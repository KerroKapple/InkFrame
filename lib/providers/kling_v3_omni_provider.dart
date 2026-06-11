// KlingV3OmniProvider — DashScope 渠道下的 Kling v3 Omni 多素材参考生视频。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : kling/kling-v3-omni-video-generation
//   Submit   : POST /services/aigc/video-generation/video-synthesis
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// 与 KlingV3 差异：
//   - input 用 `ref_images[]`（最多 4 张多素材参考）而非单 img_url
//   - 模式仅 textToVideo——参考图语义是角色/场景/镜头的组合锁定
//   - 不支持首末帧
//
// 注：参考图 URL 由上层完成本地路径→可访问 URL 转换，Provider 层仅透传。

import 'package:dio/dio.dart';

import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';
import 'rate_limiter.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kKlingV3OmniModel = 'kling/kling-v3-omni-video-generation';
const String kKlingV3OmniSubmitPath =
    '/services/aigc/video-generation/video-synthesis';

/// Kling v3 Omni 最多接受 4 张多素材参考图。
const int kKlingV3OmniMaxRefImages = 4;

// ---- 能力声明 -----------------------------------------------------------
const ProviderCapabilities kKlingV3OmniCapabilities = ProviderCapabilities(
  providerId: 'kling-v3-omni',
  region: ProviderRegion.cn,
  modes: [GenerationMode.textToVideo],
  supportedRatios: [
    AspectRatio.r16x9,
    AspectRatio.r9x16,
    AspectRatio.r1x1,
  ],
  supportedResolutions: [Resolution.p720, Resolution.p1080],
  supportedDurations: [5, 10],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: kKlingV3OmniMaxRefImages,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  supportsPolling: true,
  costModel: CostModel.perSecondVideo(
    usdPerSecondAt1080p: 0.40,
    resolutionMultiplier: {
      Resolution.p720: 0.5,
      Resolution.p1080: 1.0,
    },
  ),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

class KlingV3OmniProvider extends DashScopeAsyncProviderBase {
  KlingV3OmniProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kKlingV3OmniCapabilities;

  @override
  String get submitEndpoint => kKlingV3OmniSubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = kDashScopeVideoSizeMatrix[task.resolution]?[task.aspectRatio] ??
        kDashScopeVideoSizeMatrix[Resolution.p720]![AspectRatio.r16x9]!;
    final refs =
        task.refImagePaths.take(kKlingV3OmniMaxRefImages).toList();
    return <String, Object?>{
      'model': kKlingV3OmniModel,
      'input': <String, Object?>{
        'prompt': task.prompt,
        if (refs.isNotEmpty) kDashScopeFieldRefImages: refs,
      },
      'parameters': <String, Object?>{
        'size': size,
        'duration': task.durationSeconds > 0
            ? task.durationSeconds
            : kDashScopeDefaultDurationSeconds,
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
KlingV3OmniProvider buildKlingV3OmniProvider({
  required DashScopeKeySource keySource,
  required ProviderRateLimiter rateLimiter,
  Dio? dio,
}) =>
    KlingV3OmniProvider(
      keySource: keySource,
      rateLimiter: rateLimiter,
      dio: dio,
    );
