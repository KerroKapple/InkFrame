// Anthropic 错误响应 → InkError（shared/error-codes.md）。
//
// HTTP 层按状态码判；流内 error 事件（无状态码）按 error.type 判。
// 只保留截断后的 error.type / message 摘要，不带原始 body。
import '../../core/errors/ink_error.dart';
import 'anthropic_protocol.dart';

/// [status] 为 null ⇒ 流内 error 事件。
InkError mapClaudeErrorBody(int? status, Object? body) {
  final (String? type, String? message) = _brief(body);
  final Map<String, Object?> extra = <String, Object?>{
    'provider_id': AnthropicProtocol.clientId,
    'status': ?status,
    'body_code': ?type,
    if (message != null) 'body_message': _clip(message, 300),
  };
  final InkErrorCode code = status != null ? _byStatus(status) : _byType(type);
  return ProviderError(code: code, extra: extra);
}

InkErrorCode _byStatus(int status) {
  if (status == 401 || status == 403) return InkErrorCode.invalidKey;
  if (status == 402) return InkErrorCode.insufficientBalance;
  if (status == 429 || status == 529) return InkErrorCode.providerBusy;
  if (status >= 500) return InkErrorCode.providerServer;
  return InkErrorCode.invalidParameter;
}

InkErrorCode _byType(String? type) => switch (type) {
      AnthropicErrorTypes.rateLimit ||
      AnthropicErrorTypes.overloaded =>
        InkErrorCode.providerBusy,
      AnthropicErrorTypes.authentication ||
      AnthropicErrorTypes.permission =>
        InkErrorCode.invalidKey,
      AnthropicErrorTypes.billing => InkErrorCode.insufficientBalance,
      AnthropicErrorTypes.api || null => InkErrorCode.providerServer,
      _ => InkErrorCode.invalidParameter,
    };

(String?, String?) _brief(Object? body) {
  if (body is! Map) return (null, null);
  final Object? err = body[AnthropicJson.error];
  if (err is! Map) return (null, null);
  final Object? type = err[AnthropicJson.type];
  final Object? message = err[AnthropicJson.message];
  return (type is String ? type : null, message is String ? message : null);
}

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
