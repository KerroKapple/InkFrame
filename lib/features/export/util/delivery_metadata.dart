// metadata.json（P6 §4）：交付目录里那份「这条时间线是怎么生成出来的」。
//
// 纯函数：计划 → JSON 文本。键名与取值全是**英文协议字面量**，不走 ARB
// ——这份文件是给人和工具读的数据，不是界面文案；翻译它等于让两种语言的导出
// 结果不是同一个格式。
//
// 空值一律**省略键**（`null` 不写）。唯一例外是占位镜的 `file`：它显式写 null
// ——「这一镜没有媒体文件」是信息本身，省掉就分不清「没产物」和「忘了写」。
//
// 提示词**恒写**，没有开关（稿 2026-10-08 删掉了那一行，见 delivery_settings.dart）。
import 'dart:convert';

import '../../../core/models/provider_capabilities.dart' show CameraMovement;
import '../../../core/models/shot_language.dart';
import '../../sequence/util/timecode.dart' show kSequenceFps;
import '../models/delivery_plan.dart';
import 'edl_cmx3600.dart' show formatEdlTimecode;

/// 景别 → 行业缩写。NLE / 剧本工具都认这几个，比 `mediumShot` 通用。
String shotSizeMetadataValue(ShotSize s) => switch (s) {
      ShotSize.extremeLongShot => 'ELS',
      ShotSize.longShot => 'LS',
      ShotSize.mediumShot => 'MS',
      ShotSize.mediumCloseUp => 'MCU',
      ShotSize.closeUp => 'CU',
      ShotSize.extremeCloseUp => 'ECU',
    };

/// 机位角度 → snake_case（与注入提示词的英文术语同源，便于回读）。
String cameraAngleMetadataValue(CameraAngle a) => switch (a) {
      CameraAngle.eyeLevel => 'eye_level',
      CameraAngle.high => 'high_angle',
      CameraAngle.low => 'low_angle',
      CameraAngle.birdsEye => 'birds_eye',
      CameraAngle.dutch => 'dutch_angle',
    };

/// 运镜 → snake_case（同上）。
String cameraMotionMetadataValue(CameraMovement c) => switch (c) {
      CameraMovement.static_ => 'static_camera',
      CameraMovement.pushIn => 'dolly_in',
      CameraMovement.pullOut => 'dolly_out',
      CameraMovement.panLeft => 'pan_left',
      CameraMovement.panRight => 'pan_right',
      CameraMovement.tiltUp => 'tilt_up',
      CameraMovement.tiltDown => 'tilt_down',
      CameraMovement.truckLeft => 'truck_left',
      CameraMovement.truckRight => 'truck_right',
      CameraMovement.tracking => 'tracking_shot',
      CameraMovement.pedestalUp => 'pedestal_up',
      CameraMovement.pedestalDown => 'pedestal_down',
      CameraMovement.orbit => 'arc_shot',
    };

/// 交付计划 + 导出时刻 → metadata.json 文本（2 空格缩进，末尾一个换行）。
String buildDeliveryMetadataJson({
  required DeliveryPlan plan,
  required DateTime exportedAt,
}) {
  final Map<String, Object?> root = <String, Object?>{
    'project': plan.projectName,
    // 恒 UTC：本地时区进了文件就再也分不清是哪儿导的。
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'fps': kSequenceFps,
    'timecodeStart': formatEdlTimecode(plan.settings.timecodeStartFrames),
    'shots': <Object?>[
      for (final DeliveryShotPlan s in plan.shots) _shotJson(s),
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
}

Map<String, Object?> _shotJson(DeliveryShotPlan s) {
  final Map<String, Object?> lang = _shotLanguageJson(s);
  return <String, Object?>{
    'index': s.index,
    'name': s.name,
    // 显式 null——见文件头注。
    'file': s.fileName,
    'durationFrames': s.durationFrames,
    'isPlaceholder': s.isPlaceholder,
    if (s.providerId != null) 'provider': s.providerId,
    if (s.seed != null) 'seed': s.seed,
    if (s.prompt != null) 'prompt': s.prompt,
    if (s.stylePrompt != null) 'stylePrompt': s.stylePrompt,
    if (lang.isNotEmpty) 'shotLanguage': lang,
  };
}

Map<String, Object?> _shotLanguageJson(DeliveryShotPlan s) {
  final ShotLanguage l = s.shotLanguage;
  return <String, Object?>{
    if (l.shotSize != null) 'shotSize': shotSizeMetadataValue(l.shotSize!),
    if (l.cameraAngle != null)
      'cameraAngle': cameraAngleMetadataValue(l.cameraAngle!),
    if (s.cameraMovement != null)
      'cameraMotion': cameraMotionMetadataValue(s.cameraMovement!),
    if (l.motionStrength != null) 'motionStrength': l.motionStrength,
    if (l.focalLengthMm != null) 'focalLengthMm': l.focalLengthMm,
  };
}
