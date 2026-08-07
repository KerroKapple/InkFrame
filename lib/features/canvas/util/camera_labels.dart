// 运镜枚举 → 用户可读文案。
//
// SB-3 起被两处消费：video config 面板（受 provider `supportedCameras` 钳制，
// 只列该 provider 真支持的项）与 shot 面板（列**全量**——shot 记录的是导演意图，
// 此刻还没选 provider；能不能真做到由生成时 video inspector 的现有钳制收口）。
// 抽出来是为了让新增枚举只需改一处映射。

import 'package:flutter/widgets.dart';

import '../../../core/models/provider_capabilities.dart';
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
    CameraMovement.orbit => l.cameraOrbit,
    CameraMovement.handheld => l.cameraHandheld,
  };
}
