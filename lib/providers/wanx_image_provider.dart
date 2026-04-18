// WanxImageProvider — 阿里百炼通义万相 文生图 / 图生图（异步）。
//
// 接入参数（PROVIDER-API.md §10 / ADR-0005）：
//   Base URL : https://dashscope.aliyuncs.com/api/v1
//   Model ID : wan2.7-image-pro
//   Submit   : POST /services/aigc/image-generation/generation
//   Poll     : GET  /tasks/{task_id}（基类提供）
//
// 公共行为（auth / submit / poll / 状态机 / 错误码）由
// [DashScopeAsyncProviderBase] 承担——本类只 override 三件事：
//   1. submitEndpoint
//   2. buildRequestBody
//   3. parseSuccessOutput
//
// 硬约束（PROVIDER-API.md §10 Step 1/2）：
//   - capabilities 是 const 字段，编译期固定
//   - 接入参数写死在本文件顶部 const 区
//   - 抛出 InkError 子类，禁止裸 DioException

import 'package:dio/dio.dart';

import '../core/models/generation_task.dart';
import '../core/models/cost_model.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import 'dashscope_async_provider_base.dart';
import 'rate_limiter.dart';

// ---- 接入参数（ADR-0005 锁定） -------------------------------------------
const String kWanxImageModel = 'wan2.7-image-pro';
const String kWanxImageSubmitPath =
    '/services/aigc/image-generation/generation';

// ---- 能力声明（PROVIDER-API.md §9.2 + DashScope 控制台档位） -------------
const ProviderCapabilities kWanxImageCapabilities = ProviderCapabilities(
  providerId: 'wanx-image',
  region: ProviderRegion.cn,
  modes: [GenerationMode.textToImage, GenerationMode.imageToImage],
  supportedRatios: [
    AspectRatio.r1x1,
    AspectRatio.r16x9,
    AspectRatio.r9x16,
    AspectRatio.r4x3,
    AspectRatio.r3x4,
  ],
  supportedResolutions: [Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 4,
  maxRefImages: 1,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: true,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: true,
  supportsCancellation: false,
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.032),
  maxConcurrentJobs: 2,
  qps: 1,
  burst: 2,
);

/// AspectRatio → DashScope `parameters.size`（1080p 档）。
const Map<AspectRatio, String> _kSizeBy1080p = {
  AspectRatio.r1x1: '1024*1024',
  AspectRatio.r16x9: '1280*720',
  AspectRatio.r9x16: '720*1280',
  AspectRatio.r4x3: '1024*768',
  AspectRatio.r3x4: '768*1024',
};

class WanxImageProvider extends DashScopeAsyncProviderBase {
  WanxImageProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kWanxImageCapabilities;

  @override
  String get submitEndpoint => kWanxImageSubmitPath;

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) {
    final size = _kSizeBy1080p[task.aspectRatio] ?? _kSizeBy1080p[AspectRatio.r1x1]!;
    final content = <Map<String, Object?>>[
      {'text': task.prompt},
      for (final p in task.refImagePaths) {'image': p},
    ];
    return <String, Object?>{
      'model': kWanxImageModel,
      'input': <String, Object?>{
        'messages': [
          <String, Object?>{'role': 'user', 'content': content},
        ],
      },
      'parameters': <String, Object?>{
        'size': size,
        'n': task.batchSize,
        if (task.negativePrompt != null && task.negativePrompt!.isNotEmpty)
          'negative_prompt': task.negativePrompt,
        if (task.seed != null) 'seed': task.seed,
      },
    };
  }

  @override
  JobStatus parseSuccessOutput(Map<String, Object?> output) {
    final urls = <String>[];
    final choices = output['choices'];
    if (choices is List) {
      for (final choice in choices) {
        if (choice is! Map) continue;
        final message = choice['message'];
        if (message is! Map) continue;
        final content = message['content'];
        if (content is! List) continue;
        for (final part in content) {
          if (part is! Map) continue;
          final url = part['image'] as String?;
          if (url != null && url.isNotEmpty) urls.add(url);
        }
      }
    }
    return JobStatus.success(remoteUrls: urls);
  }
}

/// Provider 工厂：DI 层注入（registry 注册见后续 PR）。
WanxImageProvider buildWanxImageProvider({
  required DashScopeKeySource keySource,
  required ProviderRateLimiter rateLimiter,
  Dio? dio,
}) =>
    WanxImageProvider(
      keySource: keySource,
      rateLimiter: rateLimiter,
      dio: dio,
    );
