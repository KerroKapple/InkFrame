// 自动保存可靠性回归（BOARD 第 197 行，2026-08-31 审计 W17 P1）。
//
// 旧行为：`saveConfig` 的 `catch (_)` 把 InkError 整个吞掉——UI 没有失败态、
// 没有重试，下一次输入覆盖即「自愈」，所以平时看不出来；但最后一次编辑若正好
// 失败就是静默丢数据，用户以为存上了。
//
// 本文件钉住的新契约：
//   - 写失败 → 发布 InspectorAutoSaveRetrying/Failed（可被 UI 消费），不再静默
//   - 自动重试有上限（maxAutoRetries）有退避（retryBackoff），用尽后停手
//   - 用尽后 retryUnsaved() 是用户的明确动作，能再试
//   - 失败后被新输入覆盖的键 → 不会被重试写回旧值（显式自愈，而非隐式）
//   - 失败态不随「没人看」被回收：控制器自己保活，切回该节点仍能看到并重试
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';

import '../../../helpers/recording_logger.dart';

/// 可控失败次数的 nodes 仓储：前 [failures] 次 patchTypeConfig 抛 LocalIOError
/// （仓储层把 PgException 翻成的正是这个），其后正常落盘。
class _FlakyNodeRepository implements NodeRepository {
  _FlakyNodeRepository();

  /// 还要失败几次。测试中可中途改写以模拟「库恢复了」。
  int failures = 0;

  /// 真正落盘的 patch（按落盘顺序）。
  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  /// 尝试次数（含失败）——断言重试上限用。
  int attempts = 0;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw const LocalIOError(extra: <String, Object?>{'op': 'patchTypeConfig'});
    }
    patches.add(Map<String, Object?>.of(patch));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 退避全部走完所需的真实时间 + 余量。
Duration allBackoffs() => InspectorSubmitController.retryBackoff
    .fold<Duration>(const Duration(milliseconds: 200), (acc, d) => acc + d);

void main() {
  late _FlakyNodeRepository repo;
  late RecordingLogger logger;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: <Override>[
      nodeRepositoryProvider.overrideWith((ref) => Future.value(repo)),
      loggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repo = _FlakyNodeRepository();
    logger = RecordingLogger();
  });

  test('写失败 → 发布「未保存」状态，而不是静默吞掉', () async {
    repo.failures = 99;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'last edit'});

    expect(repo.attempts, 1);
    expect(repo.patches, isEmpty);
    expect(
      container.read(inspectorAutoSaveStatusProvider('n1')),
      isA<InspectorAutoSaveRetrying>(),
      reason: '首次失败应先进自动重试态，而不是把错误吞掉留 Clean',
    );
  });

  test('自动重试：第一次失败、退避后成功 → 回到 Clean 并真落盘', () async {
    repo.failures = 1;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'draft'});
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveRetrying>());

    await Future<void>.delayed(allBackoffs());

    expect(repo.patches, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'draft'},
    ]);
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveClean>());
  });

  test('自动重试封顶：尝试 1 + 重试 ${InspectorSubmitController.maxAutoRetries} 次后停手并上屏失败',
      () async {
    repo.failures = 99;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'draft'});
    await Future<void>.delayed(allBackoffs());

    expect(repo.attempts, InspectorSubmitController.maxAutoRetries + 1,
        reason: '上限必须生效：不能无限重试把「没保存」一直伪装成「保存中」');
    final state = container.read(inspectorAutoSaveStatusProvider('n1'));
    expect(state, isA<InspectorAutoSaveFailed>());
    expect((state as InspectorAutoSaveFailed).error, isA<LocalIOError>(),
        reason: '原错误要带上来，UI 才能说清为什么失败');

    // 停手之后不再自己偷偷重试。
    await Future<void>.delayed(allBackoffs());
    expect(repo.attempts, InspectorSubmitController.maxAutoRetries + 1);
  });

  test('失败落日志（warn 每次 / error 用尽），且只记键名不记值', () async {
    repo.failures = 99;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'secret words'});
    await Future<void>.delayed(allBackoffs());

    final records = logger.byModule('inspector.autosave');
    expect(records, isNotEmpty, reason: '写失败必须留下可诊断的线索');
    for (final r in records) {
      expect(r.extra?['keys'], 'prompt');
      expect(
        '${r.extra}',
        isNot(contains('secret words')),
        reason: 'patch 的值含用户 prompt，绝不进日志',
      );
    }
  });

  test('重试用尽后 retryUnsaved() 能再写一次；成功即回 Clean', () async {
    repo.failures = 99;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'draft'});
    await Future<void>.delayed(allBackoffs());
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveFailed>());

    repo.failures = 0; // 库恢复
    await ctrl.retryUnsaved();

    expect(repo.patches, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'draft'},
    ]);
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveClean>());
  });

  test('失败后新输入覆盖同一个键 → 重试不会把旧值写回去', () async {
    repo.failures = 1;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'stale'});
    await ctrl.saveConfig(const <String, Object?>{'prompt': 'fresh'});
    await Future<void>.delayed(allBackoffs());

    expect(repo.patches, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'fresh'},
    ], reason: '「下一次输入覆盖即自愈」要显式成立，旧值不得被重试写回');
    expect(container.read(inspectorAutoSaveStatusProvider('n1')),
        isA<InspectorAutoSaveClean>());
  });

  test('失败态不随「没人看」被回收：没有任何 watcher 也读得到', () async {
    repo.failures = 99;
    final container = makeContainer();
    // 关键：不 listen 状态 provider。真实 app 里用户切到别的节点后，检查器里
    // 那行就不再 watch 它；若它被 autoDispose 复位成 Clean，用户切回来会看到
    // 「一切正常」——等于再撒一次「已保存」的谎，patch 也没人能重试了。
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'prompt': 'draft'});
    await Future<void>.delayed(allBackoffs());
    // 让 autoDispose 有机会跑完一轮。
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(inspectorAutoSaveStatusProvider('n1')),
      isA<InspectorAutoSaveFailed>(),
      reason: '控制器在有未保存内容期间要连状态发布端一起保活',
    );
  });

  test('提交路径的失败仍走 InspectorSubmitFailure，不被自动保存态顶替', () async {
    repo.failures = 99;
    final container = makeContainer();
    final ctrl =
        container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.submit(const <String, Object?>{'prompt': 'go'});

    expect(container.read(inspectorSubmitControllerProvider('n1')),
        isA<InspectorSubmitFailure>(),
        reason: '生成提交的失败面与自动保存的失败面是两件事，不能互相顶替');
  });
}
