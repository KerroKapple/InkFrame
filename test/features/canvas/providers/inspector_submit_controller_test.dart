// InspectorSubmitController 单测：
//   - submit 成功路径：先落 config → submitting → running → idle
//   - GenerationError / InkError → 结构化 InspectorSubmitError（不产生用户文案）
//   - busy 期间重复 submit 不二次发起
//   - savePromptDebounced 防抖：窗口内多次输入只落最后一次
//   - submitWithPending：挂起的编辑（防抖 + 写失败等重试的键）并进终稿一并提交（B8）

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/generation/generation_controller.dart';

import '../../../helpers/recording_logger.dart';

class _FakeNodeRepository implements NodeRepository {
  final List<Map<String, Object?>> patches = [];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patches.add(Map.of(patch));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 可按调用序号闸住 `patchTypeConfig` 的仓储——让 await **真的停在中间**。
///
/// 关键设计：patch 在闸开之后才记进 [patches]，所以 [patches] 的顺序就是
/// **落库顺序**。「终稿有没有被旧 patch 盖掉」只能靠落库顺序断言，断言「写了
/// 哪些」是测不出这个 bug 的。
class _GatedNodeRepository implements NodeRepository {
  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  /// 已进入 patchTypeConfig 的调用数（含卡在闸上的）。
  int started = 0;

  final Map<int, Completer<void>> _gates = <int, Completer<void>>{};

  /// 让第 [callIndex] 次调用（1 起）卡住，返回它的闸。
  Completer<void> gate(int callIndex) =>
      _gates[callIndex] = Completer<void>();

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    started++;
    final Completer<void>? g = _gates[started];
    if (g != null) await g.future;
    patches.add(Map<String, Object?>.of(patch));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 前 [failures] 次 patchTypeConfig 抛 LocalIOError（仓储层把 PgException 翻成的正是这个），其后正常落盘。
class _FlakyNodeRepository implements NodeRepository {
  int failures = 0;

  /// 真正落盘的 patch（按落盘顺序）。
  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
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

class _FakeGenerationController implements GenerationController {
  _FakeGenerationController({this.onSubmit});

  final Future<String> Function(String nodeId)? onSubmit;
  final List<String> submitted = [];

  /// 记录每次提交带的 seed 覆盖（P4「以该种子重跑」）；不带就是 null。
  final List<int?> submittedSeeds = <int?>[];

  @override
  Future<String> submitFromConfigNode(String configNodeId, {int? seedOverride}) {
    submitted.add(configNodeId);
    submittedSeeds.add(seedOverride);
    return onSubmit?.call(configNodeId) ?? Future.value('job-1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeNodeRepository repo;

  ProviderContainer makeContainer(GenerationController gen) {
    final container = ProviderContainer(overrides: [
      nodeRepositoryProvider.overrideWith((ref) => Future.value(repo)),
      generationControllerProvider.overrideWith((ref) => Future.value(gen)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = _FakeNodeRepository());

  test('submit 成功：落 finalConfig，状态走 submitting → running → idle', () async {
    final gen = _FakeGenerationController();
    final container = makeContainer(gen);
    final states = <InspectorSubmitState>[];
    container.listen(
      inspectorSubmitControllerProvider('n1'),
      (_, s) => states.add(s),
    );

    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);
    await ctrl.submit(<String, Object?>{'prompt': 'a cat', 'provider_id': 'p'});

    expect(repo.patches.single, {'prompt': 'a cat', 'provider_id': 'p'});
    expect(gen.submitted, ['n1']);
    expect(states.whereType<InspectorSubmitSubmitting>(), isNotEmpty);
    expect(states.whereType<InspectorSubmitRunning>(), isNotEmpty);
    expect(states.last, isA<InspectorSubmitIdle>());
  });

  test('MissingApiKeyError → InspectorMissingApiKey', () async {
    final gen = _FakeGenerationController(
      onSubmit: (_) => throw const MissingApiKeyError('p'),
    );
    final container = makeContainer(gen);
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.submit(const <String, Object?>{'prompt': 'x'});

    final state = container.read(inspectorSubmitControllerProvider('n1'));
    expect(state, isA<InspectorSubmitFailure>());
    expect(
      (state as InspectorSubmitFailure).error,
      isA<InspectorMissingApiKey>(),
    );
  });

  test('InvalidGenerationConfigError → InspectorInvalidConfig 携带 reason', () async {
    final gen = _FakeGenerationController(
      onSubmit: (_) => throw const InvalidGenerationConfigError('prompt is empty'),
    );
    final container = makeContainer(gen);
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.submit(const <String, Object?>{'prompt': 'x'});

    final state = container.read(inspectorSubmitControllerProvider('n1'))
        as InspectorSubmitFailure;
    expect(state.error, isA<InspectorInvalidConfig>());
    expect((state.error as InspectorInvalidConfig).reason, 'prompt is empty');
  });

  test('ProviderNotRegisteredError → InspectorProviderNotRegistered', () async {
    final gen = _FakeGenerationController(
      onSubmit: (_) => throw const ProviderNotRegisteredError('p'),
    );
    final container = makeContainer(gen);
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.submit(const <String, Object?>{'prompt': 'x'});

    final state = container.read(inspectorSubmitControllerProvider('n1'))
        as InspectorSubmitFailure;
    expect(state.error, isA<InspectorProviderNotRegistered>());
  });

  test('InkError → InspectorInkFailure 保留原错误（供 l10nError 映射）', () async {
    const inkError = ProviderError(code: InkErrorCode.invalidKey);
    final gen = _FakeGenerationController(onSubmit: (_) => throw inkError);
    final container = makeContainer(gen);
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.submit(const <String, Object?>{'prompt': 'x'});

    final state = container.read(inspectorSubmitControllerProvider('n1'))
        as InspectorSubmitFailure;
    expect(state.error, isA<InspectorInkFailure>());
    expect((state.error as InspectorInkFailure).error, same(inkError));
  });

  test('busy 期间重复 submit 不二次发起', () async {
    final gate = Completer<String>();
    final gen = _FakeGenerationController(onSubmit: (_) => gate.future);
    final container = makeContainer(gen);
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    final first = ctrl.submit(const <String, Object?>{'prompt': 'x'});
    // 等第一次进入 running（已发起 submitFromConfigNode 但未完成）
    while (gen.submitted.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await ctrl.submit(const <String, Object?>{'prompt': 'x'});
    expect(gen.submitted.length, 1);

    gate.complete('job-1');
    await first;
    expect(
      container.read(inspectorSubmitControllerProvider('n1')),
      isA<InspectorSubmitIdle>(),
    );
  });

  test('savePromptDebounced：窗口内多次输入只落最后一次', () async {
    final container = makeContainer(_FakeGenerationController());
    // listen 保活 autoDispose，防止防抖窗口内 provider 被回收
    container.listen(inspectorSubmitControllerProvider('n1'), (_, _) {});
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('a');
    ctrl.savePromptDebounced('ab');
    ctrl.savePromptDebounced('abc');
    expect(repo.patches, isEmpty, reason: '防抖窗口内不应落盘');

    await Future<void>.delayed(
      InspectorSubmitController.debounceDuration + const Duration(milliseconds: 100),
    );
    expect(repo.patches, [
      {'prompt': 'abc'},
    ]);
  });

  test(
      'savePromptDebounced：切换选中(无监听器)也不能丢掉挂起的写入——回归 2026-08-31 审计 P0',
      () async {
    final container = makeContainer(_FakeGenerationController());
    // 关键：不调用 container.listen(...)。真实 app 里，切换 Inspector 的
    // 选中节点会让旧的 inspectorSubmitControllerProvider(oldId) 失去最后一个
    // watcher；如果防抖挂起期间没有 keepAlive，autoDispose 会在计时器触发前
    // 就把它回收，onDispose 只 cancel 了计时器，编辑内容直接丢失。
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.savePromptDebounced('final draft');

    // 让 autoDispose 有机会在防抖窗口内触发（不保活的话，这里就会被回收）。
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(
      InspectorSubmitController.debounceDuration + const Duration(milliseconds: 100),
    );

    expect(
      repo.patches,
      [
        {'prompt': 'final draft'},
      ],
      reason: 'ref.keepAlive() 应挂起 autoDispose 直到挂起的防抖写入完成',
    );
  });

  test('同一 node 上两个不同防抖字段按键合并，不互相顶掉（BOARD 第 198 行）', () async {
    final container = makeContainer(_FakeGenerationController());
    container.listen(inspectorSubmitControllerProvider('n1'), (_, _) {});
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    ctrl.saveDebounced(const <String, Object?>{'shot_notes': 'a note'});
    ctrl.savePromptDebounced('a prompt');
    expect(repo.patches, isEmpty, reason: '防抖窗口内不应落盘');

    await Future<void>.delayed(
      InspectorSubmitController.debounceDuration + const Duration(milliseconds: 100),
    );

    expect(repo.patches, [
      {'shot_notes': 'a note', 'prompt': 'a prompt'},
    ], reason: '第二个字段不得把第一个还没落盘的 patch 整个顶掉');
  });

  test('saveConfig：立即落盘一次', () async {
    final container = makeContainer(_FakeGenerationController());
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'camera': 'orbit'});
    expect(repo.patches, [
      {'camera': 'orbit'},
    ]);
  });

  // B8：画布 Ctrl+↵ / 节点菜单「生成」原来先借退出路径的 flushPendingWrites 冲一笔、再交空补丁——那一笔写失败就按
  // 「已用尽」记账、不再重试，接着 submit 读到库里的旧提示词，白生成一次。
  group('submitWithPending', () {
    test('还没发射的防抖 patch 并进终稿：只写一笔，发起生成时库里已经是最新提示词', () async {
      List<Map<String, Object?>>? landedAtSubmit;
      final gen = _FakeGenerationController(onSubmit: (_) async {
        landedAtSubmit = List<Map<String, Object?>>.of(repo.patches);
        return 'job-1';
      });
      final container = makeContainer(gen);
      final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

      ctrl.savePromptDebounced('newest words');
      await ctrl.submitWithPending();

      expect(repo.patches, <Map<String, Object?>>[
        <String, Object?>{'prompt': 'newest words'},
      ]);
      expect(landedAtSubmit, <Map<String, Object?>>[
        <String, Object?>{'prompt': 'newest words'},
      ], reason: '生成读到的就是用户最后敲进去的那句');
      expect(gen.submitted, <String>['n1']);

      // 防抖已经被终稿吃掉：窗口过了也不再补写一笔。
      await Future<void>.delayed(
        InspectorSubmitController.debounceDuration + const Duration(milliseconds: 100),
      );
      expect(repo.patches, hasLength(1));
    });

    test('写失败等重试的键也并进终稿；排着的重试晚到只会把同一份终稿再写一遍，不把旧值盖回去', () async {
      final _FlakyNodeRepository flaky = _FlakyNodeRepository()..failures = 1;
      final gen = _FakeGenerationController();
      final container = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) => Future.value(flaky)),
        generationControllerProvider.overrideWith((ref) => Future.value(gen)),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

      // ① 一笔自动保存写失败，进重试表（prompt 旧稿 + camera）。
      await ctrl.saveConfig(const <String, Object?>{'prompt': 'old draft', 'camera': 'orbit'});
      expect(flaky.patches, isEmpty);
      // ② 接着又敲了字，防抖还没发射。
      ctrl.savePromptDebounced('new draft');

      await ctrl.submitWithPending();

      expect(flaky.patches.first, <String, Object?>{'prompt': 'new draft', 'camera': 'orbit'},
          reason: '终稿 = 重试表 + 防抖，同一个键取防抖里的新值');
      expect(gen.submitted, <String>['n1']);

      // ③ 排着的重试（首次退避 400ms）晚到：写的也是新稿。
      await Future<void>.delayed(
        InspectorSubmitController.retryBackoff.first + const Duration(milliseconds: 300),
      );
      expect(flaky.patches.last['prompt'], 'new draft');
      expect(
        flaky.patches.where((Map<String, Object?> p) => p['prompt'] == 'old draft'),
        isEmpty,
        reason: '重试不得把旧稿盖回终稿头上',
      );
    });
  });

  // 「在途写入」与 submit() 竞序（2026-08-31 审计 W3 P1；BOARD 第 196 行）。
  //
  // #232 只修了「挂起未发射」被 dispose 丢弃那一种。这一组测的是**已经发射**
  // 的那一种：防抖计时器已触发、saveConfig 正 await 仓储时，submit 把完整
  // finalConfig 也发下去——两条 UPDATE 并发，到达顺序没人保证，旧 patch 晚到
  // 就把终稿 prompt 盖掉。已经发出去的 UPDATE 取消不了，所以唯一的修法是
  // 不并发：同一节点的 type_config 写入排队。
  group('type_config 写入串行化', () {
    late _GatedNodeRepository gated;

    ProviderContainer makeGatedContainer(GenerationController gen) {
      final container = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) => Future.value(gated)),
        generationControllerProvider.overrideWith((ref) => Future.value(gen)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() => gated = _GatedNodeRepository());

    test('在途的旧 patch 不得覆盖 submit 的终稿（真让 await 停在中间）', () async {
      const Map<String, Object?> finalConfig = <String, Object?>{
        'prompt': 'final draft',
        'provider_id': 'p',
      };
      // submitFromConfigNode 发起时，库里最后一笔写入是什么——生成读的就是它。
      List<Map<String, Object?>>? landedAtSubmit;
      final gen = _FakeGenerationController(onSubmit: (_) async {
        landedAtSubmit = List<Map<String, Object?>>.of(gated.patches);
        return 'job-1';
      });
      final container = makeGatedContainer(gen);
      final ctrl =
          container.read(inspectorSubmitControllerProvider('n1').notifier);

      // ① 防抖的旧 patch 发射出去，卡在仓储里（第 1 次调用）。
      final Completer<void> stale = gated.gate(1);
      ctrl.savePromptDebounced('stale draft');
      await Future<void>.delayed(
        InspectorSubmitController.debounceDuration +
            const Duration(milliseconds: 100),
      );
      expect(gated.started, 1, reason: '旧 patch 必须已经发射');
      expect(gated.patches, isEmpty, reason: '确认它真的停在 await 中间');

      // ② 此刻 submit 落完整终稿。
      final Future<void> submitted = ctrl.submit(finalConfig);
      // 给未修版本足够时间走完整条 submit（它根本不等在途的旧写入）。
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // ③ 现在才放旧 patch 过闸。
      stale.complete();
      await submitted;

      expect(gated.patches.length, 2, reason: '两笔都要落，不能有一笔被偷偷丢掉');
      expect(
        gated.patches.last,
        finalConfig,
        reason: '终稿必须是最后落盘的那一笔——旧 patch 晚到覆盖终稿就是这张卡的 bug',
      );
      expect(landedAtSubmit?.last, finalConfig,
          reason: '发起生成时库里就该已经是终稿，生成读到的不能是旧 prompt');
      expect(
        container.read(inspectorSubmitControllerProvider('n1')),
        isA<InspectorSubmitIdle>(),
      );
    });

    test('两笔自动保存按发起顺序落盘，后发起的不插队', () async {
      final container = makeGatedContainer(_FakeGenerationController());
      final ctrl =
          container.read(inspectorSubmitControllerProvider('n1').notifier);

      final Completer<void> first = gated.gate(1);
      unawaited(ctrl.saveConfig(const <String, Object?>{'prompt': 'first'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gated.started, 1);

      unawaited(ctrl.saveConfig(const <String, Object?>{'prompt': 'second'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gated.patches, isEmpty,
          reason: '第二笔必须排在第一笔后面，不能并发下发');

      first.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gated.patches, [
        {'prompt': 'first'},
        {'prompt': 'second'},
      ], reason: '同一个键被连写两次时，最终生效的必须是后发起的那个值');
    });
  });
}
