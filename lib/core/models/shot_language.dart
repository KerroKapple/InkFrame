// 镜头语言（P3，BOARD 211）：景别 / 机位角度 / 运镜幅度 / 焦段——video config 的 type_config 里四个可选键。
//
// 手写不可变值对象而非 freezed（build_runner 卡点，BOARD 145），只做 type_config ↔ 值的解析与补丁；
// 用户可读文案在 features/canvas/util/camera_labels.dart（ARB），注入提示词的英文在
// features/generation/services/shot_language_prompt.dart（英文常量，不 i18n）。
// 四键全可空：缺省即「未设」，界面不显示、提示词不注入。运镜方式沿用既有的 `camera` 键（CameraMovement）。
import 'package:flutter/foundation.dart';

/// 景别（远 → 近）。
enum ShotSize { extremeLongShot, longShot, mediumShot, mediumCloseUp, closeUp, extremeCloseUp }

/// 机位角度。
enum CameraAngle { eyeLevel, high, low, birdsEye, dutch }

/// 可选焦段（mm）。
const List<int> kFocalLengthsMm = <int>[14, 24, 35, 50, 85, 135];

/// 运镜幅度滑块的步进（PLAN §P3 补充拍板：0–1，步进 0.05）。
const double kMotionStrengthStep = 0.05;

@immutable
class ShotLanguage {
  const ShotLanguage({this.shotSize, this.cameraAngle, this.motionStrength, this.focalLengthMm});

  static const ShotLanguage empty = ShotLanguage();

  static const String keyShotSize = 'shot_size';
  static const String keyCameraAngle = 'camera_angle';
  static const String keyMotionStrength = 'camera_motion_strength';
  static const String keyFocalLength = 'focal_length_mm';

  final ShotSize? shotSize;
  final CameraAngle? cameraAngle;

  /// 0–1；越界值在解析时夹回。
  final double? motionStrength;

  /// 只认 [kFocalLengthsMm] 里的值；其他一律当未设。
  final int? focalLengthMm;

  bool get isEmpty => shotSize == null && cameraAngle == null && motionStrength == null && focalLengthMm == null;

  /// 从 type_config 解析；非法 / 缺失键一律 null，不抛。
  factory ShotLanguage.fromTypeConfig(Map<String, Object?> typeConfig) {
    final Object? strength = typeConfig[keyMotionStrength];
    final Object? focal = typeConfig[keyFocalLength];
    return ShotLanguage(
      shotSize: _enumByName(ShotSize.values, typeConfig[keyShotSize]),
      cameraAngle: _enumByName(CameraAngle.values, typeConfig[keyCameraAngle]),
      motionStrength: strength is num ? strength.toDouble().clamp(0.0, 1.0) : null,
      focalLengthMm: focal is int && kFocalLengthsMm.contains(focal) ? focal : null,
    );
  }

  /// 写回 type_config 的补丁：非空键写值，空键写 null（调用方合并时按 null 删除）。
  Map<String, Object?> toTypeConfigPatch() => <String, Object?>{
        keyShotSize: shotSize?.name,
        keyCameraAngle: cameraAngle?.name,
        keyMotionStrength: motionStrength,
        keyFocalLength: focalLengthMm,
      };

  ShotLanguage copyWith({
    ShotSize? shotSize,
    bool clearShotSize = false,
    CameraAngle? cameraAngle,
    bool clearCameraAngle = false,
    double? motionStrength,
    bool clearMotionStrength = false,
    int? focalLengthMm,
    bool clearFocalLength = false,
  }) =>
      ShotLanguage(
        shotSize: clearShotSize ? null : (shotSize ?? this.shotSize),
        cameraAngle: clearCameraAngle ? null : (cameraAngle ?? this.cameraAngle),
        motionStrength: clearMotionStrength ? null : (motionStrength ?? this.motionStrength),
        focalLengthMm: clearFocalLength ? null : (focalLengthMm ?? this.focalLengthMm),
      );

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotLanguage &&
          shotSize == other.shotSize &&
          cameraAngle == other.cameraAngle &&
          motionStrength == other.motionStrength &&
          focalLengthMm == other.focalLengthMm;

  @override
  int get hashCode => Object.hash(shotSize, cameraAngle, motionStrength, focalLengthMm);

  @override
  String toString() => 'ShotLanguage($shotSize, $cameraAngle, $motionStrength, ${focalLengthMm}mm)';
}
