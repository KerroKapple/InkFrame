// 导演会话 / 事件日志的领域值对象（A2，ADR-0015）。
//
// 手写不可变值对象而非 freezed（与 claude_message.dart / shot_language.dart 同例外：
// build_runner 全量构建损坏，BOARD 161）。行 ↔ 值的映射在仓储边界
// （storage/repositories/postgres_director_repository.dart），这里不出现 SQL。
import 'package:flutter/foundation.dart';

import '../constants/director_keys.dart';

/// 事件种类。[wire] 是落库值（英文常量，不 i18n）。
enum DirectorEventKind {
  /// 用户交给导演的剧本（+ 之前驳回时留下的意见）。
  scriptSubmitted('script_submitted'),

  /// 实际发给模型的完整请求体（不含 Key）——可原样重建那次请求。
  modelRequest('model_request'),

  /// 模型的回应：最终消息 + usage + stop_reason（拒答 / 截断也记）。
  modelResponse('model_response'),

  /// 这一轮没拿到可用结果：InkError code（含用户取消）。
  modelFailed('model_failed'),

  /// 解析出的分镜提案。
  storyboardProposed('storyboard_proposed'),

  /// 人工改动（语言 / 设定）。
  humanEdited('human_edited'),

  /// 人工确认。
  humanConfirmed('human_confirmed'),

  /// 人工驳回（带意见）。
  humanRejected('human_rejected'),

  /// 已落到画布：建出的节点 id。
  appliedToCanvas('applied_to_canvas');

  const DirectorEventKind(this.wire);

  final String wire;

  /// 认不出 ⇒ null（调用方决定怎么处置）。
  static DirectorEventKind? fromWire(String wire) {
    for (final DirectorEventKind k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// 会话设定：时代 / 地域 / 文化 / 美术风格，用内容语言写；空串 = 未设。
@immutable
class DirectorSetting {
  const DirectorSetting({
    this.era = '',
    this.region = '',
    this.culture = '',
    this.artStyle = '',
  });

  static const DirectorSetting empty = DirectorSetting();

  final String era;
  final String region;
  final String culture;
  final String artStyle;

  bool get isEmpty =>
      era.isEmpty && region.isEmpty && culture.isEmpty && artStyle.isEmpty;

  /// 宽容解析：缺键 / 非字符串一律当空串，前后空白剥掉。
  factory DirectorSetting.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    String read(String k) {
      final Object? v = raw[k];
      return v is String ? v.trim() : '';
    }

    return DirectorSetting(
      era: read(DirectorSettingKeys.era),
      region: read(DirectorSettingKeys.region),
      culture: read(DirectorSettingKeys.culture),
      artStyle: read(DirectorSettingKeys.artStyle),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        DirectorSettingKeys.era: era,
        DirectorSettingKeys.region: region,
        DirectorSettingKeys.culture: culture,
        DirectorSettingKeys.artStyle: artStyle,
      };

  DirectorSetting copyWith({
    String? era,
    String? region,
    String? culture,
    String? artStyle,
  }) =>
      DirectorSetting(
        era: era ?? this.era,
        region: region ?? this.region,
        culture: culture ?? this.culture,
        artStyle: artStyle ?? this.artStyle,
      );

  @override
  bool operator ==(Object other) =>
      other is DirectorSetting &&
      other.era == era &&
      other.region == region &&
      other.culture == culture &&
      other.artStyle == artStyle;

  @override
  int get hashCode => Object.hash(era, region, culture, artStyle);

  @override
  String toString() => 'DirectorSetting($era, $region, $culture, $artStyle)';
}

/// 一次导演会话。[contentLanguage] 是 BCP-47 码，空串 = 还没识别。
@immutable
class DirectorSession {
  const DirectorSession({
    required this.id,
    required this.projectId,
    required this.canvasId,
    required this.contentLanguage,
    required this.setting,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String canvasId;
  final String contentLanguage;
  final DirectorSetting setting;
  final DateTime createdAt;
  final DateTime updatedAt;

  DirectorSession copyWith({
    String? contentLanguage,
    DirectorSetting? setting,
    DateTime? updatedAt,
  }) =>
      DirectorSession(
        id: id,
        projectId: projectId,
        canvasId: canvasId,
        contentLanguage: contentLanguage ?? this.contentLanguage,
        setting: setting ?? this.setting,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is DirectorSession &&
      other.id == id &&
      other.projectId == projectId &&
      other.canvasId == canvasId &&
      other.contentLanguage == contentLanguage &&
      other.setting == setting &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
      id, projectId, canvasId, contentLanguage, setting, createdAt, updatedAt);
}

/// 事件日志里的一行。只追加：没有 copyWith。
///
/// [parentSeq] = 本事件接在哪个事件之后；null = 接在空根上（会话第一件事，或从头分叉）。
/// 两个事件同父 ⇒ 在那里分了叉。
@immutable
class DirectorEvent {
  DirectorEvent({
    required this.id,
    required this.sessionId,
    required this.seq,
    required this.kind,
    required this.parentSeq,
    required Map<String, Object?> payload,
    required this.createdAt,
  }) : payload = Map<String, Object?>.unmodifiable(payload);

  final String id;
  final String sessionId;
  final int seq;
  final DirectorEventKind kind;
  final int? parentSeq;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  @override
  String toString() => 'DirectorEvent(#$seq ${kind.wire} ← $parentSeq)';
}
