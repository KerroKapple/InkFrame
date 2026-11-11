// FakeAnthropicClient：按脚本回放的 AnthropicClient，观察口语义与真客户端一致——
// 发出前先 await onRequest(encodeClaudeRequest(request))，拿到用量先 await onResponse，
// 拒答 / 截断再抛错。请求体用真编码器生成，日志里的 body 就是线上会发的那份。
import 'dart:async';

import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/anthropic_client.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/services/anthropic/claude_request_encoder.dart';

class FakeClaudeReply {
  /// 正常结束（end_turn），回 [text]。
  const FakeClaudeReply.text(this.text, {this.usage = const ClaudeUsage(inputTokens: 1000, outputTokens: 200), this.gate})
      : refusalCategory = null,
        error = null,
        refusal = false;

  /// 拒答：先交出带用量的回应，再抛 RefusalError。
  const FakeClaudeReply.refusal({this.refusalCategory, this.usage = const ClaudeUsage(inputTokens: 1000)})
      : text = '',
        error = null,
        refusal = true,
        gate = null;

  /// 没拿到回应的失败（网络 / 鉴权）：不交出回应，直接抛。
  const FakeClaudeReply.error(InkError this.error)
      : text = '',
        usage = const ClaudeUsage(),
        refusalCategory = null,
        refusal = false,
        gate = null;

  final String text;
  final ClaudeUsage usage;
  final String? refusalCategory;
  final InkError? error;
  final bool refusal;

  /// 非 null ⇒ 请求发出后卡在这里，放行才回（测「在途」）。
  final Completer<void>? gate;
}

class FakeAnthropicClient implements AnthropicClient {
  FakeAnthropicClient(List<FakeClaudeReply> replies) : _queue = List<FakeClaudeReply>.of(replies);

  final List<FakeClaudeReply> _queue;

  /// 调用方交进来的请求，按顺序。
  final List<ClaudeRequest> requests = <ClaudeRequest>[];

  /// 实际「发出」的请求体（onRequest 之后才记）。
  final List<Map<String, Object?>> sentBodies = <Map<String, Object?>>[];

  void enqueue(FakeClaudeReply r) => _queue.add(r);

  @override
  Future<ClaudeMessage> createMessage(
    ClaudeRequest request, {
    ClaudeExchangeObserver? observer,
  }) async {
    requests.add(request);
    final Map<String, Object?> body = encodeClaudeRequest(request);
    await observer?.onRequest(body, attempt: 0);
    sentBodies.add(body);
    if (_queue.isEmpty) throw StateError('FakeAnthropicClient: 脚本已用完');
    final FakeClaudeReply r = _queue.removeAt(0);
    await r.gate?.future;
    final InkError? error = r.error;
    if (error != null) throw error;
    final ClaudeExchangeResponse response = ClaudeExchangeResponse(
      id: 'msg_${sentBodies.length}',
      model: 'claude-opus-5-5',
      textBlocks: r.refusal ? const <String>[] : <String>[r.text],
      usage: r.usage,
      stopReason: r.refusal ? 'refusal' : 'end_turn',
      refusalCategory: r.refusalCategory,
    );
    await observer?.onResponse(response);
    if (r.refusal) throw RefusalError(category: r.refusalCategory);
    return ClaudeMessage(
      id: response.id,
      model: response.model,
      textBlocks: response.textBlocks,
      usage: response.usage,
      stopReason: ClaudeStopReason.endTurn,
    );
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async => const KeyValidationResult.valid();
}
