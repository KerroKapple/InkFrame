// Claude（Anthropic Messages API）客户端契约。
//
// 实现见 services/anthropic/dio_anthropic_client.dart。Claude 是导演用的
// 语言模型，不是出图出片的 Provider：不实现 Submittable、不进 ProviderRegistry。
// Key 校验复用 KeyValidatable（设置页 Key 行走同一个 ApiKeyScopeController）。
import '../models/claude_message.dart';
import 'generation_provider.dart';

abstract class AnthropicClient implements KeyValidatable {
  /// 发一次 Messages 请求（流式），拼出最终消息。
  ///
  /// 失败一律抛 InkError：
  /// - 拒答（stop_reason = refusal）→ RefusalError(category)
  /// - 输出截断（stop_reason = max_tokens）→ ProviderError(outputTruncated)
  /// - 401 / 403 → invalidKey；402 → insufficientBalance；其它 4xx → invalidParameter
  /// - 429 / 529 / 5xx / 连接错误：内部退避重试，用尽后抛最后一次的错误
  /// 每次拿到 usage（含拒答与截断）都会记账。
  Future<ClaudeMessage> createMessage(ClaudeRequest request);
}
