// AnthropicClient 的 dio 实现：raw HTTP（Anthropic 无官方 Dart SDK）。
//
// 每次请求固定：model claude-opus-5-5、thinking adaptive、fallbacks "default"
// + beta 头 server-side-fallback-2026-07-01、stream true。
// 结局判定顺序：HTTP 状态 → 流内 error 事件 → 记账 → stop_reason
// （refusal / max_tokens 先于读内容）。可重试错误按 retry-after 退避，最多 [maxRetries] 次。
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/errors/ink_error.dart';
import '../../core/interfaces/anthropic_client.dart';
import '../../core/interfaces/claude_usage_ledger.dart';
import '../../core/logging/logger_service.dart';
import '../../core/models/claude_message.dart';
import '../../core/models/key_validation_result.dart';
import '../../providers/dio_error_mapper.dart';
import 'anthropic_protocol.dart';
import 'claude_error_mapper.dart';
import 'claude_pricing.dart';
import 'claude_request_encoder.dart';
import 'claude_sse.dart';

/// 退避等待的注入口（测试传立即完成的实现，不真睡）。
typedef RetrySleep = Future<void> Function(Duration delay);

Future<void> _realSleep(Duration d) => Future<void>.delayed(d);

class DioAnthropicClient implements AnthropicClient {
  DioAnthropicClient({
    required Dio dio,
    required Future<String> Function() keySource,
    required ClaudeUsageLedger ledger,
    required Clock clock,
    RetrySleep sleep = _realSleep,
    this.maxRetries = 2,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 60),
  })  : _dio = dio,
        _keySource = keySource,
        _ledger = ledger,
        _clock = clock,
        _sleep = sleep;

  final Dio _dio;
  final Future<String> Function() _keySource;
  final ClaudeUsageLedger _ledger;
  final Clock _clock;
  final RetrySleep _sleep;

  /// 首次之外最多再试几次。
  final int maxRetries;

  /// 没有 retry-after 时的指数退避基数（1s、2s …）。
  final Duration baseBackoff;

  /// retry-after 再长也只等这么久。
  final Duration maxBackoff;

  @override
  Future<ClaudeMessage> createMessage(ClaudeRequest request) async {
    final Map<String, Object?> body = encodeClaudeRequest(request);
    final String key = await _keySource();
    for (int attempt = 0;; attempt++) {
      try {
        return _conclude(await _attempt(key, body), request);
      } on _AttemptFailure catch (f) {
        if (!f.error.retryable || attempt >= maxRetries) throw f.error;
        await _sleep(_delayFor(attempt, f.retryAfter));
      }
    }
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    final Response<Object?> resp;
    try {
      resp = await _dio.get<Object?>(
        AnthropicProtocol.modelsPath,
        options: Options(
          headers: _headers(key, withBeta: false),
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      return KeyValidationResult.networkError(message: e.type.name);
    }
    final int status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) return const KeyValidationResult.valid();
    if (status == 401 || status == 403) {
      return const KeyValidationResult.invalid(reason: KeyInvalidReason.invalidKey);
    }
    if (status == 402) {
      return const KeyValidationResult.invalid(
        reason: KeyInvalidReason.insufficientBalance,
      );
    }
    return KeyValidationResult.networkError(message: 'status $status');
  }

  Map<String, Object?> _headers(String key, {required bool withBeta}) =>
      <String, Object?>{
        AnthropicHeaders.apiKey: key,
        AnthropicHeaders.version: AnthropicProtocol.apiVersion,
        if (withBeta) AnthropicHeaders.beta: AnthropicProtocol.fallbackBeta,
      };

  Future<ClaudeStreamResult> _attempt(String key, Map<String, Object?> body) async {
    final Response<ResponseBody> resp;
    try {
      resp = await _dio.post<ResponseBody>(
        AnthropicProtocol.messagesPath,
        data: body,
        options: Options(
          headers: _headers(key, withBeta: true),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw _AttemptFailure(_mapDio(e), null);
    }
    final Duration? retryAfter =
        _parseRetryAfter(resp.headers.value(AnthropicHeaders.retryAfter));
    final int status = resp.statusCode ?? 0;
    final ResponseBody? stream = resp.data;
    if (status < 200 || status >= 300 || stream == null) {
      throw _AttemptFailure(
        mapClaudeErrorBody(status, await _readErrorBody(stream)),
        retryAfter,
      );
    }

    final ClaudeStreamAccumulator acc = ClaudeStreamAccumulator();
    try {
      await for (final SseFrame frame in parseSseEvents(stream.stream)) {
        acc.add(frame);
      }
      return acc.finish();
    } on InkError catch (e) {
      _recordPartial(acc);
      throw _AttemptFailure(e, retryAfter);
    } on DioException catch (e) {
      _recordPartial(acc);
      throw _AttemptFailure(_mapDio(e), retryAfter);
    } on FormatException catch (e) {
      _recordPartial(acc);
      throw _AttemptFailure(
        ProviderError(
          code: InkErrorCode.providerInvalidResponse,
          extra: const <String, Object?>{
            'provider_id': AnthropicProtocol.clientId,
            'reason': 'sse_bad_encoding',
          },
          cause: e,
        ),
        retryAfter,
      );
    }
  }

  /// 先记账（拒答、截断同样计费），再判 stop_reason。
  ClaudeMessage _conclude(ClaudeStreamResult r, ClaudeRequest request) {
    _record(r.model, r.usage);
    final Map<String, Object?> extra = <String, Object?>{
      'provider_id': AnthropicProtocol.clientId,
      'model': r.model,
    };
    switch (r.stopReason) {
      case AnthropicStopReasons.refusal:
        throw RefusalError(category: r.refusalCategory, extra: extra);
      case AnthropicStopReasons.maxTokens:
        throw ProviderError(
          code: InkErrorCode.outputTruncated,
          extra: <String, Object?>{...extra, 'max_tokens': request.maxTokens},
        );
    }
    return ClaudeMessage(
      id: r.id,
      model: r.model,
      textBlocks: r.textBlocks,
      usage: r.usage,
      stopReason: switch (r.stopReason) {
        AnthropicStopReasons.endTurn => ClaudeStopReason.endTurn,
        AnthropicStopReasons.stopSequence => ClaudeStopReason.stopSequence,
        AnthropicStopReasons.toolUse => ClaudeStopReason.toolUse,
        AnthropicStopReasons.pauseTurn => ClaudeStopReason.pauseTurn,
        _ => ClaudeStopReason.other,
      },
    );
  }

  void _recordPartial(ClaudeStreamAccumulator acc) {
    if (acc.usage != const ClaudeUsage()) _record(acc.model, acc.usage);
  }

  void _record(String model, ClaudeUsage usage) {
    _ledger.record(ClaudeUsageRecord(
      at: _clock.nowUtc(),
      model: model.isEmpty ? AnthropicProtocol.model : model,
      usage: usage,
      estimatedCostUsd: estimateClaudeCostUsd(usage),
    ));
  }

  Duration _delayFor(int attempt, Duration? retryAfter) {
    final Duration d = retryAfter ?? baseBackoff * (1 << attempt);
    return d > maxBackoff ? maxBackoff : d;
  }

  InkError _mapDio(DioException e) =>
      mapDioError(e, providerId: AnthropicProtocol.clientId);
}

/// 一次尝试的失败 + 服务端建议的等待时长。
class _AttemptFailure implements Exception {
  const _AttemptFailure(this.error, this.retryAfter);
  final InkError error;
  final Duration? retryAfter;
}

/// retry-after 只认秒数（整数或小数）；HTTP-date 形式走默认退避。
Duration? _parseRetryAfter(String? raw) {
  if (raw == null) return null;
  final double? seconds = double.tryParse(raw.trim());
  if (seconds == null || seconds < 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// 错误响应体（流式 responseType 下也是字节流）→ JSON；读不出来就 null。
Future<Object?> _readErrorBody(ResponseBody? body) async {
  if (body == null) return null;
  try {
    final String text = await utf8.decoder.bind(body.stream).join();
    return jsonDecode(text);
  } on FormatException {
    return null;
  } on DioException {
    return null;
  }
}
