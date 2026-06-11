// OpenAIImageProvider — OpenAI gpt-image-1 同步文生图。
//
// 接入参数（计划 2026-06-10-provider-dalle，权威至 2026-06-10）：
//   Base URL : https://api.openai.com/v1
//   Model ID : gpt-image-1（DALL-E 3 已于 2026-03-04 下线，改用 gpt-image-1）
//   Auth     : Authorization: Bearer <key>（从 keySource 读取）
//   Submit   : POST /images/generations（同步，response_format=b64_json）
//   Validate : GET /models（零生成配额）
//   Poll     : 无（同步返回，走 ADR-0004 inline-bytes 通道）
//
// 硬约束（PROVIDER-API.md §10 Step 1/2）：
// - capabilities 是 const 字段，编译期固定
// - 所有接入参数写死在本文件顶部 const 区，禁止散落字面量
// - 抛出 InkError 子类，禁止裸 DioException
// - 绝不硬编码 API Key——key 只经注入的 keySource 延迟读取

import 'dart:convert';
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

// ---- 接入参数（计划锁定） -------------------------------------------------
const String kOpenAIBaseUrl = 'https://api.openai.com/v1';
const String kOpenAIModel = 'gpt-image-1';
const String kOpenAIImagePath = '/images/generations';
const String kOpenAIValidatePath = '/models';

/// 同步返回的 inline 图片数据在本地合成 JobId 时使用的前缀。
const String kOpenAILocalJobPrefix = 'local://openai-image/';

// ---- 能力声明（PROVIDER-API.md §9.2） -----------------------------------
const ProviderCapabilities kOpenAIImageCapabilities = ProviderCapabilities(
  providerId: 'openai-image',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  // gpt-image-1 仅三种 size：1024x1024 / 1536x1024 / 1024x1536。
  // r4x3 / r3x4 / r21x9 无精确映射，不声明以免误导 UI。
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
  supportsSeed: false, // gpt-image-1 无 seed 参数
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  // 同步 Provider 仍走 Pollable 路径（poll 一调即返回 inlineBytes，详见 ADR-0004）。
  supportsPolling: true,
  // medium 质量 1024×1024 的官方单图估价（low ~0.02 / medium ~0.042 / high ~0.167）。
  costModel: CostModel.perCall(usdPerCall: 0.042),
  maxConcurrentJobs: 1,
  qps: 2,
  burst: 5,
);

/// Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef OpenAIKeySource = Future<String> Function();

class OpenAIImageProvider implements Submittable, Pollable, KeyValidatable {
  OpenAIImageProvider({
    required OpenAIKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _dio = dio ?? _buildDefaultDio();

  final OpenAIKeySource _keySource;
  final ProviderRateLimiter _rateLimiter;
  final Dio _dio;

  /// 仅供 DI 单测验证「共享 limiter」不变量。生产代码不要读这个。
  ProviderRateLimiter get rateLimiterForTesting => _rateLimiter;

  /// 同步 Provider 的 inline bytes 暂存（ADR-0004）。
  ///
  /// submit 解码 base64 后塞入；poll 一次性消费并删除。
  /// instance-scoped，Provider 销毁时随 GC 回收。
  final Map<JobId, Uint8List> _inlineCache = {};

  @override
  ProviderCapabilities get capabilities => kOpenAIImageCapabilities;

  static Dio _buildDefaultDio() => Dio(
        BaseOptions(
          baseUrl: kOpenAIBaseUrl,
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
    final body = <String, Object?>{
      'model': kOpenAIModel,
      'prompt': task.prompt,
      'n': 1,
      'size': _sizeFor(task.aspectRatio),
      'quality': 'medium',
      'response_format': 'b64_json',
    };

    try {
      final resp = await _dio.post<dynamic>(
        kOpenAIImagePath,
        data: body,
        options: Options(
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $key'},
        ),
      );
      final data = resp.data is Map
          ? Map<String, Object?>.from(resp.data as Map)
          : null;
      return _handleSubmitResponse(data, task);
    } on DioException catch (e) {
      // OpenAI 400 不靠 HTTP 状态码区分内容策略——必须先读 error.code。
      if (e.response?.statusCode == 400 &&
          _isContentPolicyViolation(e.response?.data)) {
        throw ProviderError(
          code: InkErrorCode.contentPolicy,
          extra: {'provider_id': capabilities.providerId},
          cause: e,
        );
      }
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    try {
      await _dio.get<dynamic>(
        kOpenAIValidatePath,
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      );
      return const KeyValidationResult.valid();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const KeyValidationResult.invalid(
            reason: KeyInvalidReason.networkTimeout,
            detail: 'validation timeout',
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return const KeyValidationResult.invalid(
            reason: KeyInvalidReason.networkOffline,
            detail: 'no network',
          );
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
          return KeyValidationResult.networkError(
            message: 'unexpected status $status',
          );
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          return KeyValidationResult.networkError(
            message: e.message ?? 'unknown',
          );
      }
    }
  }

  JobId _handleSubmitResponse(
    Map<String, Object?>? data,
    GenerationTask task,
  ) {
    if (data == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'empty_body'},
      );
    }
    final entries = data['data'];
    if (entries is! List || entries.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_data'},
      );
    }
    final first = entries.first;
    final base64Str = first is Map ? first['b64_json'] as String? : null;
    if (base64Str == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'no_b64_json',
        },
      );
    }
    final inline = base64Decode(base64Str);
    // 同步 Provider：合成本地 JobId，bytes 暂存 cache，等上层 poll 消费（ADR-0004）。
    final suffix = '${task.jobId}-${_rand()}';
    final jobId = '$kOpenAILocalJobPrefix$suffix';
    _inlineCache[jobId] = inline;
    return jobId;
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

  /// AspectRatio → gpt-image-1 size 字符串。capabilities 已收窄到三种比例，
  /// 其余分支为防御性兜底（UI 遵守 supportedRatios 时不可达）。
  String _sizeFor(AspectRatio ratio) {
    switch (ratio) {
      case AspectRatio.r1x1:
        return '1024x1024';
      case AspectRatio.r16x9:
        return '1536x1024';
      case AspectRatio.r9x16:
        return '1024x1536';
      case AspectRatio.r4x3:
      case AspectRatio.r3x4:
      case AspectRatio.r21x9:
        return '1024x1024';
    }
  }

  bool _isContentPolicyViolation(Object? body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        return err['code'] == 'content_policy_violation';
      }
    }
    return false;
  }

  static String _rand() =>
      Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
