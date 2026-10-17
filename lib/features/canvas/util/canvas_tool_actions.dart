// 画布工具动作：浮动工具条与单键快捷键（V / I / G / T / F / L）共用的唯一实现。
//
// 原来左侧工具条与右下角加号各写了一份「视口中心建节点 + 失败提示」，两份已经走岔过
// （一份只捕 InkError、一份什么都捕）。工具条和快捷键都调这里——同一个动作只有一条路径，
// 点按钮和按键的结果不会不一样。
//
// 建节点只有一条路：addNodeFromMenu——建节点、判泳道写 laneId、新节点只单选不挪相机、写库失败弹错误卡，要连线时
// 连好线、不留半截。入口只在「落在哪」上分两种：
//   - 不带落点的：工具条建节点键、I / G / T、Tab 开的新建菜单里不带上下文的项、空画布的三个建节点 CTA、⌘K 的
//     新建节点——落在「视口中心 + 散布」
//     （addNodeAtViewportCenter 算好这一点再交给它；散布防连建叠成一摞）。菜单项上标着 I / G / T，走的就是这几个键
//     的那一条路；
//   - 带落点的：拖线松手、双击空白、空白处右键「新建…」——落在那一点（菜单锚点），不加散布。
//
// 与 canvas_node_delete.dart 同一类：要 BuildContext（弹框 / 出提示）的画布动作。
// 建泳道要开泳道编辑框，所以这里反向引了 widgets/lane_edit_dialog.dart。
//
// 新建菜单（widgets/create_node_menu.dart）的动作也在这里：在菜单锚点建节点并连好线（addNodeFromMenu，
// 不留半截）、从出端口拖到另一张卡上连线（linkByPortDrop，走连线模式那一条 linkTo）、全选。
//
// PR-8b 节点右键菜单与四个新键的动作也在这里，菜单与快捷键各调同一个函数：
//   - 生成（generateNode，Ctrl+↵ / ⌘↵）：InspectorSubmitController.submitWithPending——挂起的编辑并进终稿，与提示词条
//     「生成」走同一条 submit；
//   - 复制一份（duplicateNodes，Ctrl+D / ⌘D）：同类型 / 同 typeConfig / 同泳道，右下各偏一个 lg；
//   - 适应全部 / 适应选中（fitAllNodes / fitSelectedNodes，Shift+1 / Shift+2）：缩放条「适应」与空白处
//     右键菜单「适应视图」都是适应全部；⌘0 仍是缩放复位，不归这里；
//   - 存为角色（saveNodeAsCharacter）：与角色库「新建角色」同一条 createFromImage；
//   - 加入 / 移出泳道（moveNodesToLane）：走 moveNode，多选整批。
// 存为角色要开起名框，所以本文件又反向引了 theme 层的 InkNameDialog 与 widgets/node_card.dart 的显示名。
import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart'
    show CharacterAssetError;
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_name_dialog.dart';
import '../../../theme/tokens.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../models/style_lane.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_focus_request.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_prompt_bar_height.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/characters_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../providers/link_action_controller.dart';
import '../providers/link_mode_controller.dart';
import '../widgets/lane_edit_dialog.dart';
import '../widgets/node_card.dart';
import 'canvas_extent.dart';
import 'canvas_snackbars.dart';
import 'canvas_zoom.dart';
import 'create_menu_model.dart';
import 'drop_placement.dart';
import 'lane_geometry.dart';
import 'node_menu_model.dart';
import 'node_position.dart';
import 'viewport_fit.dart';

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

/// 「视口中心 + 散布」那一点换成视口坐标：新卡片的左上角画在这里（[viewportCenteredNodeOrigin] 的世界坐标过一遍
/// 相机）。判泳道吃的是视口坐标（[menuNodePlacement]），与带落点的入口同一种输入。
Offset viewportCenteredNodePoint(
  WidgetRef ref, {
  required String canvasId,
  required CanvasNodeType type,
  Random? random,
}) =>
    MatrixUtils.transformPoint(
      ref.read(canvasTransformControllerProvider(canvasId)).value,
      worldToStage(
        viewportCenteredNodeOrigin(ref, canvasId: canvasId, type: type, random: random),
      ),
    );

/// 在「视口中心 + 散布」建一个 [type] 节点：工具条建节点键、I / G / T、Tab 新建菜单里不带上下文的项共用。
/// 落点算好之后与新建菜单同一条路（[addNodeFromMenu]）：判泳道写 laneId、新节点只单选不挪相机、写库失败弹
/// 错误卡「添加节点失败」。
Future<void> addNodeAtViewportCenter(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required CanvasNodeType type,
  Random? random,
}) =>
    addNodeFromMenu(
      context,
      ref,
      canvasId: canvasId,
      type: type,
      placement: menuNodePlacement(
        ref,
        canvasId: canvasId,
        viewportPoint: viewportCenteredNodePoint(
          ref,
          canvasId: canvasId,
          type: type,
          random: random,
        ),
      ),
    );

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

/// 适应视口的基本留白：顶部让出浮动工具条那一条（与舞台顶部浮层同一个 stageTopInset），底部让出左下缩放条
/// 那一截（stageBottomInset），左右各一个 lg。提示词条显示时底部另算，见 [canvasFitInsets]。
const EdgeInsets kCanvasFitInsets = EdgeInsets.fromLTRB(
  InkSpacing.lg,
  InkToolbarSize.stageTopInset,
  InkSpacing.lg,
  InkToolbarSize.stageBottomInset,
);

/// 适应视口实际用的留白：[kCanvasFitInsets]，提示词条显示时（[promptBarHeight] > 0）底部改让出条子——条子高度
/// 加上它离舞台底的距离与一档间隙（promptBarClearance），与缩放条那一截取大的。条子只在恰好选中一张图像 / 视频
/// 配置时出现：这时按适应全部，最下面一排卡会贴着留白的下沿，不让就被条子压住（适应选中只框那一张、居中摆，
/// 碰不到条子，但同样按这份留白算）。
EdgeInsets canvasFitInsets({required double promptBarHeight}) => promptBarHeight <= 0
    ? kCanvasFitInsets
    : kCanvasFitInsets.copyWith(
        bottom: max(
          InkToolbarSize.stageBottomInset,
          promptBarHeight + InkToolbarSize.promptBarClearance,
        ),
      );

/// 适应全部（Shift+1；缩放条「适应」、空白处右键菜单「适应视图」同一个动作）：把画布上所有看得见的卡片
/// 框进视口（只缩小、不放大，见 viewport_fit.dart）。画布上没有卡片 ⇒ 回到初始相机。视口还没量出来 ⇒ 不动。
/// 节点还没载入时不动。
void fitAllNodes(WidgetRef ref, {required String canvasId}) {
  final List<CanvasNode>? nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull;
  if (nodes == null) return;
  _fitNodes(ref, canvasId: canvasId, nodes: nodes, resetWhenEmpty: true);
}

/// 适应选中（Shift+2）：只框选中的卡片；没有选中（或选中的都在折叠的泳道里）⇒ 不动。
void fitSelectedNodes(WidgetRef ref, {required String canvasId}) {
  final Set<String> selected =
      ref.read(canvasSelectionControllerProvider(canvasId));
  if (selected.isEmpty) return;
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  _fitNodes(
    ref,
    canvasId: canvasId,
    nodes: <CanvasNode>[
      for (final CanvasNode n in nodes)
        if (selected.contains(n.id)) n,
    ],
    resetWhenEmpty: false,
  );
}

/// 把 [nodes] 里看得见的（不在折叠泳道里的）卡片框进视口。卡片矩形与卡片实际画出来的位置同源
/// （nodeStageRect：世界 + 分道位移），泳道切片按有效厚度（折叠的道按轨宽），与 focusNodeOnCanvas 同一份取值。
void _fitNodes(
  WidgetRef ref, {
  required String canvasId,
  required List<CanvasNode> nodes,
  required bool resetWhenEmpty,
}) {
  final TransformationController transform =
      ref.read(canvasTransformControllerProvider(canvasId));
  final Set<String> collapsed = ref.read(laneCollapseProvider(canvasId));
  final List<CanvasNode> visible = <CanvasNode>[
    for (final CanvasNode n in nodes)
      if (n.laneId == null || !collapsed.contains(n.laneId)) n,
  ];
  if (visible.isEmpty) {
    if (resetWhenEmpty) transform.value = initialCanvasTransform();
    return;
  }
  final List<StyleLane> lanes =
      ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
          const <StyleLane>[];
  // 不在（现存）泳道里的卡片没有分道位移，也就不必去读泳道方向（与 focusNodeOnCanvas 同口径）。
  final Set<String> laneIds = <String>{for (final StyleLane l in lanes) l.id};
  final bool laned = visible.any((CanvasNode n) => laneIds.contains(n.laneId));
  final LaneDirection direction = laned
      ? (ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
          LaneDirection.horizontal)
      : LaneDirection.horizontal;
  final Matrix4? next = transformFittingNodes(
    nodes: visible,
    lanes: laned
        ? collapseLaneSlices(
            <({String id, double size})>[
              for (final StyleLane l in lanes) (id: l.id, size: l.size),
            ],
            collapsed,
          )
        : const <({String id, double size})>[],
    direction: direction,
    viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
    insets: canvasFitInsets(
      promptBarHeight: ref.read(canvasPromptBarHeightProvider(canvasId)),
    ),
  );
  if (next != null) transform.value = next;
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

/// 新建节点的落点：视口里的 [viewportPoint]（菜单锚点，或「视口中心 + 散布」那一点）→ 新卡片左上角的世界坐标 +
/// 泳道归属。
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
    // 没有泳道就不判道，也就不必去读泳道方向（与 _fitNodes 同口径）：工具条 / 单键建节点不为这个去碰画布仓储。
    direction: lanes.isEmpty
        ? LaneDirection.horizontal
        : (ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
            LaneDirection.horizontal),
  );
}

/// 建节点的唯一一条路（见头注）：在 [placement] 建一个 [type] 配置节点；给了 [edge] 就再从 [sourceNodeId] 连一条线到它。
///
/// 写入顺序 = 先建节点（落进泳道的再写泳道归属）、再连线。**不留半截**：节点建好之后任何一步失败，
/// 都把刚建的节点删掉（removeNode 同一个事务里级联软删它身上已有的线），再弹错误卡「添加节点失败」。
/// 「下一镜」的叙事边排在锚点已有的分叉之后（sortOrder 见 create_menu_model.nextNarrativeSortOrder）。
/// 成功后挂一条定位请求——新节点在画布下一帧被单选（widgets/stage/stage_overlays.dart 的 PendingFocusApplier 落地，
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
  final CreateMenuEdge? link = edge;
  // 要连线才取连线控制器：不带上下文的建节点（工具条 / 单键 / Tab 菜单）用不着它。
  final CanvasEdgesController? edges = link != null && sourceNodeId != null
      ? ref.read(canvasEdgesControllerProvider(canvasId).notifier)
      : null;
  final CanvasFocusRequestController focus =
      ref.read(canvasFocusRequestProvider.notifier);
  // 叙事边的序号按此刻锚点已有的出边算（同样在 await 之前取）；别的边不排序，取默认 0。
  final int sortOrder = edge?.type == EdgeType.narrative && sourceNodeId != null
      ? nextNarrativeSortOrder(
          anchorId: sourceNodeId,
          edges: ref.read(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
              const <CanvasEdge>[],
        )
      : 0;

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
    if (edges != null && link != null && sourceNodeId != null) {
      await edges.addEdge(
        sourceNodeId: sourceNodeId,
        targetNodeId: created.id,
        edgeType: link.type,
        role: link.role,
        sortOrder: sortOrder,
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

  // 只单选、不挪相机：新节点就落在用户眼前（拖线松手点 / 双击点 / 右键点 / 视口中心）。
  focus.request(canvasId: canvasId, nodeId: created.id, center: false);
}

// ===== PR-8b：节点右键菜单与 Ctrl+↵ / Ctrl+D 的动作 =====

/// 生成 [nodeId]（画布 Ctrl+↵ / ⌘↵ 与节点右键菜单「生成」共用；可不可生成的判据是
/// node_menu_model.generationTarget，调用方先判）。在忙（提交中 / 生成中）⇒ 不动。
///
/// 走 InspectorSubmitController.submitWithPending，**提示词不从画布节点里取**：提示词条里敲的字只经防抖落库
/// （savePromptDebounced），不回写画布节点——内存里的 node.promptText 可能是旧的，拿它去 submit 会把用户刚敲的
/// 字盖掉。submitWithPending 把还没发射的防抖 patch（连同写失败等重试的那几个键）并进终稿一并提交：生成读到的
/// 就是用户最后敲进去的那句，与提示词条带着最新文本提交是同一个效果。
///
/// 不再借退出路径的 flushPendingWrites 先冲一笔：那一笔写失败会直接按「已用尽」记账、不再重试，接着
/// submit 读到库里的旧提示词，白生成一次（B8）。
void generateNode(WidgetRef ref, {required String nodeId}) {
  final InspectorSubmitController submit =
      ref.read(inspectorSubmitControllerProvider(nodeId).notifier);
  if (submit.isBusy) return;
  unawaited(submit.submitWithPending());
}

/// 「复制一份」的落点偏移：往右下各一个 lg（与 24px 网格底同一步长）。
const Offset kDuplicateOffset = Offset(InkSpacing.lg, InkSpacing.lg);

/// 复制一份（Ctrl+D / ⌘D 与节点右键菜单共用）：[nodeIds] 里的每一张**配置**卡各复制一份——同类型、
/// 同 typeConfig、同泳道，标签加「副本」后缀，往右下偏 [kDuplicateOffset]。不复制边，不复制产物
/// （产物卡本身也不复制，判据 node_menu_model.duplicateSources）。
///
/// 只复制出一张 ⇒ 挂一条定位请求单选它、不挪相机（与新建菜单建节点同一条路）；多张 ⇒ 全选新的这几张。
/// 写库失败弹错误卡「添加节点失败」，已经复制出来的照样选中。
Future<void> duplicateNodes(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required Set<String> nodeIds,
}) async {
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final List<CanvasNode> sources = duplicateSources(<CanvasNode>[
    for (final CanvasNode n in nodes)
      if (nodeIds.contains(n.id)) n,
  ]);
  if (sources.isEmpty) return;
  // 文案与控制器都在 await 之前取：await 之后 context 可能已卸载。
  final AppLocalizations l = context.l10n;
  final List<String> labels = <String>[
    for (final CanvasNode s in sources)
      l.canvasNodeCopyName(nodeDisplayName(context, s)),
  ];
  final String failed = l.canvasAddNodeFailed;
  final CanvasNodesController controller =
      ref.read(canvasNodesControllerProvider(canvasId).notifier);
  final CanvasFocusRequestController focus =
      ref.read(canvasFocusRequestProvider.notifier);
  final List<String> created = <String>[];
  try {
    for (int i = 0; i < sources.length; i++) {
      final CanvasNode source = sources[i];
      final CanvasNode copy = await controller.addNode(
        label: labels[i],
        type: source.type,
        laneId: source.laneId,
        position: clampIntoWorldReach(source.position + kDuplicateOffset),
        size: source.size,
        typeConfig: Map<String, Object?>.of(source.typeConfig),
      );
      created.add(copy.id);
    }
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, failed);
  }
  if (created.isEmpty) return;
  if (created.length == 1) {
    focus.request(canvasId: canvasId, nodeId: created.single, center: false);
    return;
  }
  if (!context.mounted) return;
  ref.read(canvasSelectionControllerProvider(canvasId).notifier).selectAll(created);
}

/// 存为角色（节点右键菜单）：[node] 是带图的产物节点（判据 node_menu_model.characterSource）。
///
/// 与角色库「新建角色」同一条路（character_library_panel.dart 的 createCharacterFromFile）：先弹 InkNameDialog
/// 起名，再调 charactersController.createFromImage；源文件经 fileResolverService 解析成绝对路径。捕获集 =
/// createFromImage 的真实抛出集（仓储 InkError / 资产服务 CharacterAssetError / dart:io FileSystemException），
/// 失败一律出错误卡。画布上看不见角色库，所以成功也出一张卡（与画廊「存为角色」同一句）。
/// 角色控制器是 autoDispose：操作期间 listenManual 挂住，先等它 build 完再建（与画廊同一做法）。
Future<void> saveNodeAsCharacter(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String canvasId,
  required CanvasNode node,
}) async {
  final String? relativePath = node.imageUrl;
  if (relativePath == null) return;
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => InkNameDialog(
      title: ctx.l10n.characterNew,
      hint: ctx.l10n.characterFieldName,
      confirmLabel: ctx.l10n.characterSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
  final String trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || !context.mounted) return;
  // 文案与通知出口在 await 之前取好：之后 context 可能已卸载（切了标签 / 换了画布）。
  final AppLocalizations l = context.l10n;
  final ToastService toast = ref.read(toastServiceProvider);
  final String absolutePath;
  try {
    absolutePath = ref
        .read(fileResolverServiceProvider)
        .resolve(projectId: projectId, canvasId: canvasId, relativePath: relativePath)
        .path;
  } on PathSecurityError catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
    return;
  }
  final ProviderSubscription<AsyncValue<List<Character>>> keep =
      ref.listenManual(charactersControllerProvider(projectId), (_, _) {});
  try {
    await ref.read(charactersControllerProvider(projectId).future);
    if (!context.mounted) return;
    await ref
        .read(charactersControllerProvider(projectId).notifier)
        .createFromImage(name: trimmed, sourceAbsolutePath: absolutePath);
    toast.show(l.gallerySavedAsCharacter, kind: ToastKind.success);
  } on InkError catch (e) {
    toast.show(l10nErrorFor(l, e), kind: ToastKind.error);
  } on CharacterAssetError catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } on FileSystemException catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } finally {
    keep.close();
  }
}

/// 加入泳道（[laneId] 非空）/ 移出泳道（[laneId] 为 null）：[nodeIds] 整批走 moveNode。已经在目标道里的
/// 不动。位置一并挪进目标道的带里（移出时屏幕上不动），见 node_menu_model.laneMoveDelta——位置决定泳道
/// 归属是整个画布的规则，只改 lane_id 卡片会画在带外。写库失败弹「节点移动失败」（控制器已回滚那一张）。
Future<void> moveNodesToLane(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required Set<String> nodeIds,
  required String? laneId,
}) async {
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final List<CanvasNode> movers = laneMoveCandidates(<CanvasNode>[
    for (final CanvasNode n in nodes)
      if (nodeIds.contains(n.id)) n,
  ], laneId);
  if (movers.isEmpty) return;
  final List<StyleLane> lanes =
      ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
          const <StyleLane>[];
  final List<({String id, double size})> slices = collapseLaneSlices(
    <({String id, double size})>[
      for (final StyleLane l in lanes) (id: l.id, size: l.size),
    ],
    ref.read(laneCollapseProvider(canvasId)),
  );
  final LaneDirection direction =
      ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
          LaneDirection.horizontal;
  final double scale =
      scaleOf(ref.read(canvasTransformControllerProvider(canvasId)).value);
  final String failed = context.l10n.nodeMoveFailed;
  final CanvasNodesController controller =
      ref.read(canvasNodesControllerProvider(canvasId).notifier);
  try {
    for (final CanvasNode node in movers) {
      await controller.moveNode(
        node.id,
        laneMoveDelta(
          node: node,
          toLaneId: laneId,
          laneSlices: slices,
          direction: direction,
          scale: scale,
        ),
        laneId: laneId,
      );
    }
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, failed);
  }
}
