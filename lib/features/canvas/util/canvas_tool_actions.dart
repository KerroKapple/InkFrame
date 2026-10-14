// 画布工具动作：浮动工具条与单键快捷键（V / I / G / T / F / L）共用的唯一实现。
//
// 原来左侧工具条与右下角加号各写了一份「视口中心建节点 + 失败提示」，两份已经走岔过
// （一份只捕 InkError、一份什么都捕）。工具条和快捷键都调这里——同一个动作只有一条路径，
// 点按钮和按键的结果不会不一样。
//
// 与 canvas_node_delete.dart 同一类：要 BuildContext（弹框 / 出提示）的画布动作。
// 建泳道要开泳道编辑框，所以这里反向引了 widgets/lane_edit_dialog.dart。
//
// 新建菜单（widgets/create_node_menu.dart）的动作也在这里：在菜单锚点建节点并连好线（addNodeFromMenu，
// 不留半截）、从出端口拖到另一张卡上连线（linkByPortDrop，走连线模式那一条 linkTo）、全选、适应视图。
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_focus_request.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../providers/link_action_controller.dart';
import '../providers/link_mode_controller.dart';
import '../widgets/lane_edit_dialog.dart';
import 'canvas_snackbars.dart';
import 'canvas_zoom.dart';
import 'create_menu_model.dart';
import 'drop_placement.dart';
import 'lane_geometry.dart';
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

/// 全选当前画布的全部节点（Ctrl+A / ⌘A 与空白处右键菜单「全选」共用）。节点还没载入时不动。
void selectAllNodes(WidgetRef ref, {required String canvasId}) {
  final List<CanvasNode>? nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull;
  if (nodes == null) return;
  ref
      .read(canvasSelectionControllerProvider(canvasId).notifier)
      .selectAll(nodes.map((CanvasNode n) => n.id));
}

/// 适应视图：回到初始相机——与左下缩放条的「适应」格同一个动作（canvas_zoom_bar.dart 那一格写的
/// 也是 initialCanvasTransform）。
void fitCanvasView(WidgetRef ref, {required String canvasId}) {
  ref.read(canvasTransformControllerProvider(canvasId)).value =
      initialCanvasTransform();
}

/// 从出端口拖到另一张卡上松手：等价于「连线模式里选源 → 点目标」。先以 [sourceNodeId] 进连线模式，
/// 再走 LinkActionController.linkTo——智能默认角色（image → video 默认首帧）、23505 去重、结果提示
/// （画布 ref.listen 出通知卡）都是那一条路径的，不另写一套；linkTo 无论成败都会退出连线模式。
Future<void> linkByPortDrop(
  WidgetRef ref, {
  required String canvasId,
  required String sourceNodeId,
  required String targetNodeId,
}) {
  ref.read(linkModeControllerProvider(canvasId).notifier).start(sourceNodeId);
  return ref
      .read(linkActionControllerProvider(canvasId).notifier)
      .linkTo(targetNodeId);
}

/// 新建菜单的落点：视口里的 [viewportPoint]（菜单锚点）→ 新卡片左上角的世界坐标 + 泳道归属。
/// 相机、泳道切片（有效厚度，折叠的道按轨宽算）与方向都取此刻的现值，判定本体见 drop_placement.dart。
NodePlacement menuNodePlacement(
  WidgetRef ref, {
  required String canvasId,
  required Offset viewportPoint,
}) {
  final List<StyleLane> lanes =
      ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
          const <StyleLane>[];
  return createNodePlacement(
    viewportPoint: viewportPoint,
    transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
    laneSlices: collapseLaneSlices(
      <({String id, double size})>[
        for (final StyleLane l in lanes) (id: l.id, size: l.size),
      ],
      ref.read(laneCollapseProvider(canvasId)),
    ),
    direction: ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
        LaneDirection.horizontal,
  );
}

/// 新建菜单建节点：在 [placement] 建一个 [type] 配置节点；给了 [edge] 就再从 [sourceNodeId] 连一条线到它。
///
/// 写入顺序 = 先建节点（落进泳道的再写泳道归属）、再连线。**不留半截**：节点建好之后任何一步失败，
/// 都把刚建的节点删掉（removeNode 同一个事务里级联软删它身上已有的线），再弹错误卡「添加节点失败」。
/// 成功后挂一条定位请求——新节点在画布下一帧被单选（canvas_view 的 _PendingFocusApplier 落地，
/// 不在这里直接写选中）。
Future<void> addNodeFromMenu(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required CanvasNodeType type,
  required NodePlacement placement,
  String? sourceNodeId,
  CreateMenuEdge? edge,
}) async {
  // 文案与控制器都在 await 之前取：await 之后 context 可能已卸载。
  final String label = context.l10n.canvasNodeDefaultLabel;
  final String failed = context.l10n.canvasAddNodeFailed;
  final CanvasNodesController nodes =
      ref.read(canvasNodesControllerProvider(canvasId).notifier);
  final CanvasEdgesController edges =
      ref.read(canvasEdgesControllerProvider(canvasId).notifier);
  final CanvasFocusRequestController focus =
      ref.read(canvasFocusRequestProvider.notifier);

  final CanvasNode created;
  try {
    // 泳道归属随建节点一次写进去（落进道里的卡与拖卡片落点同一套判定，见 menuNodePlacement）。
    created = await nodes.addNode(
      label: label,
      type: type,
      position: placement.world,
      laneId: placement.laneId,
    );
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, failed);
    return;
  }

  try {
    final CreateMenuEdge? link = edge;
    if (link != null && sourceNodeId != null) {
      await edges.addEdge(
        sourceNodeId: sourceNodeId,
        targetNodeId: created.id,
        edgeType: link.type,
        role: link.role,
      );
    }
  } on InkError catch (_) {
    try {
      await nodes.removeNode(created.id);
    } on InkError catch (_) {
      // 回滚也没成：节点留在画布上——至少让它被选中，用户看得见、能手动删。
      focus.request(canvasId: canvasId, nodeId: created.id, center: false);
    }
    if (context.mounted) showCanvasSnack(context, failed);
    return;
  }

  // 只单选、不挪相机：新节点就落在用户刚点的地方（拖线松手点 / 双击点 / 右键点 / Tab 的视口中心）。
  focus.request(canvasId: canvasId, nodeId: created.id, center: false);
}
