// 系统提示词的一段（参照 DeepSeek Harness：system prompt 按 section 组装）。
//
// stability 决定排序：stable（与会话无关的常量）在前、session（会话设定 / 语言）居中、
// step（本步任务）在后——稳定前缀逐字节不变，日后加 prompt caching 断点直接落在它后面。
import 'package:flutter/foundation.dart';

import '../../../core/models/director.dart';

enum PromptStability { stable, session, step }

/// 渲染一段所需的会话上下文。语言只作参数注入，模板本身不变。
@immutable
class PromptContext {
  const PromptContext({required this.contentLanguage, required this.setting});

  /// BCP-47；空串 = 还没识别。
  final String contentLanguage;
  final DirectorSetting setting;

  factory PromptContext.of(DirectorSession s) =>
      PromptContext(contentLanguage: s.contentLanguage, setting: s.setting);
}

abstract class PromptSection {
  const PromptSection();

  /// 段名（英文常量），拼装时作为 XML 标签名。
  String get id;

  /// 同一 stability 内的先后。
  int get order;

  PromptStability get stability;

  /// 渲染为空串 ⇒ 这段不出现。
  String render(PromptContext context);
}

/// 与上下文无关的常量段。
class ConstantPromptSection extends PromptSection {
  const ConstantPromptSection({
    required this.id,
    required this.order,
    required this.stability,
    required this.text,
  });

  @override
  final String id;
  @override
  final int order;
  @override
  final PromptStability stability;
  final String text;

  @override
  String render(PromptContext context) => text;
}
