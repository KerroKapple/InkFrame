// 节点右键菜单 take 组（menu_registry.dart 头注约定的组 20）：「设为当前」。
//
// 只对一张 take 卡出：目标集恰好一张、它是有产物的 result、来源配置节点还在画布上（resultTakeStatusOf 非 null）；
// 配置卡、孤儿产物、多选都不出这一行。已是当前（含「没固定、它是最新」）⇒ 打勾置灰。没有快捷键，不写 keyHint。
// 执行体在 providers/current_take_controller.dart（与检查器历史页、产物检查器、完成通知卡同一条路）：
// 先关菜单、焦点回画布（照 undo_menu_items），再设为当前。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/current_take_controller.dart';
import '../../util/take_status.dart';
import 'menu_registry.dart';

const String _setCurrentId = 'take.setCurrent';

/// 节点右键菜单的「设为当前」。
final List<CanvasMenuItemDef> setCurrentMenuItems = <CanvasMenuItemDef>[
  const CanvasMenuItemDef(
    id: _setCurrentId,
    scope: CanvasMenuScope.node,
    group: 20,
    order: 10,
    build: _buildSetCurrent,
    run: _runSetCurrent,
  ),
];

InkMenuEntry<String>? _buildSetCurrent(CanvasMenuContext c) {
  if (c.targets.length != 1) return null;
  final String targetId = c.targets.single;
  final List<CanvasNode> nodes =
      c.ref.watch(canvasNodesControllerProvider(c.canvasId)).valueOrNull ?? const <CanvasNode>[];
  CanvasNode? target;
  CanvasNode? source;
  for (final CanvasNode n in nodes) {
    if (n.id == targetId) target = n;
  }
  final String? sourceId = target?.sourceNodeId;
  for (final CanvasNode n in nodes) {
    if (n.id == sourceId && n.role == NodeRole.config) source = n;
  }
  final CanvasNode? result = target;
  if (result == null || result.role != NodeRole.result || source == null) return null;
  final ResultTakeStatus? status = resultTakeStatusOf(result, nodes);
  if (status == null) return null;
  return InkMenuEntry<String>(
    value: _setCurrentId,
    label: c.context.l10n.takeSetCurrent,
    glyph: InkGlyph.pin,
    enabled: !status.current,
    checked: status.current,
  );
}

/// 先关菜单、焦点当场回画布，再设为当前。c.context 是宿主的 context，菜单此刻已在卸载。
Future<void> _runSetCurrent(CanvasMenuContext c) async {
  if (c.targets.length != 1) {
    c.dismiss?.call();
    return;
  }
  final String resultId = c.targets.single;
  final AppLocalizations l = c.context.l10n;
  final ProviderContainer container = ProviderScope.containerOf(c.context, listen: false);
  c.dismiss?.call();
  await container.read(currentTakeControllerProvider(c.canvasId)).setCurrent(resultId, l: l);
}
