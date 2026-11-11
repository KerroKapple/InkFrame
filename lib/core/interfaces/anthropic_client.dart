// Claude（Anthropic Messages API）客户端契约。
//
// 实现见 services/anthropic/dio_anthropic_client.dart。Claude 是导演用的
// 语言模型，不是出图出片的 Provider：不实现 Submittable、不进 ProviderRegistry。
// Key 校验复用 KeyValidatable（设置页 Key 行走同一个 ApiKeyScopeController）。
//
// 客户端自己不记账：调用方经 [ClaudeExchangeObserver] 拿到「实际发出的每一份请求体」
// 与「每一次带用量的回应」，写进导演事件日志；用量 / 费用从日志派生（ADR-0015）。
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
  /// [observer] 非 null 时：每次真正发出之前（含重试）先 await [ClaudeExchangeObserver.onRequest]，
  /// 每次拿到用量（含拒答、截断、流中途断开）都 await [ClaudeExchangeObserver.onResponse]。
  Future<ClaudeMessage> createMessage(
    ClaudeRequest request, {
    ClaudeExchangeObserver? observer,
  });
}

/// 一次调用的观察口：模型可见的东西都从这里交出去入日志。
abstract interface class ClaudeExchangeObserver {
  /// 即将发出的请求体，与线上发送的是同一份（Key 在请求头里，不在这里）。
  /// [attempt] 从 0 起，重试递增。抛错 ⇒ 这次不发，错误原样冒出。
  Future<void> onRequest(Map<String, Object?> body, {required int attempt});

  /// 一次带用量的回应（所有计费的回应都会到这里，成功与否都一样）。
  Future<void> onResponse(ClaudeExchangeResponse response);
}
