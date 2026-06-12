// InspectorSubmitController 单测：
//   - submit 成功路径：先落 config → submitting → running → idle
//   - GenerationError / InkError → 结构化 InspectorSubmitError（不产生用户文案）
//   - busy 期间重复 submit 不二次发起
//   - savePromptDebounced 防抖：窗口内多次输入只落最后一次

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/generation/generation_controller.dart';

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

class _FakeGenerationController implements GenerationController {
  _FakeGenerationController({this.onSubmit});

  final Future<String> Function(String nodeId)? onSubmit;
  final List<String> submitted = [];

  @override
  Future<String> submitFromConfigNode(String configNodeId) {
    submitted.add(configNodeId);
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

  test('saveConfig：立即落盘一次', () async {
    final container = makeContainer(_FakeGenerationController());
    final ctrl = container.read(inspectorSubmitControllerProvider('n1').notifier);

    await ctrl.saveConfig(const <String, Object?>{'camera': 'orbit'});
    expect(repo.patches, [
      {'camera': 'orbit'},
    ]);
  });
}
