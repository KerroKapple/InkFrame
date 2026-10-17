// 退出应用不得丢掉挂起的防抖自动保存（BOARD 第 201 行）。
//
// 旧行为：`AppTeardown._run` 的顺序是「JobQueue → **Pool.close** →
// PgController.stop → container.dispose」。防抖计时器的 `ref.keepAlive()` 只挡得住
// autoDispose，挡不住整个容器被 dispose；而且即便此刻补一次落盘，连接池已经关了，
// 写不进去（`Pool.close` 一上来就把 semaphore 关了，之后的 execute 直接抛）。
// 窗口 ≤500ms——用户打完最后一个字就关窗，那一笔没了，而且毫无痕迹。
//
// 本文件钉住的新契约（跨层，所以放在 services 侧而不是检查器侧）：
//   - 退出序列在 **Pool.close 之前** 冲一次全部挂起写入
//   - 冲的内容 = 未发射的防抖 patch + 失败等重试的 `_unsaved`（同键取更新的那份）
//   - 冲刷走抽象接口（PendingWriteRegistry），teardown 不认识检查器
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/pending_writes.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/window_state.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/pending_write_flush.dart';
import 'package:inkframe/core/interfaces/window_state.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/services/app_teardown.dart';
import 'package:postgres/postgres.dart';

import '../helpers/recording_logger.dart';

void main() {
  late _RecordingNodeRepository repo;
  late RecordingLogger logger;
  late List<String> order;

  setUp(() {
    order = <String>[];
    repo = _RecordingNodeRepository(order);
    logger = RecordingLogger();
  });

  /// 退出路径会读到的缝全部换成假实现：绝不触真实 window_manager / PG。
  /// `pendingWriteRegistryProvider` 刻意**不** override——这个用例要跑真的注册表。
  /// `pgControllerProvider` 刻意不挂载——teardown 只回收已实例化的 provider。
  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: <Override>[
      windowStateServiceProvider.overrideWithValue(_NoopWindowState()),
      nodeRepositoryProvider.overrideWith((ref) async => repo),
      loggerProvider.overrideWithValue(logger),
      pgPoolProvider.overrideWith(
        (ref) async => _FakePool(() => order.add('pool.close')),
      ),
    ]);
    addTearDown(() {
      // teardown 正常跑完就已经 dispose 了容器；红灯路径上兜一层，不重复 dispose。
      try {
        container.dispose();
      } on StateError {
        // 已 dispose。
      }
    });
    return container;
  }

  /// 模拟 app 正常运行到用户按关窗那一刻：连接池已经建好。
  Future<void> mountPool(ProviderContainer container) =>
      container.read(pgPoolProvider.future);

  test('关窗时挂起的防抖 patch 必须落盘（复现 BOARD 第 201 行）', () async {
    final container = makeContainer();
    await mountPool(container);
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('the last thing the user typed');
    expect(repo.patches, isEmpty,
        reason: '前置条件：防抖窗口内此刻确实还没落盘，否则这个用例测不到丢失');

    // 不等防抖窗口过去就退出——这正是那个 ≤500ms 的丢失窗口。
    await AppTeardown().run(container);

    expect(
      repo.patches,
      <Map<String, Object?>>[
        <String, Object?>{'prompt': 'the last thing the user typed'},
      ],
      reason: '退出序列必须在关池前把挂起的防抖写入冲掉',
    );
  });

  test('冲刷严格发生在 Pool.close 之前——关池之后再写根本写不进去', () async {
    final container = makeContainer();
    await mountPool(container);
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('draft');
    await AppTeardown().run(container);

    expect(order, <String>['write', 'pool.close'],
        reason: '顺序反了等于没修：Pool.close 一关 semaphore，后续 execute 直接抛');
  });

  test('失败等重试的未落盘内容（_unsaved）退出时也冲一次', () async {
    repo.failures = 1; // 第一次写失败 → 进 _unsaved，等退避重试
    final container = makeContainer();
    await mountPool(container);
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'retry me'});
    expect(repo.patches, isEmpty, reason: '前置条件：第一次写确实失败了');
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveRetrying>());

    // 退避计时器还没到就关窗：容器一 dispose 它永远不会触发。
    await AppTeardown().run(container);

    expect(repo.patches, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'retry me'},
    ]);
  });

  test('同一个键同时在 _unsaved 和防抖里 → 冲刷写用户最后敲的那份', () async {
    repo.failures = 1;
    final container = makeContainer();
    await mountPool(container);
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'stale'});
    ctrl.savePromptDebounced('fresh');

    await AppTeardown().run(container);

    expect(repo.patches, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'fresh'},
    ], reason: '防抖里的是用户最后敲的值，不能被失败重试表里的旧值盖掉');
  });

  test('没有挂起内容 → 退出路径一笔都不写（不为了冲刷凭空产生 UPDATE）', () async {
    final container = makeContainer();
    await mountPool(container);
    container.read(inspectorSubmitControllerProvider('n1').notifier);

    await AppTeardown().run(container);

    expect(order, <String>['pool.close']);
  });

  test('冲刷时写库仍然失败 → 不阻断退出，且留下 error 级日志线索', () async {
    repo.failures = 99;
    final container = makeContainer();
    await mountPool(container);
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('doomed');
    await AppTeardown().run(container);

    expect(order, <String>['pool.close'], reason: '写失败也必须继续把 PG 关掉');
    final records = logger.byModule('inspector.autosave');
    expect(records, isNotEmpty, reason: '这条日志是那一笔丢失的唯一线索');
    expect(
      records.last.msg,
      contains('gave up'),
      reason: '退出路径上「will retry」是谎话——退避计时器永远不会再触发',
    );
    for (final r in records) {
      expect('${r.extra}', isNot(contains('doomed')),
          reason: 'patch 的值含用户 prompt，绝不进日志');
    }
  });

  // 对照组：没有这条，上面几条的通过方式可以退化成「退出时无条件写一笔」。
  test('检查器已被回收 → 退出路径既不写也不炸', () async {
    final container = makeContainer();
    await mountPool(container);
    // 读 notifier 但不保活：没有 watcher，autoDispose 随即回收控制器。
    container.read(inspectorSubmitControllerProvider('n1').notifier);
    await Future<void>.delayed(Duration.zero);

    await AppTeardown().run(container);

    expect(order, <String>['pool.close']);
  });

  test('注册 / 注销与控制器生命周期对称（注册表不留悬空引用）', () async {
    final registry = _SpyRegistry();
    final container = ProviderContainer(overrides: <Override>[
      pendingWriteRegistryProvider.overrideWithValue(registry),
      nodeRepositoryProvider.overrideWith((ref) async => repo),
      loggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);

    final ProviderSubscription<InspectorSubmitState> sub =
        container.listen(inspectorSubmitControllerProvider('n1'), (_, _) {});
    expect(registry.registered, hasLength(1),
        reason: '控制器一挂载就得注册，否则退出序列根本找不到它');

    sub.close();
    await Future<void>.delayed(Duration.zero); // 让 autoDispose 跑完

    expect(registry.registered, isEmpty,
        reason: '控制器一销毁就必须注销——否则注册表持一个死对象的引用');
  });
}

/// 记录注册表里现在有谁：钉住 feature 侧 register/unregister 的接线。
class _SpyRegistry implements PendingWriteRegistry {
  final Set<PendingWriteFlushable> registered =
      Set<PendingWriteFlushable>.identity();

  @override
  void register(PendingWriteFlushable target) => registered.add(target);

  @override
  void unregister(PendingWriteFlushable target) => registered.remove(target);

  @override
  Future<void> flushAll() async {}

  @override
  Future<void> flushBeforeEdit() async {}
}

/// 可控失败次数的 nodes 仓储：落盘顺序记进共享的 [order]，用来钉住
/// 「写在 Pool.close 之前」这条顺序契约。
class _RecordingNodeRepository implements NodeRepository {
  _RecordingNodeRepository(this.order);

  final List<String> order;

  /// 还要失败几次。仓储层把 PgException 统一翻成 LocalIOError。
  int failures = 0;

  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (failures > 0) {
      failures--;
      throw const LocalIOError(
        extra: <String, Object?>{'op': 'patchTypeConfig'},
      );
    }
    order.add('write');
    patches.add(Map<String, Object?>.of(patch));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoopWindowState implements WindowStateService {
  @override
  Future<void> capture() async {}
  @override
  Future<void> restore() async {}
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
