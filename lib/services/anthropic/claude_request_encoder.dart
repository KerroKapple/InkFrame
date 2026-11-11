// ClaudeRequest → Messages API 请求体（JSON 序列化边界）。
//
// 固定写入：model、stream、thinking adaptive、fallbacks "default"。
// 永不写入：temperature / top_p / top_k（2026-10-21 版本一律 400）、
// tool_choice（any / tool 在该模型 400）。
import '../../core/errors/ink_error.dart';
import '../../core/models/claude_message.dart';
import 'anthropic_protocol.dart';

/// 末轮不是 user ⇒ 等同 assistant 预填（该模型 400），在本地就拦下。
Map<String, Object?> encodeClaudeRequest(ClaudeRequest r) {
  if (r.messages.isEmpty || r.messages.last.role != ClaudeRole.user) {
    throw const ProviderError(
      code: InkErrorCode.invalidParameter,
      extra: <String, Object?>{
        'provider_id': AnthropicProtocol.clientId,
        'reason': 'last_message_must_be_user',
      },
    );
  }
  final ClaudeJsonSchema? schema = r.outputSchema;
  final String? system = r.system;
  return <String, Object?>{
    AnthropicJson.model: AnthropicProtocol.model,
    AnthropicJson.maxTokens: r.maxTokens,
    AnthropicJson.stream: true,
    AnthropicJson.thinking: const <String, Object?>{
      AnthropicJson.type: AnthropicJson.adaptive,
    },
    AnthropicJson.outputConfig: <String, Object?>{
      AnthropicJson.effort: r.effort.name,
      if (schema != null)
        AnthropicJson.format: <String, Object?>{
          AnthropicJson.type: AnthropicJson.jsonSchema,
          AnthropicJson.schema: schema.schema,
        },
    },
    AnthropicJson.fallbacks: AnthropicJson.fallbacksDefault,
    if (system != null && system.isNotEmpty) AnthropicJson.system: system,
    AnthropicJson.messages: <Object?>[
      for (final ClaudeMessageParam m in r.messages)
        <String, Object?>{
          AnthropicJson.role: m.role.name,
          AnthropicJson.content: <Object?>[
            for (final ClaudeContentBlock b in m.content) _block(b),
          ],
        },
    ],
  };
}

Map<String, Object?> _block(ClaudeContentBlock b) => switch (b) {
      ClaudeTextBlock(:final String text) => <String, Object?>{
          AnthropicJson.type: AnthropicJson.text,
          AnthropicJson.text: text,
        },
      ClaudeImageBlock(:final String mediaType, :final String base64Data) =>
        <String, Object?>{
          AnthropicJson.type: AnthropicJson.image,
          AnthropicJson.source: <String, Object?>{
            AnthropicJson.type: AnthropicJson.base64,
            AnthropicJson.mediaType: mediaType,
            AnthropicJson.data: base64Data,
          },
        },
    };
