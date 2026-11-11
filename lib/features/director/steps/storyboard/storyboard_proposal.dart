// 拆分镜提案：解析、规范化后的分镜表（storyboard_proposed 事件的 payload 就是它的 JSON）。
import 'package:flutter/foundation.dart';

import '../../../../core/constants/director_keys.dart';
import '../../../../core/models/director.dart';
import '../../../../core/models/provider_capabilities.dart';
import '../../../../core/models/shot_language.dart';

/// 结构化输出与提案 payload 里每镜的键（英文常量）。
abstract final class StoryboardKeys {
  static const String label = 'label';
  static const String notes = 'notes';
  static const String shotSize = 'shot_size';
  static const String cameraAngle = 'camera_angle';
  static const String camera = 'camera';
  static const String durationSeconds = 'duration_seconds';
  static const String durationMs = 'duration_ms';
  static const String characters = 'characters';
}

@immutable
class StoryboardShot {
  StoryboardShot({
    required this.label,
    required this.notes,
    this.shotSize,
    this.cameraAngle,
    this.camera,
    required this.durationMs,
    List<String> characters = const <String>[],
  }) : characters = List<String>.unmodifiable(characters);

  final String label;

  /// 首帧画面 + 动作；出场角色名已附在末行。
  final String notes;
  final ShotSize? shotSize;
  final CameraAngle? cameraAngle;
  final CameraMovement? camera;

  /// 已夹到 1–15 秒。
  final int durationMs;
  final List<String> characters;

  Map<String, Object?> toJson() => <String, Object?>{
        StoryboardKeys.label: label,
        StoryboardKeys.notes: notes,
        StoryboardKeys.shotSize: shotSize?.name,
        StoryboardKeys.cameraAngle: cameraAngle?.name,
        StoryboardKeys.camera: camera?.name,
        StoryboardKeys.durationMs: durationMs,
        StoryboardKeys.characters: characters,
      };

  factory StoryboardShot.fromJson(Map<String, Object?> j) {
    final Object? ms = j[StoryboardKeys.durationMs];
    final Object? chars = j[StoryboardKeys.characters];
    return StoryboardShot(
      label: _str(j[StoryboardKeys.label]),
      notes: _str(j[StoryboardKeys.notes]),
      shotSize: enumByName(ShotSize.values, j[StoryboardKeys.shotSize]),
      cameraAngle: enumByName(CameraAngle.values, j[StoryboardKeys.cameraAngle]),
      camera: enumByName(CameraMovement.values, j[StoryboardKeys.camera]),
      durationMs: ms is int ? ms : 0,
      characters: chars is List
          ? <String>[for (final Object? c in chars) if (c is String) c]
          : const <String>[],
    );
  }
}

@immutable
class StoryboardProposal {
  StoryboardProposal({
    required this.contentLanguage,
    required this.setting,
    required List<StoryboardShot> shots,
  }) : shots = List<StoryboardShot>.unmodifiable(shots);

  final String contentLanguage;
  final DirectorSetting setting;
  final List<StoryboardShot> shots;

  StoryboardProposal copyWith({String? contentLanguage, DirectorSetting? setting}) =>
      StoryboardProposal(
        contentLanguage: contentLanguage ?? this.contentLanguage,
        setting: setting ?? this.setting,
        shots: shots,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        DirectorPayloadKeys.contentLanguage: contentLanguage,
        DirectorPayloadKeys.setting: setting.toJson(),
        DirectorPayloadKeys.shots: <Object?>[for (final StoryboardShot s in shots) s.toJson()],
      };

  factory StoryboardProposal.fromJson(Map<String, Object?> j) {
    final Object? shots = j[DirectorPayloadKeys.shots];
    return StoryboardProposal(
      contentLanguage: _str(j[DirectorPayloadKeys.contentLanguage]),
      setting: DirectorSetting.fromJson(j[DirectorPayloadKeys.setting]),
      shots: shots is List
          ? <StoryboardShot>[
              for (final Object? s in shots)
                if (s is Map) StoryboardShot.fromJson(s.cast<String, Object?>()),
            ]
          : const <StoryboardShot>[],
    );
  }
}

String _str(Object? v) => v is String ? v.trim() : '';

/// 按 .name 认枚举；认不出 / 非字符串 ⇒ null。
T? enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final T v in values) {
    if (v.name == raw) return v;
  }
  return null;
}
