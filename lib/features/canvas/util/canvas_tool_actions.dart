// 画布工具动作：浮动工具条与单键快捷键（V / I / G / T / F / L）共用的唯一实现。
//
// 原来左侧工具条与右下角加号各写了一份「视口中心建节点 + 失败提示」，两份已经走岔过
// （一份只捕 InkError、一份什么都捕）。工具条和快捷键都调这里——同一个动作只有一条路径，
// 点按钮和按键的结果不会不一样。
//
// 与 canvas_node_delete.dart 同一类：要 BuildContext（弹框 / 出提示）的画布动作。
// 建泳道要开泳道编辑框，所以这里反向引了 widgets/lane_edit_dialog.dart。
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/link_mode_controller.dart';
import '../widgets/lane_edit_dialog.dart';
import 'canvas_snackbars.dart';
import 'node_position.dart';

/// 新节点（或导入脚本那条链的第一镜）的落点：视口中心（债150；视口未上报时回退旧
/// 固定区随机）。[random] 是测试注入口，null 时每次取系统熵。
Offset viewportCenteredNodeOrigin(
  WidgetRef ref, {
  required String canvasId,
  required CanvasNodeType type,
  Random? random,
}) =>
    pickViewportCenteredNodePosition(
      random: random ?? Random(),
      transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
      viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
      nodeSize: defaultNodeSize(type),
    );

/// 在视口中心建一个 [type] 节点；写库失败弹错误卡「添加节点失败」。
Future<void> addNodeAtViewportCenter(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required CanvasNodeType type,
  Random? random,
}) async {
  // 文案在 await 之前取：await 之后 context 可能已卸载。
  final String label = context.l10n.canvasNodeDefaultLabel;
  final String failed = context.l10n.canvasAddNodeFailed;
  try {
    await ref.read(canvasNodesControllerProvider(canvasId).notifier).addNode(
          label: label,
          type: type,
          position: viewportCenteredNodeOrigin(
            ref,
            canvasId: canvasId,
            type: type,
            random: random,
          ),
        );
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, failed);
  }
}

/// 开「新建泳道」对话框，确认后建泳道；写库失败弹错误卡「创建泳道失败」。
Future<void> addLaneViaDialog(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
}) async {
  final LaneEditResult? r = await showLaneEditDialog(context);
  if (r == null || !context.mounted) return;
  final String failed = context.l10n.laneCreateFailed;
  try {
    await ref.read(canvasLanesControllerProvider(canvasId).notifier).createLane(
          label: r.label,
          stylePrompt: r.stylePrompt,
          tintColor: r.tintColor,
        );
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, failed);
  }
}

/// 连线键此刻能不能按：已在连线模式（按 = 退出），或恰好选中一个节点（按 = 以它为源
/// 开始连线）。选中零个或多个时不知道从哪个节点连出去，所以不可按。
bool canToggleLink({required bool linking, required int selectedCount}) =>
    linking || selectedCount == 1;

/// 连线开关：在连线模式就退出；否则恰好选中一个节点时以它为源进入连线模式，其余情况不动。
///
/// 进连线时顺手回到选择工具：连线的下一步是点目标节点，而平移工具下卡片不收指针、
/// 根本点不到。退出连线不动工具态。
void toggleLinkMode(WidgetRef ref, {required String canvasId}) {
  final LinkModeController link =
      ref.read(linkModeControllerProvider(canvasId).notifier);
  if (ref.read(linkModeControllerProvider(canvasId)) != null) {
    link.cancel();
    return;
  }
  final Set<String> selected =
      ref.read(canvasSelectionControllerProvider(canvasId));
  if (selected.length != 1) return;
  ref.read(canvasToolModeProvider(canvasId).notifier).select();
  link.start(selected.single);
}

/// 选择工具：回到默认指针（退出平移工具），同时退出连线模式——与旧左侧工具条
/// 「选择」同义：选择 = 不在平移、也不在连线。
void activateSelectTool(WidgetRef ref, {required String canvasId}) {
  ref.read(canvasToolModeProvider(canvasId).notifier).select();
  ref.read(linkModeControllerProvider(canvasId).notifier).cancel();
}
