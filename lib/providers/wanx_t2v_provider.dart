// WanxT2VProvider — 阿里百炼通义万相 文生视频（异步）。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : wan2.7-t2v
//   Submit   : POST /services/aigc/video-generation/video-synthesis
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// 公共行为（auth / submit / poll / 状态机 / 错误码）由
// [DashScopeAsyncProviderBase] 承担——本类只 override 三件事。
//
// 与 WanxImageProvider 差异：
//   - Request body：`input.prompt`（纯文本），非多模态 messages
//   - Response：`output.video_url` 单一 URL
//   - 追加 duration / size（含视频分辨率）

import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kWanxT2VModel = 'wan2.7-t2v';
const String kWanxT2VSubmitPath =
    '/services/aigc/video-generation/video-synthesis';

// ---- 能力声明 -----------------------------------------------------------
const ProviderCapabilities kWanxT2VCapabilities = ProviderCapabilities(
  providerId: 'wanx-t2v',
  displayName: 'Wanx Text-to-Video',
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
  maxRefImages: 0,
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
    usdPerSecondAt1080p: 0.25,
    resolutionMultiplier: {
      Resolution.p720: 0.5,
      Resolution.p1080: 1.0,
    },
  ),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 2,
);

class WanxT2VProvider extends DashScopeAsyncProviderBase {
  WanxT2VProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kWanxT2VCapabilities;

  @override
  String get submitEndpoint => kWanxT2VSubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = kDashScopeVideoSizeMatrix[task.resolution]?[task.aspectRatio] ??
        kDashScopeVideoSizeMatrix[Resolution.p720]![AspectRatio.r16x9]!;
    return <String, Object?>{
      'model': kWanxT2VModel,
      'input': <String, Object?>{'prompt': task.prompt},
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
