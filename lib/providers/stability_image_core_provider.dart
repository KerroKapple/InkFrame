// StabilityImageCoreProvider — Stability AI Stable Image Core 同步文生图。
//
// 接入参数（Stability AI REST v2beta）：
//   Base URL : https://api.stability.ai
//   Generate : POST /v2beta/stable-image/generate/core
//   Auth     : Authorization: Bearer {key}（从 keySource 读取）
//   Validate : GET /v1/user/balance（v1 legacy，仍有效，零生成配额消耗）
//   Submit   : 同步——单次 POST 直接返回原始图片字节（HTTP 200 + body）
//   Poll     : 无远端轮询；走 ADR-0004 inlineBytes 暂存通道
//
// 三个区别于其它 JSON Provider 的特殊点：
//   1. 请求体 multipart/form-data（FormData.fromMap），非 application/json
//   2. 响应 ResponseType.bytes（仅此 Provider 不解析 JSON）——逐请求 Options 设置，
//      不污染共享 Dio 的 JSON 默认
//   3. finish-reason 响应头：HTTP 200 也可能是 CONTENT_FILTERED（内容过滤），
//      必须读 response.headers，mapDioError 抓不到这种情况
//
// 硬约束（PROVIDER-API.md §10）：
// - capabilities 是 const 字段，编译期固定
// - 接入参数写死在本文件顶部 const 区，不散落
// - 抛出 InkError 子类，禁止裸 DioException
// - Key 仅经注入的 keySource 读取，绝不硬编码

import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/key_validation_result.dart';
import '../core/models/provider_capabilities.dart';
import 'dio_error_mapper.dart';
import 'rate_limiter.dart';

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

/// Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef StabilityKeySource = Future<String> Function();

class StabilityImageCoreProvider
    implements Submittable, Pollable, KeyValidatable {
  StabilityImageCoreProvider({
    required StabilityKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _dio = dio ?? _buildDefaultDio();

  final StabilityKeySource _keySource;
  final ProviderRateLimiter _rateLimiter;
  final Dio _dio;

  /// 仅供 DI 单测验证「共享 limiter」不变量。生产代码不要读这个。
  ProviderRateLimiter get rateLimiterForTesting => _rateLimiter;

  /// 同步 Provider 的 inline bytes 暂存（ADR-0004）。
  /// submit 成功后塞入；poll 一次性消费并删除。instance-scoped，随 GC 回收。
  final Map<JobId, Uint8List> _inlineCache = {};

  @override
  ProviderCapabilities get capabilities => kStabilityImageCoreCapabilities;

  static Dio _buildDefaultDio() => Dio(
        BaseOptions(
          baseUrl: kStabilityBasePath,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          responseType: ResponseType.json,
        ),
      );

  @override
  Future<JobId> submit(GenerationTask task) async {
    if (task.mode != GenerationMode.textToImage) {
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {'provider_id': capabilities.providerId, 'reason': 'mode'},
      );
    }
    if (task.prompt.trim().isEmpty) {
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'empty_prompt',
        },
      );
    }

    await _rateLimiter.acquire();

    final key = await _keySource();
    // multipart/form-data——Stability 不收 JSON body。
    final form = FormData.fromMap(<String, Object?>{
      'prompt': task.prompt,
      if (task.negativePrompt != null) 'negative_prompt': task.negativePrompt,
      'aspect_ratio': _mapAspectRatio(task.aspectRatio),
      if (task.seed != null) 'seed': task.seed.toString(),
      'output_format': kStabilityOutputFormat,
    });

    try {
      final resp = await _dio.post<List<int>>(
        kStabilityCoreGeneratePath,
        data: form,
        options: Options(
          headers: <String, Object?>{
            'Authorization': 'Bearer $key',
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
          extra: {
            'provider_id': capabilities.providerId,
            'reason': 'empty_body',
          },
        );
      }
      final bytes = Uint8List.fromList(raw);

      // 同步 Provider：合成本地 JobId，bytes 暂存 cache，等上层 poll 消费。
      final jobId = '$kStabilityLocalJobPrefix${task.jobId}-${_rand()}';
      _inlineCache[jobId] = bytes;
      return jobId;
    } on DioException catch (e) {
      // Stability 的 403 是内容审核，非 invalidKey——先于 mapDioError 拦截。
      if (e.response?.statusCode == 403) {
        throw ProviderError(
          code: InkErrorCode.contentPolicy,
          extra: {'provider_id': capabilities.providerId, 'status': 403},
          cause: e,
        );
      }
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    try {
      // GET /v1/user/balance —— 返回 {"credits": float}，零生成配额消耗。
      await _dio.get<dynamic>(
        kStabilityBalancePath,
        options: Options(
          headers: <String, Object?>{'Authorization': 'Bearer $key'},
        ),
      );
      // 200 即视为有效 Key——零余额不等于无效（UI 另行提示余额不足）。
      return const KeyValidationResult.valid();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const KeyValidationResult.networkError(
            message: 'validation timeout',
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return const KeyValidationResult.networkError(message: 'no network');
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode ?? 0;
          if (status == 401 || status == 403) {
            return const KeyValidationResult.invalid(
              reason: KeyInvalidReason.invalidKey,
            );
          }
          if (status == 402) {
            return const KeyValidationResult.invalid(
              reason: KeyInvalidReason.insufficientBalance,
            );
          }
          return KeyValidationResult.networkError(message: 'status $status');
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          return KeyValidationResult.networkError(
            message: e.message ?? 'unknown',
          );
      }
    }
  }

  @override
  Future<JobStatus> poll(JobId id) async {
    final bytes = _inlineCache.remove(id);
    if (bytes == null) {
      // 重复 poll 同一 jobId 或 jobId 未由本 instance submit 产生。
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'cache_miss_or_consumed',
          'job_id': id,
        },
      );
    }
    return JobStatus.success(remoteUrls: const [], inlineBytes: [bytes]);
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

  static String _rand() =>
      Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
