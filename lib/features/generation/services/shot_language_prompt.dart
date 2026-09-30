// 镜头语言 → 提示词前缀（P3）。英文常量，**不走 ARB**（提示词是模型契约，不随界面语言变）。
//
// 模板（PLAN §P3）：`{景别}, {运镜}, {角度}, {焦段}mm lens`；空项跳过；四项全空返回空串。
// 运镜幅度没有稳定的自然语言表达，不注入（只落库 / 只显示）。
// provider 不支持 camera 能力位时也照样注入——这正是本函数存在的理由：文本是对所有模型都成立的通道。
import '../../../core/models/provider_capabilities.dart' show CameraMovement;
import '../../../core/models/shot_language.dart';

String shotSizePromptTerm(ShotSize s) => switch (s) {
      ShotSize.extremeLongShot => 'extreme long shot',
      ShotSize.longShot => 'long shot',
      ShotSize.mediumShot => 'medium shot',
      ShotSize.mediumCloseUp => 'medium close-up',
      ShotSize.closeUp => 'close-up',
      ShotSize.extremeCloseUp => 'extreme close-up',
    };

String cameraAnglePromptTerm(CameraAngle a) => switch (a) {
      CameraAngle.eyeLevel => 'eye level',
      CameraAngle.high => 'high angle',
      CameraAngle.low => 'low angle',
      CameraAngle.birdsEye => "bird's-eye view",
      CameraAngle.dutch => 'dutch angle',
    };

String cameraMovementPromptTerm(CameraMovement c) => switch (c) {
      CameraMovement.static_ => 'static camera',
      CameraMovement.pushIn => 'dolly in',
      CameraMovement.pullOut => 'dolly out',
      CameraMovement.panLeft => 'pan left',
      CameraMovement.panRight => 'pan right',
      CameraMovement.tiltUp => 'tilt up',
      CameraMovement.tiltDown => 'tilt down',
      CameraMovement.truckLeft => 'truck left',
      CameraMovement.truckRight => 'truck right',
      CameraMovement.tracking => 'tracking shot',
      CameraMovement.pedestalUp => 'pedestal up',
      CameraMovement.pedestalDown => 'pedestal down',
      CameraMovement.orbit => 'arc shot',
    };

/// `medium shot, dolly in, eye level, 35mm lens`；无可注入项时为空串。
String shotLanguagePromptPrefix(ShotLanguage lang, {CameraMovement? camera}) {
  final List<String> parts = <String>[
    if (lang.shotSize != null) shotSizePromptTerm(lang.shotSize!),
    if (camera != null) cameraMovementPromptTerm(camera),
    if (lang.cameraAngle != null) cameraAnglePromptTerm(lang.cameraAngle!),
    if (lang.focalLengthMm != null) '${lang.focalLengthMm}mm lens',
  ];
  return parts.join(', ');
}
