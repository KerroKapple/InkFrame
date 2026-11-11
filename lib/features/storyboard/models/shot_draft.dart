// 一条待落地的分镜草稿：SB-1 规则拆分与 A2 AI 拆分都产出它，
// ScriptImportController.importDrafts 把它变成真的 shot 节点。
//
// 镜头语言四项可选：规则拆分恒为 null；有值才写进 shot 节点 type_config 的现有键
// （shot_size / camera_angle / camera / duration_ms），不加新键。
import 'package:flutter/foundation.dart';

import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';

@immutable
class ShotDraft {
  const ShotDraft({
    required this.label,
    required this.notes,
    this.shotSize,
    this.cameraAngle,
    this.camera,
    this.durationMs,
  });

  /// 节点标题：段首行（已剥编号），超长截断。
  final String label;

  /// 分镜备注：整段原文（已剥段首编号），保留段内换行。
  final String notes;

  final ShotSize? shotSize;
  final CameraAngle? cameraAngle;
  final CameraMovement? camera;
  final int? durationMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotDraft &&
          label == other.label &&
          notes == other.notes &&
          shotSize == other.shotSize &&
          cameraAngle == other.cameraAngle &&
          camera == other.camera &&
          durationMs == other.durationMs;

  @override
  int get hashCode =>
      Object.hash(label, notes, shotSize, cameraAngle, camera, durationMs);

  @override
  String toString() => 'ShotDraft($label)';
}
