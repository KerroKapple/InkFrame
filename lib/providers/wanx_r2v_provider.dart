// WanxR2VProvider — 阿里百炼通义万相 参考生视频（异步）。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : wan2.7-r2v
//   Submit   : POST /services/aigc/video-generation/video-synthesis
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// R2V 与 I2V 差异：
//   - input 用 `ref_images[]`（1-3 张角色/场景锁定用参考图）
//     而非 I2V 的单张 `img_url` 首帧
//   - capabilities.maxRefImages = 3，不使用首末帧字段
//
// 注：参考图本地路径由基类在 submit 前内联为 base64 data URI（HI-05）；
// http(s)/data 引用原样透传。

import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kWanxR2VModel = 'wan2.7-r2v';
const String kWanxR2VSubmitPath =
    '/services/aigc/video-generation/video-synthesis';

/// DashScope R2V 最多接受 3 张参考图。
const int kWanxR2VMaxRefImages = 3;

// ---- 能力声明 -----------------------------------------------------------
const ProviderCapabilities kWanxR2VCapabilities = ProviderCapabilities(
  providerId: 'wanx-r2v',
  displayName: 'Wanx Reference-to-Video',
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
  maxRefImages: kWanxR2VMaxRefImages,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  supportsPolling: true,
  costModel: CostModel.perSecondVideo(
    usdPerSecondAt1080p: 0.32,
    resolutionMultiplier: {
      Resolution.p720: 0.5,
      Resolution.p1080: 1.0,
    },
  ),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

class WanxR2VProvider extends DashScopeAsyncProviderBase {
  WanxR2VProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kWanxR2VCapabilities;

  @override
  String get submitEndpoint => kWanxR2VSubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = kDashScopeVideoSizeMatrix[task.resolution]?[task.aspectRatio] ??
        kDashScopeVideoSizeMatrix[Resolution.p720]![AspectRatio.r16x9]!;
    // DashScope 上限 3 张；超出丢弃保持客户端宽容、服务端做最终裁决。
    final refs = task.refImagePaths.take(kWanxR2VMaxRefImages).toList();
    return <String, Object?>{
      'model': kWanxR2VModel,
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
        if (task.seed != null) 'seed': task.seed,
      },
    };
  }

  @override
  JobStatus parseSuccessOutput(Map<String, Object?> output) =>
      parseSingleVideoUrlOutput(output);
}
