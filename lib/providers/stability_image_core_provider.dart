// StabilityImageCoreProvider — Stability AI Stable Image Core 同步文生图。
//
// 接入参数（Stability AI REST v2beta）：
//   Base URL : https://api.stability.ai
//   Generate : POST /v2beta/stable-image/generate/core（同步，返回原始图片字节）
//   Auth     : Authorization: Bearer {key}（从 keySource 读取）
//   Validate : GET /v1/user/balance（v1 legacy，仍有效，零生成配额消耗）
//   Poll     : 无（同步返回，走 SyncProviderBase 的 inlineBytes 通道）
//
// 区别于其它 JSON Provider 的三个特殊点（均封在 performGeneration 内）：
//   1. 请求体 multipart/form-data（FormData.fromMap），非 JSON
//   2. 响应 ResponseType.bytes（逐请求 Options 设置，不污染共享 Dio 的 JSON 默认）
//   3. finish-reason 响应头：HTTP 200 也可能是 CONTENT_FILTERED（内容过滤）
//
// 共享脚手架见 SyncProviderBase；本文件仅声明能力 + Stability 专有的请求/解析/审核判定。
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/provider_capabilities.dart';
import 'sync_provider_base.dart';

// ---- 接入参数（Stability AI v2beta 锁定） --------------------------------
const String kStabilityBasePath = 'https://api.stability.ai';
const String kStabilityCoreGeneratePath =
    '/v2beta/stable-image/generate/core';
const String kStabilityBalancePath = '/v1/user/balance';
const String kStabilityLocalJobPrefix = 'local://stability-image-core/';
// GenerationTask 无 output-format 字段；硬编码 png，未来改单行即可。
const String kStabilityOutputFormat = 'png';

// ---- 能力声明（plan §ProviderCapabilities） -----------------------------
const ProviderCapabilities kStabilityImageCoreCapabilities =
    ProviderCapabilities(
  providerId: 'stability-image-core',
  displayName: 'Stable Image Core',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  supportedRatios: [
    AspectRatio.r1x1,
    AspectRatio.r16x9,
    AspectRatio.r9x16,
    AspectRatio.r4x3,
    AspectRatio.r3x4,
    AspectRatio.r21x9,
  ],
  supportedResolutions: [Resolution.p1080],
  supportedDurations: [],
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
  // 同步 Provider 仍走 Pollable：poll 一调即返回 inlineBytes（ADR-0004）。
  supportsPolling: true,
  costModel: CostModel.perCall(usdPerCall: 0.03),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 3,
);

class StabilityImageCoreProvider extends SyncProviderBase {
  StabilityImageCoreProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kStabilityImageCoreCapabilities;

  @override
  String get baseUrl => kStabilityBasePath;

  @override
  String get localJobPrefix => kStabilityLocalJobPrefix;

  @override
  Future<Uint8List> performGeneration(
    GenerationTask task,
    String apiKey,
  ) async {
    // multipart/form-data——Stability 不收 JSON body。
    final form = FormData.fromMap(<String, Object?>{
      'prompt': task.prompt,
      if (task.negativePrompt != null) 'negative_prompt': task.negativePrompt,
      'aspect_ratio': _mapAspectRatio(task.aspectRatio),
      if (task.seed != null) 'seed': task.seed.toString(),
      'output_format': kStabilityOutputFormat,
    });

    final resp = await dio.post<List<int>>(
      kStabilityCoreGeneratePath,
      data: form,
      options: Options(
        headers: <String, Object?>{
          'Authorization': 'Bearer $apiKey',
          'Accept': 'image/*',
        },
        // 仅此请求取 bytes；不动共享 Dio 的 JSON 默认。
        responseType: ResponseType.bytes,
        contentType: 'multipart/form-data',
      ),
    );

    // finish-reason 头：HTTP 200 也可能内容过滤（mapDioError 抓不到）。
    final finishReason = resp.headers.value('finish-reason');
    if (finishReason == 'CONTENT_FILTERED') {
      throw ProviderError(
        code: InkErrorCode.contentPolicy,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'content_filtered',
        },
      );
    }

    final raw = resp.data;
    if (raw == null || raw.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'empty_body'},
      );
    }
    return Uint8List.fromList(raw);
  }

  @override
  Future<void> performKeyValidation(String apiKey) async {
    // GET /v1/user/balance —— 返回 {"credits": float}，零生成配额消耗。
    // 200 即视为有效 Key——零余额不等于无效（UI 另行提示余额不足）。
    await dio.get<dynamic>(
      kStabilityBalancePath,
      options: Options(
        headers: <String, Object?>{'Authorization': 'Bearer $apiKey'},
      ),
    );
  }

  @override
  InkError? contentPolicyFromDioError(DioException e) {
    // Stability 的 403 是内容审核，非 invalidKey——先于 mapDioError 拦截。
    if (e.response?.statusCode == 403) {
      return ProviderError(
        code: InkErrorCode.contentPolicy,
        extra: {'provider_id': capabilities.providerId, 'status': 403},
        cause: e,
      );
    }
    return null;
  }

  /// AspectRatio 枚举 → Stability 的 aspect_ratio 字面量。
  String _mapAspectRatio(AspectRatio r) {
    switch (r) {
      case AspectRatio.r1x1:
        return '1:1';
      case AspectRatio.r16x9:
        return '16:9';
      case AspectRatio.r9x16:
        return '9:16';
      case AspectRatio.r4x3:
        return '4:3';
      case AspectRatio.r3x4:
        return '3:4';
      case AspectRatio.r21x9:
        return '21:9';
    }
  }
}
