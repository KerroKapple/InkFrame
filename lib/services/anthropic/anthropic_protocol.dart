// Anthropic Messages API 的协议字面量（英文常量，不 i18n）。
//
// 版本与 beta 值以 claude-api skill 的本地文档为准：
// - anthropic-version 2026-10-21：curl/examples.md「Required Headers」+
//   shared/api-version-migration.md「Set the version」（raw HTTP 直接发该值）。
// - server-side-fallback-2026-07-01：shared/model-migration.md「New API features」
//   ——`fallbacks: "default"` 标量形式只认这个 beta。
abstract final class AnthropicProtocol {
  static const String baseUrl = 'https://api.anthropic.com';
  static const String messagesPath = '/v1/messages';
  static const String modelsPath = '/v1/models';

  static const String apiVersion = '2026-10-21';
  static const String fallbackBeta = 'server-side-fallback-2026-07-01';
  static const String model = 'claude-opus-5-5';

  /// 日志 / 错误 extra 里的 provider_id。
  static const String clientId = 'anthropic';
}

/// 请求头名。
abstract final class AnthropicHeaders {
  static const String apiKey = 'x-api-key';
  static const String version = 'anthropic-version';
  static const String beta = 'anthropic-beta';
  static const String retryAfter = 'retry-after';
}

/// 请求 / 响应 JSON 键与取值。
abstract final class AnthropicJson {
  static const String model = 'model';
  static const String maxTokens = 'max_tokens';
  static const String stream = 'stream';
  static const String system = 'system';
  static const String messages = 'messages';
  static const String role = 'role';
  static const String content = 'content';
  static const String type = 'type';
  static const String text = 'text';
  static const String image = 'image';
  static const String source = 'source';
  static const String base64 = 'base64';
  static const String mediaType = 'media_type';
  static const String data = 'data';
  static const String thinking = 'thinking';
  static const String adaptive = 'adaptive';
  static const String outputConfig = 'output_config';
  static const String effort = 'effort';
  static const String format = 'format';
  static const String jsonSchema = 'json_schema';
  static const String schema = 'schema';
  static const String fallbacks = 'fallbacks';
  static const String fallbacksDefault = 'default';

  static const String id = 'id';
  static const String message = 'message';
  static const String index = 'index';
  static const String contentBlock = 'content_block';
  static const String delta = 'delta';
  static const String usage = 'usage';
  static const String stopReason = 'stop_reason';
  static const String stopDetails = 'stop_details';
  static const String category = 'category';
  static const String error = 'error';

  static const String inputTokens = 'input_tokens';
  static const String outputTokens = 'output_tokens';
  static const String cacheCreationInputTokens = 'cache_creation_input_tokens';
  static const String cacheReadInputTokens = 'cache_read_input_tokens';
}

/// SSE 事件类型。
abstract final class AnthropicEvents {
  static const String messageStart = 'message_start';
  static const String contentBlockStart = 'content_block_start';
  static const String contentBlockDelta = 'content_block_delta';
  static const String contentBlockStop = 'content_block_stop';
  static const String messageDelta = 'message_delta';
  static const String messageStop = 'message_stop';
  static const String ping = 'ping';
  static const String error = 'error';

  static const String textDelta = 'text_delta';
}

/// stop_reason 取值。
abstract final class AnthropicStopReasons {
  static const String endTurn = 'end_turn';
  static const String maxTokens = 'max_tokens';
  static const String stopSequence = 'stop_sequence';
  static const String toolUse = 'tool_use';
  static const String pauseTurn = 'pause_turn';
  static const String refusal = 'refusal';
}

/// 错误体里的 error.type。
abstract final class AnthropicErrorTypes {
  static const String rateLimit = 'rate_limit_error';
  static const String overloaded = 'overloaded_error';
  static const String api = 'api_error';
  static const String authentication = 'authentication_error';
  static const String permission = 'permission_error';
  static const String billing = 'billing_error';
}
