// WanxI2VProvider — 阿里百炼通义万相 图生视频（异步）。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : wan2.7-i2v
//   Submit   : POST /services/aigc/video-generation/video-synthesis
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// 与 WanxT2VProvider 差异：
//   - input 追加 `img_url`（首帧图，必填）+ 可选 `last_frame_url`（末帧图）
//   - 其他参数（size / duration / seed / negative_prompt）一致
//   - 响应同 T2V：`output.video_url` 单一 URL
//
// 注：首末帧本地路径由基类在 submit 前内联为 base64 data URI（HI-05）；
// http(s)/data 引用原样透传。

import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kWanxI2VModel = 'wan2.7-i2v';
const String kWanxI2VSubmitPath =
    '/services/aigc/video-generation/video-synthesis';

// ---- 能力声明 -----------------------------------------------------------
const ProviderCapabilities kWanxI2VCapabilities = ProviderCapabilities(
  providerId: 'wanx-i2v',
  displayName: 'Wanx Image-to-Video',
  region: ProviderRegion.cn,
  modes: [GenerationMode.imageToVideo],
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
  supportsLastFrame: true,
  supportsNegativePrompt: true,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  supportsPolling: true,
  costModel: CostModel.perSecondVideo(
    usdPerSecondAt1080p: 0.30,
    resolutionMultiplier: {
      Resolution.p720: 0.5,
      Resolution.p1080: 1.0,
    },
  ),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

class WanxI2VProvider extends DashScopeAsyncProviderBase {
  WanxI2VProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kWanxI2VCapabilities;

  @override
  String get submitEndpoint => kWanxI2VSubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = kDashScopeVideoSizeMatrix[task.resolution]?[task.aspectRatio] ??
        kDashScopeVideoSizeMatrix[Resolution.p720]![AspectRatio.r16x9]!;
    return <String, Object?>{
      'model': kWanxI2VModel,
      'input': <String, Object?>{
        'prompt': task.prompt,
        if (task.firstFramePath != null)
          kDashScopeFieldImgUrl: task.firstFramePath,
        if (task.lastFramePath != null)
          kDashScopeFieldLastFrameUrl: task.lastFramePath,
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
