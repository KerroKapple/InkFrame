// Claude Messages API 的请求 / 响应值对象（A1 Claude 客户端）。
//
// 手写不可变值对象而非 freezed（与 gen_inputs.dart / shot_language.dart 同例外）：
// 只在内存里流转，不落库、不走 JSON 往返；线上格式的编解码在
// services/anthropic/ 里，这里不出现任何协议字面量。
import 'package:flutter/foundation.dart';

/// output_config.effort 的五档。默认 medium（claude-opus-5-5 的 API 默认值）。
enum ClaudeEffort { low, medium, high, xhigh, max }

/// 对话角色。没有 system——system 提示词单列在 [ClaudeRequest.system]。
enum ClaudeRole { user, assistant }

/// 一条消息里的内容块。
@immutable
sealed class ClaudeContentBlock {
  const ClaudeContentBlock();
}

/// 文本块。
final class ClaudeTextBlock extends ClaudeContentBlock {
  const ClaudeTextBlock(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is ClaudeTextBlock && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// 图片块（base64 内联）。[mediaType] 如 image/png、image/jpeg。
final class ClaudeImageBlock extends ClaudeContentBlock {
  const ClaudeImageBlock({required this.mediaType, required this.base64Data});

  final String mediaType;
  final String base64Data;

  @override
  bool operator ==(Object other) =>
      other is ClaudeImageBlock &&
      other.mediaType == mediaType &&
      other.base64Data == base64Data;

  @override
  int get hashCode => Object.hash(mediaType, base64Data);
}

/// 一轮对话。
@immutable
class ClaudeMessageParam {
  ClaudeMessageParam({
    required this.role,
    required List<ClaudeContentBlock> content,
  }) : content = List<ClaudeContentBlock>.unmodifiable(content);

  ClaudeMessageParam.userText(String text)
      : this(role: ClaudeRole.user, content: <ClaudeContentBlock>[ClaudeTextBlock(text)]);

  final ClaudeRole role;
  final List<ClaudeContentBlock> content;
}

/// 结构化输出的 JSON Schema。Schema 本身就是一份 JSON 文档，这里只做不可变包装。
@immutable
class ClaudeJsonSchema {
  ClaudeJsonSchema(Map<String, Object?> schema)
      : schema = Map<String, Object?>.unmodifiable(schema);

  final Map<String, Object?> schema;
}

/// 一次 createMessage 的入参。
///
/// 模型、thinking、fallbacks 由客户端固定，不在这里暴露；也没有
/// temperature / top_p / top_k / tool_choice——该模型上它们都会 400。
@immutable
class ClaudeRequest {
  ClaudeRequest({
    required List<ClaudeMessageParam> messages,
    this.system,
    this.maxTokens = kClaudeDefaultMaxTokens,
    this.effort = ClaudeEffort.medium,
    this.outputSchema,
  }) : messages = List<ClaudeMessageParam>.unmodifiable(messages);

  final String? system;
  final List<ClaudeMessageParam> messages;

  /// 含思考在内的输出上限（思考不返回内容，但计入 max_tokens）。
  final int maxTokens;
  final ClaudeEffort effort;

  /// 非 null ⇒ 走 output_config.format 结构化输出，[ClaudeMessage.text] 即 JSON。
  final ClaudeJsonSchema? outputSchema;
}

/// 思考也算进 max_tokens，给足余量。
const int kClaudeDefaultMaxTokens = 32000;

/// token 用量（一次调用的顶层 usage）。
@immutable
class ClaudeUsage {
  const ClaudeUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationInputTokens = 0,
    this.cacheReadInputTokens = 0,
  });

  /// 未命中缓存的输入部分。
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationInputTokens;
  final int cacheReadInputTokens;

  ClaudeUsage operator +(ClaudeUsage o) => ClaudeUsage(
        inputTokens: inputTokens + o.inputTokens,
        outputTokens: outputTokens + o.outputTokens,
        cacheCreationInputTokens:
            cacheCreationInputTokens + o.cacheCreationInputTokens,
        cacheReadInputTokens: cacheReadInputTokens + o.cacheReadInputTokens,
      );

  @override
  bool operator ==(Object other) =>
      other is ClaudeUsage &&
      other.inputTokens == inputTokens &&
      other.outputTokens == outputTokens &&
      other.cacheCreationInputTokens == cacheCreationInputTokens &&
      other.cacheReadInputTokens == cacheReadInputTokens;

  @override
  int get hashCode => Object.hash(
      inputTokens, outputTokens, cacheCreationInputTokens, cacheReadInputTokens);

  @override
  String toString() =>
      'ClaudeUsage(in=$inputTokens, out=$outputTokens, '
      'cacheWrite=$cacheCreationInputTokens, cacheRead=$cacheReadInputTokens)';
}

/// 正常结束的 stop_reason。refusal / max_tokens 不会出现在成功结果里——
/// 客户端把它们翻成 InkError。
enum ClaudeStopReason { endTurn, stopSequence, toolUse, pauseTurn, other }

/// createMessage 的成功结果。
@immutable
class ClaudeMessage {
  ClaudeMessage({
    required this.id,
    required this.model,
    required List<String> textBlocks,
    required this.usage,
    required this.stopReason,
  }) : textBlocks = List<String>.unmodifiable(textBlocks);

  final String id;

  /// 实际产出这条消息的模型（走了 fallback 时不是请求的模型）。
  final String model;

  /// 各 text 块原文，按出现顺序；thinking 等其它块不收。
  final List<String> textBlocks;
  final ClaudeUsage usage;
  final ClaudeStopReason stopReason;

  /// 全部 text 块拼接；结构化输出时即那份 JSON。
  String get text => textBlocks.join();
}

/// 记账里的一行：一次调用（成功、拒答或截断——都计费）的用量与估算费用。
@immutable
class ClaudeUsageRecord {
  const ClaudeUsageRecord({
    required this.at,
    required this.model,
    required this.usage,
    required this.estimatedCostUsd,
  });

  final DateTime at;
  final String model;
  final ClaudeUsage usage;

  /// 按 claude-opus-5-5 价目估算；以服务商账单为准。
  final double estimatedCostUsd;
}
