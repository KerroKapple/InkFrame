// AppTeardown 单测：窗口关闭路径的有序回收。
// 顺序契约：JobQueue.dispose → Pool.close → PgController.stop → container.dispose。
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/window_state.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/window_state.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/app_teardown.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:postgres/postgres.dart';

void main() {
  late Directory tempRoot;
  late List<String> order;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('teardown_');
    order = <String>[];
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  // 窗口捕获缝在退出路径被读取——单测统一 override 成假实现，绝不触真实插件。
  ProviderContainer buildContainer([WindowStateService? windowState]) {
    return ProviderContainer(
      overrides: <Override>[
        windowStateServiceProvider
            .overrideWithValue(windowState ?? _NoopWindowState()),
        jobQueueServiceProvider.overrideWith(
          (ref) async => _FakeJobQueue(() => order.add('jobQueue.dispose')),
        ),
        pgPoolProvider.overrideWith(
          (ref) async => _FakePool(() => order.add('pool.close')),
        ),
        pgControllerProvider.overrideWithValue(
          _RecordingPgController(
            root: tempRoot,
            onStop: () => order.add('pg.stop'),
          ),
        ),
      ],
    );
  }

  test('全部已初始化 → 按 JobQueue → Connection → PG 顺序回收并 dispose 容器', () async {
    final container = buildContainer();
    // 模拟 app 正常运行：三层全部已被解析
    await container.read(jobQueueServiceProvider.future);
    await container.read(pgPoolProvider.future);
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    await teardown.run(container);

    expect(order, <String>['jobQueue.dispose', 'pool.close', 'pg.stop']);
    // 容器已 dispose：再读 provider 必抛
    expect(() => container.read(pgControllerProvider), throwsStateError);
  });

  test('半初始化：pgPool 在途时 teardown 等其完成再 close+stop（不漏回收 / 不孤儿）',
      () async {
    final gate = Completer<void>();
    final container = ProviderContainer(
      overrides: <Override>[
        windowStateServiceProvider.overrideWithValue(_NoopWindowState()),
        pgPoolProvider.overrideWith((ref) async {
          await gate.future; // 模拟 PgController.start 仍在途
          return _FakePool(() => order.add('pool.close'));
        }),
        pgControllerProvider.overrideWithValue(
          _RecordingPgController(
            root: tempRoot,
            onStop: () => order.add('pg.stop'),
          ),
        ),
      ],
    );
    // 挂载 pgPool（触发 init）但不等待 → 处于在途；pgController 也挂载。
    container.read(pgPoolProvider);
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    final f = teardown.run(container);
    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty, reason: 'init 未完成前不应回收（旧实现会漏关 + 提前 stop 变 no-op）');

    gate.complete(); // 放行 init
    await f;
    expect(order, <String>['pool.close', 'pg.stop'],
        reason: '等 init 完成后按序回收，杜绝 stop/start 竞争孤儿');
  });

  test('未初始化的 provider 不被 teardown 触发实例化', () async {
    final container = buildContainer();
    final teardown = AppTeardown();
    await teardown.run(container);

    expect(order, isEmpty, reason: '关闭路径绝不反向拉起 PG/队列');
  });

  test('重复 run 幂等：第二次不重复回收', () async {
    final container = buildContainer();
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    await teardown.run(container);
    await teardown.run(container);

    expect(order, <String>['pg.stop']);
  });

  test('并发 run（窗口关闭 + macOS Cmd+Q 竞争）共享同一次回收，仅执行一次', () async {
    final container = buildContainer();
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    // 不 await 第一个就发起第二个，模拟两条退出路径同时触发。
    final f1 = teardown.run(container);
    final f2 = teardown.run(container);
    expect(identical(f1, f2), isTrue, reason: '并发调用必须共享同一 future');
    await Future.wait(<Future<void>>[f1, f2]);

    expect(order, <String>['pg.stop']);
  });

  test('退出路径捕获窗口状态一次（重复/并发 run 也只捕获一次）', () async {
    final windowState = _CountingWindowState();
    final container = buildContainer(windowState);
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    // 并发 + 重复调用共享同一次回收 → capture 至多一次。
    await Future.wait(<Future<void>>[
      teardown.run(container),
      teardown.run(container),
    ]);
    await teardown.run(container);

    expect(windowState.captureCount, 1);
  });
}

/// 无副作用窗口状态：默认容器用它，绝不触真实 window_manager / screen_retriever。
class _NoopWindowState implements WindowStateService {
  @override
  Future<void> capture() async {}
  @override
  Future<void> restore() async {}
}

/// 计数窗口状态：验证退出路径「捕获一次」。
class _CountingWindowState implements WindowStateService {
  int captureCount = 0;
  @override
  Future<void> capture() async => captureCount++;
  @override
  Future<void> restore() async {}
}

class _FakeJobQueue implements JobQueueService {
  _FakeJobQueue(this.onDispose);
  final void Function() onDispose;

  @override
  void dispose() => onDispose();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakePool implements Pool<void> {
  _FakePool(this.onClose);
  final void Function() onClose;

  @override
  Future<void> close({bool force = false}) async => onClose();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingPgController extends PgController {
  _RecordingPgController({required Directory root, required this.onStop})
      : super(
          paths: DefaultAppPaths.forRoot(root),
          locator: _ThrowingLocator(),
        );
  final void Function() onStop;

  @override
  Future<void> stop() async => onStop();
}

class _ThrowingLocator implements PgBinaryLocator {
  @override
  PgBinaryLocation locate() => throw UnimplementedError('locate');
}
