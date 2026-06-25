// 同步图片 Provider 公共基类（对照 DashScopeAsyncProviderBase / ADR-0004 / ADR-0005）。
//
// gemini / openai / stability 共享：rate-limit + key 读取 + 本地 JobId 合成 + inlineBytes
// 暂存 + poll 消费 + DioException→KeyValidationResult 开关。各 Provider 仅实现
// performGeneration（HTTP+解码出 bytes）/ performKeyValidation（最轻量鉴权 GET）/
// contentPolicyFromDioError（可选：把内容审核类 DioException 翻成 contentPolicy）。
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/key_validation_result.dart';
import '../core/models/provider_capabilities.dart';
import 'dio_error_mapper.dart';
import 'rate_limiter.dart';

/// Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef SyncProviderKeySource = Future<String> Function();

abstract class SyncProviderBase
    implements Submittable, Pollable, KeyValidatable {
  SyncProviderBase({
    required SyncProviderKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _injectedDio = dio;

  final SyncProviderKeySource _keySource;
  final ProviderRateLimiter _rateLimiter;
  final Dio? _injectedDio;

  /// 注入优先，否则按子类 [baseUrl] 懒建默认 Dio（首次访问时初始化）。
  late final Dio _dio = _injectedDio ?? _buildDefaultDio(baseUrl);

  /// 同步 Provider 的 inline bytes 暂存（ADR-0004）：submit 塞入、poll 一次性消费。
  final Map<JobId, Uint8List> _inlineCache = {};

  /// 仅供 DI 单测验证「共享 limiter」不变量。生产代码不要读这个。
  ProviderRateLimiter get rateLimiterForTesting => _rateLimiter;

  /// 子类在 performGeneration / performKeyValidation 里用它发请求。
  Dio get dio => _dio;

  // ---- 子类必须提供 ------------------------------------------------------

  /// 默认 Dio 的 base URL（注入 dio 时不使用）。
  String get baseUrl;

  /// 本地合成 JobId 前缀，如 `local://gemini-image/`。
  String get localJobPrefix;

  /// 执行同步生成请求并返回原始图片字节。
  /// HTTP/解析失败抛 [ProviderError]；成功响应里的内容审核（如 Stability 的
  /// finish-reason 头）也在此直接抛 [ProviderError]（contentPolicy）。
  /// DioException 原样抛出，由基类统一映射。
  Future<Uint8List> performGeneration(GenerationTask task, String apiKey);

  /// 执行最轻量鉴权 GET（零生成配额）。成功即返回；失败抛 DioException。
  Future<void> performKeyValidation(String apiKey);

  /// 把内容审核类 DioException 翻成 [ProviderError]（contentPolicy）；否则返回 null。
  InkError? contentPolicyFromDioError(DioException e) => null;

  // ---- Submittable -------------------------------------------------------

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
    try {
      final bytes = await performGeneration(task, key);
      // 同步 Provider：合成本地 JobId，bytes 暂存 cache，等上层 poll 消费（ADR-0004）。
      final jobId = '$localJobPrefix${task.jobId}-${_rand()}';
      _inlineCache[jobId] = bytes;
      return jobId;
    } on DioException catch (e) {
      final policy = contentPolicyFromDioError(e);
      if (policy != null) throw policy;
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  // ---- Pollable ----------------------------------------------------------

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

  // ---- KeyValidatable ----------------------------------------------------

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    try {
      await performKeyValidation(key);
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
          return KeyValidationResult.networkError(
            message: e.message ?? 'unknown',
          );
      }
    }
  }

  // ---- 内部 --------------------------------------------------------------

  static String _rand() =>
      Random.secure().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

  static Dio _buildDefaultDio(String baseUrl) => Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          responseType: ResponseType.json,
        ),
      );
}
