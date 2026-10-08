// 交付前检查 → 用户可读文案（P6）。
//
// 单独成文件是因为有两个消费方：面板里的检查清单，和**标签栏主按钮的 Tooltip**
// （任务书 §2.5：「存在任一 ✕ 时主按钮禁用，Tooltip 写第一条阻断原因」）。
// 判据在 delivery_preflight.dart（纯、无 l10n），文案在这里（与
// features/canvas/util/camera_labels.dart 同样的分法）。
import '../../../l10n/generated/app_localizations.dart';
import '../../sequence/util/timecode.dart' show formatTimecodeShort;
import '../models/delivery_plan.dart';
import 'delivery_preflight.dart';

/// 一条检查的首行文案（Tooltip 用它；清单里单行的检查也用它）。
String deliveryCheckHeadline(
  AppLocalizations l,
  DeliveryCheck check, {
  required String projectName,
}) {
  switch (check.id) {
    case DeliveryCheckId.frameRate:
      // 「算不出来」的那一条：没有 fps 字段，只说按 24 fps 统一处理，
      // 不写「已校验一致」——那是假装在比对（见 delivery_preflight.dart 头注）。
      return l.deliveryCheckFrameRate(check.shotCount);
    case DeliveryCheckId.frameSize:
      if (check.level == DeliveryCheckLevel.warn) {
        return l.deliveryCheckFrameSizeMixed(check.aspectLabels.join(' / '));
      }
      final String? ratio = check.aspectLabel;
      if (ratio == null) return l.deliveryCheckFrameSizeUnknown;
      return check.unknownSizeCount == 0
          ? l.deliveryCheckFrameSizeOk(ratio)
          : l.deliveryCheckFrameSizeOkUnknown(ratio, check.unknownSizeCount);
    case DeliveryCheckId.missingArtifacts:
      if (check.missing.isEmpty) {
        return l.deliveryCheckMissingNone(check.shotCount);
      }
      return deliveryMissingItemText(l, check.missing.first);
    case DeliveryCheckId.projectContext:
      return check.isOk
          ? l.deliveryCheckProjectOk(projectName)
          : l.deliveryCheckProjectMissing;
    case DeliveryCheckId.outputWritable:
      return check.isOk
          ? l.deliveryCheckOutputOk
          : l.deliveryCheckOutputBlocked;
  }
}

/// 缺失产物的一行：「00N {镜头名} 无视频产物，将导出为 {时长} 空隙并加标记」。
String deliveryMissingItemText(AppLocalizations l, DeliveryShotPlan shot) =>
    l.deliveryCheckMissingItem(
      shot.index.toString().padLeft(3, '0'),
      shot.name,
      formatTimecodeShort(shot.durationMs),
    );
