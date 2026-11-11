// 导演事件 payload 的编解码（键见 core/constants/director_keys.dart）。
//
// 只做「值 ↔ JSON」，不碰仓储；写哪件事件、接在谁后面由 DirectorStepRunner /
// DirectorSessionController 决定。
import '../../../core/constants/director_keys.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/claude_message.dart';
import '../../../core/models/director.dart';

Map<String, Object?> usageToJson(ClaudeUsage u) => <String, Object?>{
      DirectorUsageKeys.inputTokens: u.inputTokens,
      DirectorUsageKeys.outputTokens: u.outputTokens,
      DirectorUsageKeys.cacheCreationInputTokens: u.cacheCreationInputTokens,
      DirectorUsageKeys.cacheReadInputTokens: u.cacheReadInputTokens,
    };

/// 宽容解析：缺键 / 非数字当 0。
ClaudeUsage usageFromJson(Object? raw) {
  if (raw is! Map) return const ClaudeUsage();
  int read(String k) {
    final Object? v = raw[k];
    return v is num ? v.toInt() : 0;
  }

  return ClaudeUsage(
    inputTokens: read(DirectorUsageKeys.inputTokens),
    outputTokens: read(DirectorUsageKeys.outputTokens),
    cacheCreationInputTokens: read(DirectorUsageKeys.cacheCreationInputTokens),
    cacheReadInputTokens: read(DirectorUsageKeys.cacheReadInputTokens),
  );
}

/// script_submitted：剧本原文 + 之前驳回时留下的意见（按时间先后）。
Map<String, Object?> scriptSubmittedPayload({
  required String step,
  required String text,
  required List<String> feedback,
}) =>
    <String, Object?>{
      DirectorPayloadKeys.step: step,
      DirectorPayloadKeys.text: text,
      DirectorPayloadKeys.feedback: feedback,
    };

/// model_request：实际发出的请求体原样放在 body 下。
Map<String, Object?> modelRequestPayload({
  required String step,
  required Map<String, Object?> body,
  required int attempt,
}) =>
    <String, Object?>{
      DirectorPayloadKeys.step: step,
      DirectorPayloadKeys.attempt: attempt,
      DirectorPayloadKeys.body: body,
    };

Map<String, Object?> modelResponsePayload({
  required String step,
  required ClaudeExchangeResponse response,
}) =>
    <String, Object?>{
      DirectorPayloadKeys.step: step,
      DirectorPayloadKeys.messageId: response.id,
      DirectorPayloadKeys.model: response.model,
      DirectorPayloadKeys.content: response.textBlocks,
      DirectorPayloadKeys.usage: usageToJson(response.usage),
      DirectorPayloadKeys.stopReason: response.stopReason,
      DirectorPayloadKeys.refusalCategory: response.refusalCategory,
      DirectorPayloadKeys.partial: response.partial,
    };

Map<String, Object?> modelFailedPayload({
  required String step,
  required InkError error,
}) =>
    <String, Object?>{
      DirectorPayloadKeys.step: step,
      DirectorPayloadKeys.code: error.code.wire,
      if (error case RefusalError(:final String category))
        DirectorPayloadKeys.refusalCategory: category,
    };

/// model_failed 里记的错误码；认不出 ⇒ unknown。
InkErrorCode failedCodeOf(DirectorEvent e) {
  final Object? code = e.payload[DirectorPayloadKeys.code];
  return code is String ? InkErrorCode.fromWire(code) : InkErrorCode.unknown;
}

/// script_submitted 的原文与意见。
({String text, List<String> feedback}) scriptOf(DirectorEvent e) {
  final Object? text = e.payload[DirectorPayloadKeys.text];
  final Object? feedback = e.payload[DirectorPayloadKeys.feedback];
  return (
    text: text is String ? text : '',
    feedback: feedback is List
        ? <String>[for (final Object? f in feedback) if (f is String) f]
        : const <String>[],
  );
}

/// 事件里记的提案 seq（human_* 用）。
int? proposalSeqOf(DirectorEvent e) {
  final Object? v = e.payload[DirectorPayloadKeys.proposalSeq];
  return v is int ? v : null;
}
