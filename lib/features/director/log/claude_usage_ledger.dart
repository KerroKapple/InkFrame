// Claude 用量账：从导演事件日志派生，不单独记（ADR-0015）。
//
// 每件 model_response 是一次计费的回应（成功、拒答、截断、流中途断开都算），
// 不论它在哪条分支上——被驳回、被取消的那一轮也花了钱。
import '../../../core/constants/director_keys.dart';
import '../../../core/models/claude_message.dart';
import '../../../core/models/director.dart';
import '../../../services/anthropic/claude_pricing.dart';
import 'director_payloads.dart';

class ClaudeUsageLedger {
  ClaudeUsageLedger._(this.records);

  factory ClaudeUsageLedger.fromEvents(Iterable<DirectorEvent> events) {
    final List<ClaudeUsageRecord> rows = <ClaudeUsageRecord>[
      for (final DirectorEvent e in events)
        if (e.kind == DirectorEventKind.modelResponse) _recordOf(e),
    ]..sort((ClaudeUsageRecord a, ClaudeUsageRecord b) => a.at.compareTo(b.at));
    return ClaudeUsageLedger._(List<ClaudeUsageRecord>.unmodifiable(rows));
  }

  /// 记账行，按时间正序。
  final List<ClaudeUsageRecord> records;

  ClaudeUsage get totalUsage => records.fold(
        const ClaudeUsage(),
        (ClaudeUsage sum, ClaudeUsageRecord r) => sum + r.usage,
      );

  double get totalCostUsd =>
      records.fold(0, (double sum, ClaudeUsageRecord r) => sum + r.estimatedCostUsd);

  static ClaudeUsageRecord _recordOf(DirectorEvent e) {
    final ClaudeUsage usage = usageFromJson(e.payload[DirectorPayloadKeys.usage]);
    final Object? model = e.payload[DirectorPayloadKeys.model];
    return ClaudeUsageRecord(
      at: e.createdAt,
      model: model is String ? model : '',
      usage: usage,
      estimatedCostUsd: estimateClaudeCostUsd(usage),
    );
  }
}
