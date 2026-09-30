// 镜头语言枚举 → 用户可读文案（运镜 / 景别 / 机位角度 / 焦段）。
//
// SB-3 起运镜被两处消费：video config 面板与 shot 面板（shot 记录的是导演意图，列全量）。
// P3 起四处共用同一组文案：检查器「镜头运动」组 / 画廊「镜头语言」行 / 序列监视器叠字 / 提示词条摘要。
// 抽出来是为了让新增枚举只需改一处映射；注入提示词的英文在
// features/generation/services/shot_language_prompt.dart，与这里的界面文案无关。

import 'package:flutter/widgets.dart';

import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../../../l10n/l10n_x.dart';

/// exhaustive switch——新增 [CameraMovement] 枚举漏映射会编译期报错，
/// 而不是在界面上露出枚举名。
String cameraMovementLabel(BuildContext context, CameraMovement camera) {
  final l = context.l10n;
  return switch (camera) {
    CameraMovement.static_ => l.cameraStatic,
    CameraMovement.pushIn => l.cameraPushIn,
    CameraMovement.pullOut => l.cameraPullOut,
    CameraMovement.panLeft => l.cameraPanLeft,
    CameraMovement.panRight => l.cameraPanRight,
    CameraMovement.tiltUp => l.cameraTiltUp,
    CameraMovement.tiltDown => l.cameraTiltDown,
    CameraMovement.truckLeft => l.cameraTruckLeft,
    CameraMovement.truckRight => l.cameraTruckRight,
    CameraMovement.tracking => l.cameraTracking,
    CameraMovement.pedestalUp => l.cameraPedestalUp,
    CameraMovement.pedestalDown => l.cameraPedestalDown,
    CameraMovement.orbit => l.cameraOrbit,
  };
}

/// `camera` 键的原串 → 枚举；未知 / 非法为 null（旧数据里已删除的值也走这里归 null）。
CameraMovement? parseCameraMovement(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  for (final CameraMovement c in CameraMovement.values) {
    if (c.name == raw) return c;
  }
  return null;
}

String shotSizeLabel(BuildContext context, ShotSize s) {
  final l = context.l10n;
  return switch (s) {
    ShotSize.extremeLongShot => l.shotSizeExtremeLongShot,
    ShotSize.longShot => l.shotSizeLongShot,
    ShotSize.mediumShot => l.shotSizeMediumShot,
    ShotSize.mediumCloseUp => l.shotSizeMediumCloseUp,
    ShotSize.closeUp => l.shotSizeCloseUp,
    ShotSize.extremeCloseUp => l.shotSizeExtremeCloseUp,
  };
}

String cameraAngleLabel(BuildContext context, CameraAngle a) {
  final l = context.l10n;
  return switch (a) {
    CameraAngle.eyeLevel => l.cameraAngleEyeLevel,
    CameraAngle.high => l.cameraAngleHigh,
    CameraAngle.low => l.cameraAngleLow,
    CameraAngle.birdsEye => l.cameraAngleBirdsEye,
    CameraAngle.dutch => l.cameraAngleDutch,
  };
}

String focalLengthLabel(BuildContext context, int mm) => context.l10n.focalLengthMm(mm);

/// 运镜幅度的显示串（两位小数，与稿的「0.35」一致）。
String motionStrengthLabel(double v) => v.toStringAsFixed(2);

/// 画廊「镜头语言」行 / 序列叠字用的紧凑摘要：`中景 MS · 平视 Eye Level · 0.35 · 35mm`；全空返回空串。
String shotLanguageSummary(BuildContext context, ShotLanguage lang) {
  final List<String> parts = <String>[
    if (lang.shotSize != null) shotSizeLabel(context, lang.shotSize!),
    if (lang.cameraAngle != null) cameraAngleLabel(context, lang.cameraAngle!),
    if (lang.motionStrength != null) motionStrengthLabel(lang.motionStrength!),
    if (lang.focalLengthMm != null) focalLengthLabel(context, lang.focalLengthMm!),
  ];
  return parts.join(' · ');
}
