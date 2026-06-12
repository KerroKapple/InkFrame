// AppTeardown 单测：窗口关闭路径的有序回收。
// 顺序契约：JobQueue.dispose → Connection.close → PgController.stop → container.dispose。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
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

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: <Override>[
        jobQueueServiceProvider.overrideWith(
          (ref) async => _FakeJobQueue(() => order.add('jobQueue.dispose')),
        ),
        pgConnectionProvider.overrideWith(
          (ref) async => _FakeConnection(() => order.add('conn.close')),
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
    await container.read(pgConnectionProvider.future);
    container.read(pgControllerProvider);

    final teardown = AppTeardown();
    await teardown.run(container);

    expect(order, <String>['jobQueue.dispose', 'conn.close', 'pg.stop']);
    // 容器已 dispose：再读 provider 必抛
    expect(() => container.read(pgControllerProvider), throwsStateError);
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

class _FakeConnection implements Connection {
  _FakeConnection(this.onClose);
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
