// 协议模板白名单 + 派生规则（PROVIDER-API §13.2 / ADR-0009 修订）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';

const _config = CustomProviderConfig(
  id: 'my-endpoint',
  displayName: 'My Endpoint',
  template: kOpenAIImageTemplateId,
  baseUrl: 'https://example.com/v1',
  modelId: 'flux-pro',
);

void main() {
  test('白名单首批只含 openai-image', () {
    expect(kProviderProtocolTemplates.keys, [kOpenAIImageTemplateId]);
  });

  group('openai-image 模板基线（保守能力位）', () {
    const base = kOpenAIImageTemplateCapabilities;

    test('仅 textToImage / 同步 Pollable / 无取消', () {
      expect(base.modes, [GenerationMode.textToImage]);
      expect(base.supportsPolling, isTrue);
      expect(base.supportsCancellation, isFalse);
    });

    test('批量/参考图/seed/负向 全关，maxBatchSize=1，maxRefImages=0', () {
      expect(base.supportsBatch, isFalse);
      expect(base.supportsSeed, isFalse);
      expect(base.supportsNegativePrompt, isFalse);
      expect(base.maxBatchSize, 1);
      expect(base.maxRefImages, 0);
    });

    test('比例/分辨率取 openai 兼容通用集', () {
      expect(base.supportedRatios, [
        AspectRatio.r1x1,
        AspectRatio.r16x9,
        AspectRatio.r9x16,
      ]);
      expect(base.supportedResolutions, [Resolution.p1080]);
    });

    test('限流最保守档 qps 1 / burst 2 / 并发 1', () {
      expect(base.qps, 1);
      expect(base.burst, 2);
      expect(base.maxConcurrentJobs, 1);
    });

    test('计费未知按零估（perCall 0）', () {
      expect(base.costModel, const CostModel.perCall(usdPerCall: 0));
    });
  });

  group('deriveCustomProviderCapabilities', () {
    test('providerId / displayName 来自配置，能力位取模板基线', () {
      final caps = deriveCustomProviderCapabilities(_config);
      expect(caps.providerId, 'custom:my-endpoint');
      expect(caps.displayName, 'My Endpoint');
      expect(
        caps,
        kOpenAIImageTemplateCapabilities.copyWith(
          providerId: 'custom:my-endpoint',
          displayName: 'My Endpoint',
        ),
      );
    });

    test('占位 providerId 不泄漏到派生结果', () {
      final caps = deriveCustomProviderCapabilities(_config);
      expect(caps.providerId, isNot(kTemplatePlaceholderProviderId));
    });

    test('未知模板 → ArgumentError（编程错误，非 InkError）', () {
      expect(
        () => deriveCustomProviderCapabilities(
          _config.copyWith(template: 'no-such-template'),
        ),
        throwsArgumentError,
      );
    });
  });
}
