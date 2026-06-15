// DashScope 异步 Provider 公共基类（ADR-0005）。
//
// 6 个具体 Provider 共享：
//   Wanx: image-pro / image / t2v / i2v / r2v
//   Kling: kling-v3-video-generation / kling-v3-omni-video-generation
//
// 所有阿里百炼下挂的异步模型都用同一个 sk-xxx Key + 同一套 task 状态机。

import 'dart:convert';
import 'dart:io';
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

/// DashScope 北京地域 base URL。
const String kDashScopeBaseUrl = 'https://dashscope.aliyuncs.com/api/v1';

/// 任务查询 endpoint 模板（GET）。
const String kDashScopeTasksPath = '/tasks';

/// 视频默认时长（秒）：task.durationSeconds<=0 时的兜底值。
const int kDashScopeDefaultDurationSeconds = 5;

/// (Resolution, AspectRatio) → DashScope `parameters.size`（视频档共用）。
const Map<Resolution, Map<AspectRatio, String>> kDashScopeVideoSizeMatrix = {
  Resolution.p720: {
    AspectRatio.r16x9: '1280*720',
    AspectRatio.r9x16: '720*1280',
    AspectRatio.r1x1: '720*720',
  },
  Resolution.p1080: {
    AspectRatio.r16x9: '1920*1080',
    AspectRatio.r9x16: '1080*1920',
    AspectRatio.r1x1: '1080*1080',
  },
};

// ---- DashScope 请求体字段名（网络协议字面量，保持英文常量） --------------
const String kDashScopeFieldImgUrl = 'img_url';
const String kDashScopeFieldLastFrameUrl = 'last_frame_url';
const String kDashScopeFieldRefImages = 'ref_images';
const String kDashScopeFieldN = 'n';
const String kDashScopeFieldRole = 'role';

/// API Key getter 协议——延迟读取，避免 Provider 持久化 Key。
typedef DashScopeKeySource = Future<String> Function();

/// task_status 枚举字面量。
class DashScopeTaskStatus {
  const DashScopeTaskStatus._();
  static const String pending = 'PENDING';
  static const String running = 'RUNNING';
  static const String succeeded = 'SUCCEEDED';
  static const String failed = 'FAILED';
  static const String canceled = 'CANCELED';
  static const String unknown = 'UNKNOWN';
}

abstract class DashScopeAsyncProviderBase
    implements Submittable, Pollable, KeyValidatable {
  DashScopeAsyncProviderBase({
    required DashScopeKeySource keySource,
    required ProviderRateLimiter rateLimiter,
    Dio? dio,
  })  : _keySource = keySource,
        _rateLimiter = rateLimiter,
        _dio = dio ?? _buildDefaultDio();

  final DashScopeKeySource _keySource;
  final ProviderRateLimiter _rateLimiter;
  final Dio _dio;

  /// 仅供 DI 单测验证「共享 limiter」不变量。生产代码不要读这个。
  ProviderRateLimiter get rateLimiterForTesting => _rateLimiter;

  // ---- 子类必须提供 ------------------------------------------------------

  /// POST 创建任务的 endpoint 路径（相对 base URL）。
  ///
  /// 示例：`/services/aigc/image-generation/generation`
  String get submitEndpoint;

  /// 构造 POST 请求 body（含 model / input / parameters）。
  Map<String, Object?> buildRequestBody(GenerationTask task);

  /// 把 SUCCEEDED 任务的 `output` 字段解析为 [JobStatus.success]。
  ///
  /// 各 Provider 字段路径不同：
  /// - 图片：`output.choices[0].message.content[].image`
  /// - 视频：`output.video_url`
  JobStatus parseSuccessOutput(Map<String, Object?> output);

  // ---- Submittable -------------------------------------------------------

  @override
  Future<JobId> submit(GenerationTask task) async {
    // HI-05：本地图片路径不许直发远端——先内联为 base64 data URI。
    final prepared = await _inlineLocalImages(task);
    await _rateLimiter.acquire();
    final key = await _keySource();
    try {
      final resp = await _dio.post<dynamic>(
        submitEndpoint,
        data: buildRequestBody(prepared),
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'X-DashScope-Async': 'enable',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = resp.data is Map
          ? Map<String, Object?>.from(resp.data as Map)
          : null;
      final taskId = _extractTaskId(data);
      if (taskId == null) {
        throw ProviderError(
          code: InkErrorCode.providerServer,
          extra: {
            'provider_id': capabilities.providerId,
            'reason': 'no_task_id',
          },
        );
      }
      return taskId;
    } on DioException catch (e) {
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  // ---- Pollable ----------------------------------------------------------

  @override
  Future<JobStatus> poll(JobId taskId) async {
    final key = await _keySource();
    try {
      final resp = await _dio.get<dynamic>(
        '$kDashScopeTasksPath/$taskId',
        options: Options(
          headers: {'Authorization': 'Bearer $key'},
        ),
      );
      final data = resp.data is Map
          ? Map<String, Object?>.from(resp.data as Map)
          : null;
      final output = data?['output'];
      if (output is! Map) {
        throw ProviderError(
          code: InkErrorCode.providerServer,
          extra: {
            'provider_id': capabilities.providerId,
            'reason': 'no_output',
            'task_id': taskId,
          },
        );
      }
      final outputMap = Map<String, Object?>.from(output);
      final status = outputMap['task_status'] as String?;
      switch (status) {
        case DashScopeTaskStatus.pending:
        case DashScopeTaskStatus.running:
          return const JobStatus.inProgress();
        case DashScopeTaskStatus.succeeded:
          return parseSuccessOutput(outputMap);
        case DashScopeTaskStatus.failed:
          final code = outputMap['code'] as String?;
          final message = outputMap['message'] as String?;
          return JobStatus.failure(
            error: ProviderError(
              code: _mapAliyunErrorCode(code),
              extra: {
                'provider_id': capabilities.providerId,
                'aliyun_code': code,
                'aliyun_message': message,
                'task_id': taskId,
              },
            ),
          );
        case DashScopeTaskStatus.canceled:
          return JobStatus.failure(
            error: CancelledError.byUser(extra: {'task_id': taskId}),
          );
        case DashScopeTaskStatus.unknown:
        default:
          // task_id 24h 过期或未知状态——终态，不可重试。
          return JobStatus.failure(
            error: ProviderError(
              code: InkErrorCode.providerInvalidResponse,
              extra: {
                'provider_id': capabilities.providerId,
                'reason': 'unknown_status',
                'task_id': taskId,
              },
            ),
          );
      }
    } on DioException catch (e) {
      throw mapDioError(e, providerId: capabilities.providerId);
    }
  }

  // ---- KeyValidatable ----------------------------------------------------

  /// 默认实现：GET /tasks/{bogus}。
  /// - 401/403 → invalidKey（HI-03：validateStatus 放行后必须显式查 statusCode）
  /// - 200/404 → valid（key 通过鉴权，task 不存在不影响）
  /// - 其他 → networkError（含超时/离线——无法判定 Key 本身，ME-10）
  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    try {
      final resp = await _dio.get<dynamic>(
        '$kDashScopeTasksPath/inkframe-validation-bogus-id',
        options: Options(
          headers: {'Authorization': 'Bearer $key'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final status = resp.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const KeyValidationResult.invalid(
          reason: KeyInvalidReason.invalidKey,
        );
      }
      if (status == 200 || status == 404) {
        return const KeyValidationResult.valid();
      }
      return KeyValidationResult.networkError(
        message: 'unexpected status $status',
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return const KeyValidationResult.invalid(
          reason: KeyInvalidReason.invalidKey,
        );
      }
      return KeyValidationResult.networkError(
        message: e.message ?? 'unknown',
      );
    }
  }

  // ---- 子类共用 helper ----------------------------------------------------

  /// 视频类 Provider 共用：解析 `output.video_url` 单一 URL。
  ///
  /// HI-04：SUCCEEDED 但缺产物 URL 不许标 success——直接抛 ProviderError。
  /// 这是远端报终态成功却无产物的确定性失败，不可重试（providerInvalidResponse），
  /// 否则上层轮询会对一个不可变的终态响应反复重试直到 pollTimeout（约 30min）。
  JobStatus parseSingleVideoUrlOutput(Map<String, Object?> output) {
    final url = output['video_url'] as String?;
    if (url == null || url.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'empty_output_url',
        },
      );
    }
    return JobStatus.success(remoteUrls: [url]);
  }

  // ---- 内部 helper -------------------------------------------------------

  /// HI-05：把 task 中本地文件引用内联为 base64 data URI。
  /// http(s)/data 引用原样透传；DashScope 各端点均接受
  /// `data:{MIME};base64,{data}` 形式的图片输入。
  Future<GenerationTask> _inlineLocalImages(GenerationTask task) async {
    if (task.refImagePaths.isEmpty &&
        task.firstFramePath == null &&
        task.lastFramePath == null) {
      return task;
    }
    return task.copyWith(
      refImagePaths: [
        for (final p in task.refImagePaths) await _toDataUriIfLocal(p),
      ],
      firstFramePath: task.firstFramePath == null
          ? null
          : await _toDataUriIfLocal(task.firstFramePath!),
      lastFramePath: task.lastFramePath == null
          ? null
          : await _toDataUriIfLocal(task.lastFramePath!),
    );
  }

  Future<String> _toDataUriIfLocal(String ref) async {
    final lower = ref.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:')) {
      return ref;
    }
    final Uint8List bytes;
    try {
      bytes = await File(ref).readAsBytes();
    } on FileSystemException catch (e) {
      throw LocalIOError(
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'ref_image_unreadable',
          'path': ref,
        },
        cause: e,
      );
    }
    return 'data:${_mimeForPath(lower)};base64,${base64Encode(bytes)}';
  }

  String _mimeForPath(String lowerPath) {
    final dot = lowerPath.lastIndexOf('.');
    final ext = dot >= 0 ? lowerPath.substring(dot + 1) : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }

  String? _extractTaskId(Map<String, Object?>? data) {
    if (data == null) return null;
    final output = data['output'];
    if (output is! Map) return null;
    return output['task_id'] as String?;
  }

  /// 阿里云错误码 → InkErrorCode 映射（PROVIDER-API §6.3）。
  InkErrorCode _mapAliyunErrorCode(String? aliyunCode) {
    switch (aliyunCode) {
      case 'InvalidApiKey':
        return InkErrorCode.invalidKey;
      case 'IPInfringementSuspect':
      case 'DataInspectionFailed':
        return InkErrorCode.contentPolicy;
      case 'InvalidParameter':
        return InkErrorCode.invalidParameter;
      case 'Throttling':
      case 'Throttling.RateQuota':
        return InkErrorCode.providerBusy;
      case 'InsufficientBalance':
        return InkErrorCode.insufficientBalance;
      default:
        return InkErrorCode.providerServer;
    }
  }

  static Dio _buildDefaultDio() => Dio(
        BaseOptions(
          baseUrl: kDashScopeBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          responseType: ResponseType.json,
        ),
      );
}
