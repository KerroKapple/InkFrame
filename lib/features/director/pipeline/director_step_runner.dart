// 跑一轮导演步骤的模型部分：组请求 → 调用（经观察口把每次实际发出的请求体与回应写进日志）→
// 解析 → 写提案；失败写 model_failed。人工关口不在这里。
//
// 本轮写的事件串成一条链：每件接在上一件之后（parent_seq = 本轮的链头）。
// 取消：调用方把 [DirectorCancelToken] 置位后，还没发出的请求不再发，回来的结果只入日志、
// 不再出提案——model_failed(cancelled_by_user) 由调用方在取消当下写。
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/anthropic_client.dart';
import '../../../core/models/claude_message.dart';
import '../../../core/models/director.dart';
import '../log/director_log.dart';
import '../log/director_payloads.dart';
import 'director_step.dart';

/// 追加一件事件（DirectorSessionController 提供，背后是仓储）。
typedef DirectorAppend = Future<DirectorEvent> Function(
  DirectorEventKind kind, {
  int? parentSeq,
  Map<String, Object?> payload,
  String? contentLanguage,
  DirectorSetting? setting,
});

class DirectorCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// 一轮的结局。
sealed class DirectorRunOutcome<P> {
  const DirectorRunOutcome();
}

final class DirectorRunProposed<P> extends DirectorRunOutcome<P> {
  const DirectorRunProposed(this.proposal, this.event);
  final P proposal;

  /// 提案事件（它的 seq 就是新的链头）。
  final DirectorEvent event;
}

final class DirectorRunFailed<P> extends DirectorRunOutcome<P> {
  const DirectorRunFailed(this.error, this.event);
  final InkError error;

  /// model_failed 事件。
  final DirectorEvent event;
}

/// 已取消：结果丢弃（模型可见的部分照样入了日志）。
final class DirectorRunCancelled<P> extends DirectorRunOutcome<P> {
  const DirectorRunCancelled();
}

class DirectorStepRunner {
  DirectorStepRunner({required AnthropicClient client, required DirectorAppend append})
      : _client = client,
        _append = append;

  final AnthropicClient _client;
  final DirectorAppend _append;

  /// 本轮链头：取消时 model_failed 接在这里。
  int get head => _head;
  int _head = 0;

  Future<DirectorRunOutcome<P>> run<P>(
    DirectorStep<P> step, {
    required DirectorSession session,
    required DirectorLog log,
    required int inputSeq,
    required DirectorCancelToken cancel,
  }) async {
    _head = inputSeq;
    final _LoggingObserver observer = _LoggingObserver(this, step.id, cancel);
    final ClaudeMessage message;
    final P proposal;
    try {
      final ClaudeRequest request =
          step.buildRequest(session: session, log: log, inputSeq: inputSeq);
      message = await _client.createMessage(request, observer: observer);
      if (cancel.isCancelled) return DirectorRunCancelled<P>();
      proposal = step.parse(message);
    } on InkError catch (e) {
      if (cancel.isCancelled) return DirectorRunCancelled<P>();
      final DirectorEvent failed = await _chain(
        DirectorEventKind.modelFailed,
        modelFailedPayload(step: step.id, error: e),
      );
      return DirectorRunFailed<P>(e, failed);
    }
    final DirectorSessionPatch patch = step.sessionPatchOf(proposal);
    final DirectorEvent proposed = await _chain(
      step.proposedKind,
      step.encodeProposal(proposal),
      contentLanguage: patch.contentLanguage,
      setting: patch.setting,
    );
    return DirectorRunProposed<P>(proposal, proposed);
  }

  Future<DirectorEvent> _chain(
    DirectorEventKind kind,
    Map<String, Object?> payload, {
    String? contentLanguage,
    DirectorSetting? setting,
  }) async {
    final DirectorEvent e = await _append(
      kind,
      parentSeq: _head,
      payload: payload,
      contentLanguage: contentLanguage,
      setting: setting,
    );
    _head = e.seq;
    return e;
  }
}

/// 模型可见即入日志：每次发出前写 model_request，每次带用量的回应写 model_response。
class _LoggingObserver implements ClaudeExchangeObserver {
  _LoggingObserver(this._runner, this._step, this._cancel);

  final DirectorStepRunner _runner;
  final String _step;
  final DirectorCancelToken _cancel;

  @override
  Future<void> onRequest(Map<String, Object?> body, {required int attempt}) async {
    if (_cancel.isCancelled) throw const CancelledError.byUser();
    await _runner._chain(
      DirectorEventKind.modelRequest,
      modelRequestPayload(step: _step, body: body, attempt: attempt),
    );
  }

  @override
  Future<void> onResponse(ClaudeExchangeResponse response) async {
    await _runner._chain(
      DirectorEventKind.modelResponse,
      modelResponsePayload(step: _step, response: response),
    );
  }
}
