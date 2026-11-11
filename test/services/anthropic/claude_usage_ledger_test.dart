// 记账与价目：claude-opus-5-5 按 4 / 20 USD 每百万 token，cache read 0.20、
// 5 分钟 cache write 1.25 × 输入价。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/anthropic.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/services/anthropic/claude_pricing.dart';

ClaudeUsageRecord _rec(ClaudeUsage u) => ClaudeUsageRecord(
      at: DateTime.utc(2026, 11, 11),
      model: 'claude-opus-5-5',
      usage: u,
      estimatedCostUsd: estimateClaudeCostUsd(u),
    );

void main() {
  group('estimateClaudeCostUsd', () {
    test('各一百万：输入 4、输出 20、cache read 0.2、cache write 5', () {
      const int m = 1000000;
      expect(estimateClaudeCostUsd(const ClaudeUsage(inputTokens: m)), closeTo(4, 1e-9));
      expect(estimateClaudeCostUsd(const ClaudeUsage(outputTokens: m)), closeTo(20, 1e-9));
      expect(estimateClaudeCostUsd(const ClaudeUsage(cacheReadInputTokens: m)), closeTo(0.2, 1e-9));
      expect(estimateClaudeCostUsd(const ClaudeUsage(cacheCreationInputTokens: m)), closeTo(5, 1e-9));
    });

    test('零用量零费用', () {
      expect(estimateClaudeCostUsd(const ClaudeUsage()), 0);
    });
  });

  group('claudeUsageLedgerProvider', () {
    test('初始为空；record 追加并通知，累计用量与费用', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      final List<int> lengths = <int>[];
      c.listen<List<ClaudeUsageRecord>>(
        claudeUsageLedgerProvider,
        (_, List<ClaudeUsageRecord> next) => lengths.add(next.length),
      );
      expect(c.read(claudeUsageLedgerProvider), isEmpty);

      final ledger = c.read(claudeUsageLedgerProvider.notifier);
      ledger.record(_rec(const ClaudeUsage(inputTokens: 1000000)));
      ledger.record(_rec(const ClaudeUsage(outputTokens: 500000)));

      expect(lengths, <int>[1, 2]);
      expect(c.read(claudeUsageLedgerProvider), hasLength(2));
      expect(ledger.totalUsage, const ClaudeUsage(inputTokens: 1000000, outputTokens: 500000));
      expect(ledger.totalCostUsd, closeTo(14, 1e-9));
    });

    test('记账列表不可外改', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(claudeUsageLedgerProvider.notifier).record(_rec(const ClaudeUsage()));
      expect(
        () => c.read(claudeUsageLedgerProvider).add(_rec(const ClaudeUsage())),
        throwsUnsupportedError,
      );
    });
  });
}
