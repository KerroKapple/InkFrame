// ProviderRegistry 单元测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/provider_registry.dart';

class _FakeSubmittable implements Submittable {
  _FakeSubmittable(this.id);
  final String id;

  @override
  ProviderCapabilities get capabilities => ProviderCapabilities(
        providerId: id,
        region: ProviderRegion.global,
        modes: const [GenerationMode.textToImage],
        supportedRatios: const [AspectRatio.r1x1],
        supportedResolutions: const [Resolution.p1080],
        supportedDurations: const [],
        supportedCameras: const [],
        maxBatchSize: 1,
        maxRefImages: 0,
        refImagesIncludeKeyframes: false,
        supportsFirstFrame: false,
        supportsLastFrame: false,
        supportsNegativePrompt: false,
        supportsSeed: false,
        supportsSound: false,
        supportsBatch: false,
        supportsCancellation: false,
        supportsPolling: false,
        costModel: const CostModel.perCall(usdPerCall: 0.01),
        maxConcurrentJobs: 1,
        qps: 2,
        burst: 5,
      );

  @override
  Future<JobId> submit(GenerationTask task) async => 'fake-job-$id';
}

void main() {
  group('ProviderRegistry', () {
    test('按 id 取 Provider', () {
      final registry = ProviderRegistry({
        'fake-a': () => _FakeSubmittable('fake-a'),
        'fake-b': () => _FakeSubmittable('fake-b'),
      });
      expect(registry.contains('fake-a'), isTrue);
      expect(registry.get('fake-a').capabilities.providerId, 'fake-a');
      expect(registry.ids, containsAll(<String>['fake-a', 'fake-b']));
    });

    test('未注册 id 抛 ArgumentError', () {
      final registry = ProviderRegistry(const <String, ProviderFactory>{});
      expect(() => registry.get('nope'), throwsA(isA<ArgumentError>()));
    });

    test('空字符串 id 断言失败', () {
      expect(
        () => ProviderRegistry({'': () => _FakeSubmittable('x')}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('listCapabilities 返回所有 Provider 能力声明', () {
      final registry = ProviderRegistry({
        'a': () => _FakeSubmittable('a'),
        'b': () => _FakeSubmittable('b'),
      });
      final caps = registry.listCapabilities();
      expect(caps, hasLength(2));
      expect(caps.map((c) => c.providerId), containsAll(<String>['a', 'b']));
    });
  });
}
