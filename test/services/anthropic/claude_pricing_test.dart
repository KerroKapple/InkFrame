// 价目：claude-opus-5-5 按 4 / 20 USD 每百万 token，cache read 0.20、
// 5 分钟 cache write 1.25 × 输入价。用量账本身从导演日志派生，见
// test/features/director/log/claude_usage_ledger_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/services/anthropic/claude_pricing.dart';

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
}
