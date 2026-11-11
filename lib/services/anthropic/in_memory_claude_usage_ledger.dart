// Claude 用量记账（内存，本次会话内有效，不落库）。
//
// Notifier 状态 = 记账行列表（按时间正序），UI watch claudeUsageLedgerProvider
// 读；客户端只经 ClaudeUsageLedger.record 写。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/interfaces/claude_usage_ledger.dart';
import '../../core/models/claude_message.dart';

class InMemoryClaudeUsageLedger extends Notifier<List<ClaudeUsageRecord>>
    implements ClaudeUsageLedger {
  @override
  List<ClaudeUsageRecord> build() => const <ClaudeUsageRecord>[];

  @override
  void record(ClaudeUsageRecord record) {
    state = List<ClaudeUsageRecord>.unmodifiable(
      <ClaudeUsageRecord>[...state, record],
    );
  }

  /// 本次会话累计用量。
  ClaudeUsage get totalUsage => state.fold(
        const ClaudeUsage(),
        (ClaudeUsage sum, ClaudeUsageRecord r) => sum + r.usage,
      );

  /// 本次会话累计估算费用（USD）。
  double get totalCostUsd => state.fold(
        0,
        (double sum, ClaudeUsageRecord r) => sum + r.estimatedCostUsd,
      );
}
