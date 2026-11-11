// claude-opus-5-5 的价目与费用估算（USD / 百万 token）。
//
// 出处：claude-api skill 本地文档 shared/models.md（$4 / $20，cache read $0.20）
// 与 shared/prompt-caching.md（5 分钟 cache write = 1.25 × 输入价）。
// 走了 fallback 的调用实际按 fallback 模型计价，这里仍按本价目估——只是估算。
import '../../core/models/claude_message.dart';

abstract final class ClaudePricing {
  static const double inputPerMTok = 4;
  static const double outputPerMTok = 20;
  static const double cacheReadPerMTok = 0.20;
  static const double cacheWritePerMTok = inputPerMTok * 1.25;
}

const double _perToken = 1 / 1000000;

double estimateClaudeCostUsd(ClaudeUsage u) =>
    (u.inputTokens * ClaudePricing.inputPerMTok +
        u.outputTokens * ClaudePricing.outputPerMTok +
        u.cacheReadInputTokens * ClaudePricing.cacheReadPerMTok +
        u.cacheCreationInputTokens * ClaudePricing.cacheWritePerMTok) *
    _perToken;
