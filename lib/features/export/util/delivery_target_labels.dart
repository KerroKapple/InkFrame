// 目标软件 / 格式行的用户可读文案（P6 §2.1、§2.2）。
//
// 分段标签复用 P2 已有的四个 key（`sequenceTarget*`）——同一个东西不该有两套名字。
// 「待支持」Tooltip 按**写出器 id** 分，不按段分：将来 Final Cut 换成别的格式，
// 改的是 writerId 的映射，段本身不用动。
import '../../../l10n/generated/app_localizations.dart';
import '../models/delivery_settings.dart';
import '../models/delivery_writer_registry.dart';

String deliveryTargetLabel(AppLocalizations l, DeliveryTarget t) =>
    switch (t) {
      DeliveryTarget.resolve => l.sequenceTargetResolve,
      DeliveryTarget.premiere => l.sequenceTargetPremiere,
      DeliveryTarget.finalCut => l.sequenceTargetFinalCut,
      DeliveryTarget.jianying => l.sequenceTargetJianying,
    };

/// 不可选段的 Tooltip。没有对应文案（将来新增的 writerId）时返回 null ⇒ 不挂 Tooltip，
/// 总比挂一句瞎话好。
String? deliveryPendingTooltip(AppLocalizations l, DeliveryTarget t) =>
    switch (t.writerId) {
      DeliveryWriterIds.fcpXml => l.deliveryPendingFcpxml,
      DeliveryWriterIds.jianyingDraft => l.deliveryPendingJianying,
      _ => null,
    };

/// 「格式」行：由目标推导。没有写出器的段显示「—」而不是编个格式名。
String deliveryFormatLabel(
  AppLocalizations l,
  DeliveryWriterRegistry registry,
  DeliveryTarget target,
) {
  final DeliveryProjectWriter? writer = registry.forTarget(target);
  if (writer == null) return l.deliveryFormatPending;
  return switch (writer.id) {
    DeliveryWriterIds.edlCmx3600 => l.deliveryFormatEdlCmx3600,
    // 新写出器接上来但还没给文案时，退到它自报的扩展名（大写）——
    // 比显示「—」诚实：格式确实有，只是文案还没写。
    _ => writer.fileExtension.toUpperCase(),
  };
}
