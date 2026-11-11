// 导演事件 payload / 会话设定的 JSON 键（英文常量，落库即协议，不 i18n）。
//
// 放 core：导入重映射（services/import）要认 applied_to_canvas 里的节点 id，
// 不能反向依赖 features/director。

/// director_sessions.setting 的键。
abstract final class DirectorSettingKeys {
  static const String era = 'era';
  static const String region = 'region';
  static const String culture = 'culture';
  static const String artStyle = 'art_style';
}

/// director_events.payload 的键。
abstract final class DirectorPayloadKeys {
  /// 产生本事件的步骤 id（如 storyboard）。
  static const String step = 'step';

  // script_submitted
  static const String text = 'text';
  static const String feedback = 'feedback';

  // model_request
  static const String body = 'body';
  static const String attempt = 'attempt';

  // model_response
  static const String messageId = 'id';
  static const String model = 'model';
  static const String content = 'content';
  static const String usage = 'usage';
  static const String stopReason = 'stop_reason';
  static const String refusalCategory = 'refusal_category';
  static const String partial = 'partial';

  // model_failed
  static const String code = 'code';

  // storyboard_proposed / human_edited
  static const String contentLanguage = 'content_language';
  static const String setting = 'setting';
  static const String shots = 'shots';

  // human_confirmed / human_rejected
  static const String proposalSeq = 'proposal_seq';
  static const String reason = 'reason';

  // applied_to_canvas
  static const String nodeIds = 'node_ids';
}

/// model_response.usage 的键（与 Messages API 的 usage 同名）。
abstract final class DirectorUsageKeys {
  static const String inputTokens = 'input_tokens';
  static const String outputTokens = 'output_tokens';
  static const String cacheCreationInputTokens = 'cache_creation_input_tokens';
  static const String cacheReadInputTokens = 'cache_read_input_tokens';
}
