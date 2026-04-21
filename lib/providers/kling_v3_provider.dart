// KlingV3Provider — DashScope 渠道下的快手 Kling v3（文生/图生视频，异步）。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : kling/kling-v3-video-generation（注意含 '/'）
//   Submit   : POST /services/aigc/video-generation/video-synthesis
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// 与 WanxI2V 差异：
//   - modes 同时支持 T2V + I2V（单 Provider 多模式，避免拆两个子类）
//   - img_url 可选：有则 I2V，无则 T2V
//   - 不支持 last_frame_url
//   - model 字段写全路径 `kling/kling-v3-video-generation`——DashScope
//     用 `/` 表示厂商命名空间
//
// 注：首帧 URL 由上层完成本地路径→可访问 URL 转换，Provider 层仅透传。

import 'package:dio/dio.dart';

import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';
import 'rate_limiter.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kKlingV3Model = 'kling/kling-v3-video-generation';
const String kKlingV3SubmitPath =
    '/services/aigc/video-generation/video-synthesis';

// ---- 能力声明 -----------------------------------------------------------
const ProviderCapabilities kKlingV3Capabilities = ProviderCapabilities(
  providerId: 'kling-v3',
  region: ProviderRegion.cn,
  modes: [GenerationMode.textToVideo, GenerationMode.imageToVideo],
  supportedRatios: [
    AspectRatio.r16x9,
    AspectRatio.r9x16,
    AspectRatio.r1x1,
  ],
  supportedResolutions: [Resolution.p720, Resolution.p1080],
  supportedDurations: [5, 10],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: true,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  supportsPolling: true,
  costModel: CostModel.perSecondVideo(
    usdPerSecondAt1080p: 0.35,
    resolutionMultiplier: {
      Resolution.p720: 0.5,
      Resolution.p1080: 1.0,
    },
  ),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

/// (Resolution, AspectRatio) → DashScope `parameters.size`。
const Map<Resolution, Map<AspectRatio, String>> _kSizeMatrix = {
  Resolution.p720: {
    AspectRatio.r16x9: '1280*720',
    AspectRatio.r9x16: '720*1280',
    AspectRatio.r1x1: '720*720',
  },
  Resolution.p1080: {
    AspectRatio.r16x9: '1920*1080',
    AspectRatio.r9x16: '1080*1920',
    AspectRatio.r1x1: '1080*1080',
  },
};

class KlingV3Provider extends DashScopeAsyncProviderBase {
  KlingV3Provider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kKlingV3Capabilities;

  @override
  String get submitEndpoint => kKlingV3SubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = _kSizeMatrix[task.resolution]?[task.aspectRatio] ??
        _kSizeMatrix[Resolution.p720]![AspectRatio.r16x9]!;
    return <String, Object?>{
      'model': kKlingV3Model,
      'input': <String, Object?>{
        'prompt': task.prompt,
        if (task.firstFramePath != null) 'img_url': task.firstFramePath,
      },
      'parameters': <String, Object?>{
        'size': size,
        'duration': task.durationSeconds > 0 ? task.durationSeconds : 5,
        if (task.negativePrompt != null && task.negativePrompt!.isNotEmpty)
          'negative_prompt': task.negativePrompt,
      },
    };
  }

  @override
  JobStatus parseSuccessOutput(Map<String, Object?> output) {
    final url = output['video_url'] as String?;
    return JobStatus.success(
      remoteUrls: url != null && url.isNotEmpty ? [url] : const [],
    );
  }
}

/// Provider 工厂：DI 层注入（registry 注册见后续 PR）。
KlingV3Provider buildKlingV3Provider({
  required DashScopeKeySource keySource,
  required ProviderRateLimiter rateLimiter,
  Dio? dio,
}) =>
    KlingV3Provider(
      keySource: keySource,
      rateLimiter: rateLimiter,
      dio: dio,
    );
