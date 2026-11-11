// 用量账从事件日志派生：每件 model_response 一行（拒答 / 流中断也算，不论在哪条分支），
// 其它事件不计；费用按 claude-opus-5-5 价目估。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/features/director/log/claude_usage_ledger.dart';
import 'package:inkframe/features/director/log/director_payloads.dart';

DirectorEvent _e(int seq, DirectorEventKind kind, {Map<String, Object?> payload = const <String, Object?>{}, int? parent}) =>
    DirectorEvent(
      id: 'e$seq',
      sessionId: 's',
      seq: seq,
      kind: kind,
      parentSeq: parent,
      payload: payload,
      createdAt: DateTime.utc(2026, 11, 11, 9, seq),
    );

Map<String, Object?> _resp(ClaudeUsage u, {String? stop = 'end_turn', bool partial = false}) =>
    modelResponsePayload(
      step: 'storyboard',
      response: ClaudeExchangeResponse(
        id: 'm',
        model: 'claude-opus-5-5',
        textBlocks: const <String>[],
        usage: u,
        stopReason: stop,
        partial: partial,
      ),
    );

void main() {
  test('只数 model_response；跨分支、拒答、流中断都计费', () {
    final ClaudeUsageLedger ledger = ClaudeUsageLedger.fromEvents(<DirectorEvent>[
      _e(1, DirectorEventKind.scriptSubmitted),
      _e(2, DirectorEventKind.modelRequest, parent: 1),
      _e(3, DirectorEventKind.modelResponse,
          parent: 2, payload: _resp(const ClaudeUsage(inputTokens: 1000000), stop: 'refusal')),
      _e(4, DirectorEventKind.modelFailed, parent: 3),
      _e(5, DirectorEventKind.scriptSubmitted),
      _e(6, DirectorEventKind.modelRequest, parent: 5),
      _e(7, DirectorEventKind.modelResponse,
          parent: 6, payload: _resp(const ClaudeUsage(outputTokens: 500000), partial: true)),
    ]);
    expect(ledger.records, hasLength(2));
    expect(ledger.records.first.at, DateTime.utc(2026, 11, 11, 9, 3));
    expect(ledger.records.first.model, 'claude-opus-5-5');
    expect(ledger.totalUsage, const ClaudeUsage(inputTokens: 1000000, outputTokens: 500000));
    expect(ledger.totalCostUsd, closeTo(14, 1e-9));
  });

  test('空日志 ⇒ 零', () {
    final ClaudeUsageLedger ledger = ClaudeUsageLedger.fromEvents(const <DirectorEvent>[]);
    expect(ledger.records, isEmpty);
    expect(ledger.totalCostUsd, 0);
  });

  test('记账行不可外改', () {
    final ClaudeUsageLedger ledger = ClaudeUsageLedger.fromEvents(<DirectorEvent>[
      _e(1, DirectorEventKind.modelResponse, payload: _resp(const ClaudeUsage())),
    ]);
    expect(() => ledger.records.clear(), throwsUnsupportedError);
  });
}
