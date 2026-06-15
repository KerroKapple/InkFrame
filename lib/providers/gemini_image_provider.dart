// GeminiImageProvider — Gemini 2.5 flash image preview 同步生成。
//
// PRD §10.2.1 接入参数：
//   Base URL : https://generativelanguage.googleapis.com/v1beta
//   Model ID : gemini-2.5-flash-image-preview
//   Auth     : x-goog-api-key 请求头（从 keySource 读取；LO-13 禁止进 URL）
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

/// LO-13：API Key 经请求头传递，绝不进 URL query（防日志/代理泄露）。
const String kGeminiApiKeyHeader = 'x-goog-api-key';

// ---- 能力声明（PROVIDER-API.md §9.2） -----------------------------------
const ProviderCapabilities kGeminiImageCapabilities = ProviderCapabilities(
  providerId: 'gemini-image',
  displayName: 'Gemini Image',
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
        // HI-27：image-preview 模型要求 TEXT+IMAGE 双模态，仅 IMAGE 会被拒。
        'responseModalities': ['TEXT', 'IMAGE'],
        // HI-07：aspectRatio 接入 imageConfig，不许静默忽略。
        'imageConfig': <String, Object?>{
          'aspectRatio': _aspectRatioFor(task.aspectRatio),
        },
      },
    };

    try {
      final resp = await _dio.post<dynamic>(
        kGeminiSubmitPath,
        data: body,
        options: Options(
          contentType: 'application/json',
          headers: {kGeminiApiKeyHeader: key},
        ),
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
        queryParameters: {'pageSize': 1},
        options: Options(headers: {kGeminiApiKeyHeader: key}),
      );
      return const KeyValidationResult.valid();
    } on DioException catch (e) {
      switch (e.type) {
        // ME-10：超时/离线无法判定 Key 本身 → networkError（与全 Provider 统一）。
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

  /// AspectRatio 枚举 → Gemini imageConfig.aspectRatio 字面量。
  /// capabilities 已收窄到前五种；r21x9 为防御性兜底。
  String _aspectRatioFor(AspectRatio ratio) {
    switch (ratio) {
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
