// 协议模板白名单（PROVIDER-API §13.2 / ADR-0009 2026-07-02 修订）。
//
// 模板 = 编译期 const 的 ProviderCapabilities 能力基线；自定义 Provider 的
// capabilities 只能由模板派生（copyWith providerId/displayName），能力位
// 禁止来自用户配置或运行时下发。加新模板 = 改本文件 + 发版。

import 'cost_model.dart';
import 'custom_provider_config.dart';
import 'provider_capabilities.dart';

/// OpenAI Images API 兼容（POST /images/generations + b64_json）。
const String kOpenAIImageTemplateId = 'openai-image';

/// 模板基线的占位 providerId——派生时必被 copyWith 覆盖，不应出现在任何运行时数据里。
const String kTemplatePlaceholderProviderId = 'custom:__template__';

/// openai-image 模板能力基线：OpenAI 兼容端点的保守通用集。
/// 端点真实能力未知——比例/分辨率取 gpt-image-1 同款交集，批量/参考图/seed 全关，
/// 计费未知按零估（perCall 0），限流取全仓最保守档（qps 1 / burst 2 / 并发 1）。
const ProviderCapabilities kOpenAIImageTemplateCapabilities =
    ProviderCapabilities(
  providerId: kTemplatePlaceholderProviderId,
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  supportedRatios: [
    AspectRatio.r1x1,
    AspectRatio.r16x9,
    AspectRatio.r9x16,
  ],
  supportedResolutions: [Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
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
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

/// 白名单唯一事实源：templateId → 能力基线。首批仅 openai-image。
const Map<String, ProviderCapabilities> kProviderProtocolTemplates =
    <String, ProviderCapabilities>{
  kOpenAIImageTemplateId: kOpenAIImageTemplateCapabilities,
};

/// 模板派生：能力位取 const 基线，仅 providerId / displayName 来自用户配置。
/// 未知模板属编程错误（文件服务已在解析期剔除）——抛 ArgumentError 而非 InkError。
ProviderCapabilities deriveCustomProviderCapabilities(
  CustomProviderConfig config,
) {
  final ProviderCapabilities? template =
      kProviderProtocolTemplates[config.template];
  if (template == null) {
    throw ArgumentError.value(
      config.template,
      'config.template',
      'unknown protocol template',
    );
  }
  return template.copyWith(
    providerId: config.providerId,
    displayName: config.displayName,
  );
}
