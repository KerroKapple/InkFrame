// 交付面板的测试锚点 Key。
//
// 单独一个文件：主按钮与进度环挂在 **标签栏**（features/shell/widgets/shell_tab_bar.dart）
// 上，面板本体在 features/export/widgets/ 下，两边都要用同一批 Key。挂在任一侧
// 都会把 import 绕成环（与 batch_slot_parts / onboarding_anchors 同因）。
import 'package:flutter/widgets.dart';

import 'models/delivery_settings.dart';
import 'util/delivery_preflight.dart';

abstract final class DeliveryKeys {
  /// 面板最外层容器——两态（空态 / 真面板）都挂它，「面板在不在树上」的唯一判据。
  static const Key panel = Key('delivery.panel');
  static const Key emptyState = Key('delivery.emptyState');

  /// 目标软件分段。
  static Key segment(DeliveryTarget t) =>
      ValueKey<String>('delivery.segment.${t.wire}');

  /// 工程文件 / 媒体两组里的值。
  static const Key formatValue = Key('delivery.value.format');
  static const Key tcStartField = Key('delivery.value.tcStart');

  /// 三个开关。
  static const Key relativePathsToggle = Key('delivery.toggle.relativePaths');
  static const Key sceneMarkersToggle = Key('delivery.toggle.sceneMarkers');
  static const Key shotLanguageToggle = Key('delivery.toggle.shotLanguage');

  /// 交付前检查。
  static const Key preflight = Key('delivery.preflight');
  static const Key preflightCount = Key('delivery.preflight.count');
  static Key check(DeliveryCheckId id) =>
      ValueKey<String>('delivery.check.${id.name}');

  /// 底部摘要两行。
  static const Key footerOutput = Key('delivery.footer.output');
  static const Key footerInclude = Key('delivery.footer.include');

  /// 结果条。
  static const Key resultBar = Key('delivery.result');
  static const Key resultOpenFolder = Key('delivery.result.openFolder');
  static const Key resultCopyPath = Key('delivery.result.copyPath');
  static const Key resultRetry = Key('delivery.result.retry');
  static const Key resultDismiss = Key('delivery.result.dismiss');

  /// 标签栏右侧的主按钮与「序列」标签右边的进度环。
  static const Key deliverButton = Key('shellAction-deliver');
  static const Key progressRing = Key('delivery.progressRing');
}
