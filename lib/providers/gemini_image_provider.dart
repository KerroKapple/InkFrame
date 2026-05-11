// GeminiImageProvider — Gemini 2.5 flash image preview 同步生成。
//
// PRD §10.2.1 接入参数：
//   Base URL : https://generativelanguage.googleapis.com/v1beta
//   Model ID : gemini-2.5-flash-image-preview
//   Auth     : ?key= query 参数（从 keySource 读取）
//   Submit   : POST /models/{model}:generateContent
//   Poll     : 无（同步返回）
//
// 硬约束（PROVIDER-API.md §10 Step 1/2）：
// - capabilities 是 const 字段，编译期固定
// - 所有接入参数写死在本文件顶部 const 区
// - 抛出 InkError 子类，禁止裸 DioException

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

// ---- 接入参数（PRD §10.2.1 锁定） ----------------------------------------
const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta';
const String kGeminiModel = 'gemini-2.5-flash-image-preview';
const String kGeminiSubmitPath = '/models/$kGeminiModel:generateContent';
const String kGeminiValidatePath = '/models';

// ---- 能力声明（PROVIDER-API.md §9.2） -----------------------------------
const ProviderCapabilities kGeminiImageCapabilities = ProviderCapabilities(
  providerId: 'gemini-image',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
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
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  // 同步 Provider 仍走 Pollable 路径（poll 一调即返回 inlineBytes，详见 ADR-0004）。
  supportsPolling: true,
  costModel: CostModel.perCharInput(
    usdPerKChar: 0.000075,
    usdPerImageOutput: 0.039,
  ),
  maxConcurrentJobs: 1,
  qps: 2,
  burst: 10,
);

/// 同步返回的 inline 图片数据在本地生成 JobId 时使用的前缀。
const String kGeminiLocalJobPrefix = 'local://gemini-image/';

/// Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef GeminiKeySource = Future<String> Function();

class GeminiImageProvider implements Submittable, Pollable, KeyValidatable {
  GeminiImageProvider({
    required GeminiKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _dio = dio ?? _buildDefaultDio();

  final GeminiKeySource _keySource;
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
  ProviderCapabilities get capabilities => kGeminiImageCapabilities;

  static Dio _buildDefaultDio() => Dio(
        BaseOptions(
          baseUrl: kGeminiBaseUrl,
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
        extra: {'provider_id': capabilities.providerId, 'reason': 'empty_prompt'},
      );
    }

    await _rateLimiter.acquire();

    final key = await _keySource();
    final body = <String, Object?>{
      'contents': [
        {
          'parts': [
            {'text': task.prompt},
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        if (task.seed != null) 'seed': task.seed,
        'responseModalities': ['IMAGE'],
      },
    };

    try {
      final resp = await _dio.post<dynamic>(
        kGeminiSubmitPath,
        queryParameters: {'key': key},
        data: body,
        options: Options(contentType: 'application/json'),
      );
      final data = resp.data is Map
          ? Map<String, Object?>.from(resp.data as Map)
          : null;
      return _handleSubmitResponse(data, task);
    } on DioException catch (e) {
      // Gemini 400 的 message 包含 "SAFETY" / "blocked" → 归 content_policy
      if (e.response?.statusCode == 400 && _isContentPolicy(e.response?.data)) {
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
        kGeminiValidatePath,
        queryParameters: {'key': key, 'pageSize': 1},
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
          return KeyValidationResult.networkError(message: e.message ?? 'unknown');
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
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_candidates'},
      );
    }
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'];
    if (parts is! List) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_parts'},
      );
    }
    Uint8List? inline;
    for (final p in parts) {
      if (p is Map && p['inlineData'] is Map) {
        final base64Str = (p['inlineData'] as Map)['data'] as String?;
        if (base64Str != null) {
          inline = base64Decode(base64Str);
          break;
        }
      }
    }
    if (inline == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_inline_data'},
      );
    }
    // 同步 Provider：合成本地 JobId，bytes 暂存 cache，等上层 poll 消费（ADR-0004）。
    final suffix = '${task.jobId}-${_rand()}';
    final jobId = '$kGeminiLocalJobPrefix$suffix';
    _inlineCache[jobId] = inline;
    return jobId;
  }

  @override
  Future<JobStatus> poll(JobId id) async {
    final bytes = _inlineCache.remove(id);
    if (bytes == null) {
      // 重复 poll 同一 jobId 或 jobId 未由本 instance submit 产生
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

  bool _isContentPolicy(Object? body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        final msg = (err['message'] as String?)?.toLowerCase() ?? '';
        return msg.contains('safety') || msg.contains('blocked');
      }
    }
    return false;
  }

  static String _rand() =>
      Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
