// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责切分（HI-18）：
//   - _CanvasBody：状态装配 + 节点 tap 语义 + 连线事件 → snackbar 副作用（ref.listen）
//   - _CanvasStage：InteractiveViewer 舞台（连线层 / 节点卡片 / 边删除按钮）
//   - 平移工具（H / 按住空格，canvas_tool_mode.dart）：_PanGate 让舞台内容与泳道标题栏层
//     不收指针、拖哪儿都是拖画布；_StagePanCursor 换手形光标
//   - 可播放性 IO 判定在 playableVideoPathProvider；连线编排在 LinkActionController
//   - 新建菜单（create_node_menu.dart）：从卡片出端口拖线（_NodeCardSlot 报拖线、_PendingWireLayer 画
//     实时虚线、舞台层判落点——落在卡上 = linkTo，落在空白 = 带上下文开菜单）、空白处双击 / 右键
//     （_BlankPointerDetector）都开它；菜单宿主 CanvasMenuHost 包在 _CanvasBody 最外层

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/canvas_style.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_focus_request.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_id.dart';
import '../providers/link_action_controller.dart';
import '../providers/link_mode_controller.dart';
import '../providers/node_drag_delta.dart';
import '../providers/playable_video_path.dart';
import '../providers/selected_edge_controller.dart';
import '../util/canvas_extent.dart';
import '../util/canvas_node_delete.dart';
import '../util/canvas_snackbars.dart';
import '../util/canvas_tool_actions.dart';
import '../util/canvas_zoom.dart';
import '../util/drop_placement.dart';
import '../util/edge_hit_test.dart';
import '../util/edge_style.dart';
import '../util/lineage_edges.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../util/lane_geometry.dart';
import '../util/lane_pin_geometry.dart';
import '../../shell/widgets/shell_empty_state.dart';
import 'canvas_empty_state.dart';
import 'canvas_grid_painter.dart';
import 'create_node_menu.dart';
import 'edge_painter.dart';
import 'left_rail/left_rail_actions.dart';
import 'lane_background.dart';
import 'canvas_shortcuts.dart';
import 'lane_edit_dialog.dart';
import 'lane_title_bar.dart';
import 'lane_toolbar.dart';
import 'node_card.dart';
import 'video_lightbox.dart';

// InteractiveViewer 平移越界余量（画布外延展空间，非视觉 token）
const double kCanvasBoundaryMargin = 2000;

class CanvasView extends ConsumerWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    final colors = context.inkColors;
    if (canvasId == null) {
      // 生产路径里到不了这里：外壳的 CanvasTab 在 canvasId == null 时就换上了
      // 同一个空态（还带「回到 Studio」CTA）。直接 mount CanvasView 的测试 /
      // 工具会走到这一支，所以渲染的是同一块共用空态，而不是另造一块。
      return ColoredBox(
        color: colors.surface1,
        child: ShellEmptyState(
          icon: Icons.account_tree_outlined,
          title: context.l10n.shellCanvasEmptyTitle,
          body: context.l10n.shellCanvasEmptyBody,
        ),
      );
    }

    final nodesAsync = ref.watch(canvasNodesControllerProvider(canvasId));
    return nodesAsync.when(
      loading: () => Container(
        color: colors.surface1,
        child: const Center(child: CircularProgressIndicator()),
      ),
      // raw toString 上屏收敛（GAP-3 审计;设置页安全存储探测行的诊断详情
      // 为有意例外）——走 l10n 映射。
      error: (err, _) => _LoadError(message: l10nAsyncError(context, err)),
      data: (nodes) => _PendingFocusApplier(
        canvasId: canvasId,
        nodes: nodes,
        child: _CanvasBody(canvasId: canvasId, nodes: nodes),
      ),
    );
  }
}

/// 挂起的定位请求（canvas_focus_request.dart）在本画布落地：节点已载入（本层只在 data 分支里）、
/// 视口已上报尺寸之后，帧后单选 + 移到视口中心，并消费掉请求。
///
/// 跨画布定位时本画布是切过去才挂上来的；直接在切换那一刻写选中会被 autoDispose 回收。
/// 请求的节点不在本画布（已删）时只消费、不定位。
class _PendingFocusApplier extends ConsumerStatefulWidget {
  const _PendingFocusApplier({
    required this.canvasId,
    required this.nodes,
    required this.child,
  });

  final String canvasId;
  final List<CanvasNode> nodes;
  final Widget child;

  @override
  ConsumerState<_PendingFocusApplier> createState() => _PendingFocusApplierState();
}

class _PendingFocusApplierState extends ConsumerState<_PendingFocusApplier> {
  @override
  Widget build(BuildContext context) {
    final CanvasFocusRequest? request = ref.watch(canvasFocusRequestProvider);
    // 视口尺寸恒 watch：本层自己给这个 autoDispose provider 保活，不指望外层碰巧有人订阅
    // （生产里 CanvasShortcuts 也 watch 着，但落地不该依赖它）。重建只到本层——返回的是
    // 同一个 child 实例，舞台不跟着重建。
    final Size viewport = ref.watch(canvasViewportSizeProvider(widget.canvasId));
    if (request != null && request.canvasId == widget.canvasId && !viewport.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _land(request));
    }
    return widget.child;
  }

  void _land(CanvasFocusRequest request) {
    if (!mounted || ref.read(canvasFocusRequestProvider) != request) return;
    ref.read(canvasFocusRequestProvider.notifier).consume(request);
    for (final CanvasNode node in widget.nodes) {
      if (node.id == request.nodeId) {
        if (request.center) {
          focusNodeOnCanvas(ref, canvasId: widget.canvasId, node: node);
        } else {
          ref.read(canvasSelectionControllerProvider(widget.canvasId).notifier).select(node.id);
        }
        return;
      }
    }
  }
}

class _EdgeDeleteButton extends StatelessWidget {
  const _EdgeDeleteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Material(
      color: colors.surface1,
      shape: CircleBorder(side: BorderSide(color: colors.danger, width: 1.5)),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.close, size: 16, color: colors.danger),
        ),
      ),
    );
  }
}

class _SelectionCountChip extends StatelessWidget {
  const _SelectionCountChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Material(
      color: colors.surface3,
      borderRadius: BorderRadius.circular(InkRadius.pill),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md,
          vertical: InkSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline, size: 14, color: colors.accent),
            const SizedBox(width: InkSpacing.xs),
            Text(
              context.l10n.canvasSelectionCount(count),
              style: typo.meta.copyWith(color: colors.fg1),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkHintBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Material(
      color: colors.surface3,
      borderRadius: BorderRadius.circular(InkRadius.md),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md,
          vertical: InkSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 16, color: colors.accent),
            const SizedBox(width: InkSpacing.sm),
            Flexible(
              child: Text(
                context.l10n.linkModeHint,
                style: typo.body.copyWith(color: colors.fg1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      color: colors.surface1,
      padding: const EdgeInsets.all(InkSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.canvasLoadFailed,
              style: typo.body.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.sm),
            Text(
              message,
              style: typo.meta.copyWith(color: colors.fg3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态装配层：连线事件 snackbar 副作用 + 节点 tap 语义 + 布局组合。
class _CanvasBody extends ConsumerWidget {
  const _CanvasBody({required this.canvasId, required this.nodes});

  final String canvasId;
  final List<CanvasNode> nodes;

  /// 连线结果事件 → 通知卡映射（ME-08：duplicate / failed 分流）。
  /// 连上了是 success；自连 / 已存在是没连成但什么也没坏，用户换个目标就行 → warning；
  /// 只有写库失败才是 error（错误卡不自动消失）。
  void _onLinkEvent(BuildContext context, LinkActionEvent? event) {
    if (event == null) return;
    final l10n = context.l10n;
    final (String text, ToastKind kind) = switch (event.result) {
      LinkActionResult.created => (l10n.linkCreated, ToastKind.success),
      LinkActionResult.selfLinkRejected =>
        (l10n.linkSelfNotAllowed, ToastKind.warning),
      LinkActionResult.duplicate => (l10n.linkAlreadyExists, ToastKind.warning),
      LinkActionResult.failed => (l10n.linkCreateFailed, ToastKind.error),
    };
    showCanvasSnack(context, text, kind: kind);
  }

  Future<void> _handleNodeTap(
    BuildContext context,
    WidgetRef ref,
    CanvasNode node,
  ) async {
    // link 模式：编排交给 LinkActionController，结果经 ref.listen 出 snackbar。
    if (ref.read(linkModeControllerProvider(canvasId)) != null) {
      await ref
          .read(linkActionControllerProvider(canvasId).notifier)
          .linkTo(node.id);
      return;
    }

    final selectionCtrl =
        ref.read(canvasSelectionControllerProvider(canvasId).notifier);

    // 可播放 video result → 打开 Lightbox，不走常规多选。
    final playablePath = ref.read(playableVideoPathProvider(node));
    if (playablePath != null) {
      selectionCtrl.select(node.id);
      await showVideoLightbox(context, videoPath: playablePath);
      return;
    }

    final keyboard = HardwareKeyboard.instance;
    final modifierHeld =
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed;
    selectionCtrl.select(node.id, toggle: modifierHeld);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LinkActionEvent?>(
      linkActionControllerProvider(canvasId),
      (_, next) => _onLinkEvent(context, next),
    );

    // 本层不再 watch 选中/链接态——这两类高频变化下沉到各插槽各自 watch，
    // 避免改一次选中就整层（含全部节点卡片）重建。
    void onEmptyTap() {
      if (ref.read(linkModeControllerProvider(canvasId)) != null) {
        ref.read(linkModeControllerProvider(canvasId).notifier).cancel();
      }
      ref.read(canvasSelectionControllerProvider(canvasId).notifier).clear();
      ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
    }

    final Widget canvasArea;
    if (nodes.isEmpty) {
      canvasArea = CanvasEmptyState(
        canvasId: canvasId,
        onBackgroundTap: onEmptyTap,
      );
    } else {
      canvasArea = _CanvasStage(
        canvasId: canvasId,
        nodes: nodes,
        onNodeTap: (node) => _handleNodeTap(context, ref, node),
        onEmptyTap: onEmptyTap,
      );
    }

    // 顶部三条浮层从 stageTopInset 起：舞台顶部居中压着浮动工具条（canvas_screen 画在
    // 本层之上），从 md 起的话连线提示的后半句会被工具条盖住。
    final Widget leftArea = Stack(
      children: [
        Positioned.fill(child: canvasArea),
        // 边/泳道/泳道方向加载失败 → 非阻塞横幅（节点照常渲染），可忽略。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: _EdgeLaneErrorSlot(canvasId: canvasId),
        ),
        // 链接提示条：仅随 linkMode 重建。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: _LinkHintSlot(canvasId: canvasId),
        ),
        // 多选计数 chip：仅随选中数量重建。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          right: InkSpacing.md,
          child: _SelectionCountSlot(canvasId: canvasId),
        ),
        // 泳道工具栏：左下角，叠在缩放条（canvas_screen，left 12 / bottom 12）之上，
        // 左沿与它对齐。
        Positioned(
          bottom: InkToolbarSize.stageBottomInset,
          left: InkSpacing.s12,
          child: LaneToolbar(canvasId: canvasId),
        ),
      ],
    );

    // 节点 Inspector 已迁到右侧面板（canvas_inspector_panel.dart），本层只剩画布。
    // 新建菜单 / 空白处右键菜单的宿主包在画布区最外层：菜单浮在 Overlay 上，锚点坐标系就是这一块
    // （= 舞台视口；空态画布同样包着，Tab 在空画布上也开得出来）。
    return CanvasMenuHost(canvasId: canvasId, child: leftArea);
  }
}

/// 舞台层：InteractiveViewer + 连线层 + 节点卡片 + 选中边删除按钮。
class _CanvasStage extends ConsumerWidget {
  const _CanvasStage({
    required this.canvasId,
    required this.nodes,
    required this.onNodeTap,
    required this.onEmptyTap,
  });

  final String canvasId;
  final List<CanvasNode> nodes;
  final void Function(CanvasNode node) onNodeTap;
  final VoidCallback onEmptyTap;

  Future<void> _handleEdgeDelete(
    BuildContext context,
    WidgetRef ref,
    CanvasEdge edge,
  ) async {
    ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
    final edgesCtrl = ref.read(
      canvasEdgesControllerProvider(canvasId).notifier,
    );
    try {
      final removed = await edgesCtrl.removeEdge(edge.id);
      if (removed == null || !context.mounted) return;
      showCanvasUndoSnack(
        context,
        message: context.l10n.edgeDeleted,
        onUndo: () => _restoreEdge(context, edgesCtrl, removed),
      );
    } on InkError catch (_) {
      // 删失败：EdgesController 已回滚内存，SelectedEdge 已清。回滚让连线**冒回来**，
      // 可那只是现象——不说一声，用户只看到「删掉的线又回来了」，不知道是没删成。
      // 删节点 / 删泳道失败都有提示，删连线原来是唯一不说的那个。
      if (context.mounted) showCanvasSnack(context, context.l10n.edgeDeleteFailed);
    }
  }

  Future<void> _restoreEdge(
    BuildContext context,
    CanvasEdgesController ctrl,
    CanvasEdge edge,
  ) async {
    try {
      await ctrl.restore(edge);
    } on InkError catch (_) {
      if (context.mounted) showCanvasSnack(context, context.l10n.undoFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    // 选中/链接态不在本层 watch——下沉到 _NodeCardSlot 各自 watch，改选中
    // 只重建涉及的卡片，不再整层重建（丝滑核心）。
    final selectedEdgeId = ref.watch(selectedEdgeControllerProvider(canvasId));
    final edges =
        // 良性降级（GAP-3 审计 B 类）：错误横幅在 _EdgeLaneErrorSlot
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    // 泳道数据。
    final lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
        const <StyleLane>[];
    final direction =
        ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
        LaneDirection.horizontal;
    // 折叠态（纯 UI，不持久化）。
    final collapsedIds = ref.watch(laneCollapseProvider(canvasId));
    // 拖拽落点 → 泳道归属用的切片，整层算一次复用给各卡片插槽。
    // 【有效厚度】：折叠的道按 kCollapsedLaneSize（Lanes 稿改动 4）——几何全家同吃这一份，
    // 折叠才真的省空间。
    final laneSlices = collapseLaneSlices(
      [for (final l in lanes) (id: l.id, size: l.size)],
      collapsedIds,
    );
    // 折叠道里的节点不画：连线 / 命中 / 选中边几何都只看这份可见集。
    final visibleNodes = [
      for (final n in nodes)
        if (n.laneId == null || !collapsedIds.contains(n.laneId)) n,
    ];
    // 产出线：由 source_node_id 推导（不落库、点不中、删不掉——命中仍只看存量边），
    // 只在可见节点之间推：折叠道里的端点不画，线也不画。整层算一次，连线层与端口共用。
    final lineage = deriveLineageEdges(nodes: visibleNodes, edges: edges);
    // 端口按需显示：哪一侧真挂着画出来的线（存量边 + 产出线）就常驻那一侧。
    final ports = connectedPortSides(
      nodes: visibleNodes,
      edges: edges,
      lineage: lineage,
    );

    // PL-2：绑定快捷键缩放共用的变换控制器（按 canvasId 分族；gesture 平移/缩放照常）。
    final transformController = ref.watch(
      canvasTransformControllerProvider(canvasId),
    );

    // 舞台坐标这一点压着哪条连线。命中用渲染位置（含分道位移），与 EdgePainter 同源。
    String? edgeAt(Offset stagePoint) => hitTestEdge(
          point: stagePoint,
          edges: edges,
          nodes: displacedNodes(
            nodes: visibleNodes,
            lanes: laneSlices,
            direction: direction,
            transform: transformController.value,
          ),
          direction: direction,
        );

    void onEdgeLayerTap(TapDownDetails d) {
      final hitId = edgeAt(d.localPosition);
      if (hitId != null) {
        ref.read(selectedEdgeControllerProvider(canvasId).notifier).select(hitId);
        return;
      }
      onEmptyTap();
    }

    // 空白处双击 → 在双击点开新建菜单；空白处右键 → 在那一点开空白处右键菜单（create_node_menu.dart）。
    // 压着连线不算空白：连线自己的右键菜单不归这一版。菜单锚点是视口坐标（舞台坐标过一遍相机）。
    void onBlankDoubleDown(Offset stagePoint) {
      if (edgeAt(stagePoint) != null) return;
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openCreate(
            MatrixUtils.transformPoint(transformController.value, stagePoint),
          );
    }

    void onBlankSecondaryDown(Offset stagePoint) {
      if (edgeAt(stagePoint) != null) return;
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openBlank(
            MatrixUtils.transformPoint(transformController.value, stagePoint),
          );
    }

    final selectedGeometry = _selectedEdgeGeometry(
      selectedEdgeId: selectedEdgeId,
      edges: edges,
      nodes: visibleNodes,
    );

    // 全向无限画布：居中定舞台（100k×100k，世界原点在正中央）。
    // Positioned/painter 使用舞台坐标 = 世界坐标 + kStageOrigin。
    const stage = kStageSize;

    // 各泳道起始边（屏幕坐标 = 有效厚度顺序累计），分道位移组用。
    final laneStarts = <String, double>{};
    {
      var offset = 0.0;
      for (final l in laneSlices) {
        laneStarts[l.id] = offset;
        offset += l.size;
      }
    }
    // 无道（或道已不存在）的节点走全局变换。
    final freeNodes = [
      for (final n in nodes)
        if (n.laneId == null || !laneStarts.containsKey(n.laneId)) n,
    ];

    // 卡片的绘制顺序：无道的先画，再逐条道画道里的（折叠的道不画）。拖线落点找「最上面那张卡」
    // 按它倒着找，与肉眼看到的叠放一致。
    final List<CanvasNode> paintOrder = <CanvasNode>[
      ...freeNodes,
      for (final StyleLane lane in lanes)
        if (!collapsedIds.contains(lane.id))
          for (final CanvasNode n in nodes)
            if (n.laneId == lane.id) n,
    ];

    // 从出端口拖线后松手：落在另一张卡上 = 连线（走连线模式那一条 linkTo：智能默认角色、23505 去重、
    // 结果提示都是它的）；落在空白处 = 在松手点开新建菜单，带「从哪张卡拖出来」的上下文；
    // 落回源卡片自己 = 什么都不做。
    void onWireDrop(WireDrag drag) {
      final Matrix4 m = transformController.value;
      final String? target = topmostNodeAt(
        point: drag.pointer,
        drawn: displacedNodes(
          nodes: paintOrder,
          lanes: laneSlices,
          direction: direction,
          transform: m,
        ),
      );
      if (target == drag.sourceNodeId) return;
      if (target != null) {
        linkByPortDrop(
          ref,
          canvasId: canvasId,
          sourceNodeId: drag.sourceNodeId,
          targetNodeId: target,
        );
        return;
      }
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openCreate(
            MatrixUtils.transformPoint(m, drag.pointer),
            sourceNodeId: drag.sourceNodeId,
          );
    }

    return Container(
      color: colors.surface1,
      // 视口尺寸上报给缩放层（围绕视口中心缩放需要）。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(canvasViewportSizeProvider(canvasId).notifier).setSize(size);
            }
          });
          // 泳道模型（终版）：泳道栈锚在世界原点——拖画布时整体跟着世界走，
          // 缩放时道厚不变、只有道内内容以本道起始边为锚缩放。
          // 皮分两组同偏移平移：底色带在世界内容之下，标题栏/拖拽条之上。
          //
          // 偏移必须用 Positioned（每帧重建）而非 Transform.translate：
          // RenderBox.hitTest 先按未变换的盒子边界筛，Transform 只移画面
          // 不移命中区——平移后泳道边界"看得见摸不着"（宽度拖拽锁死）。
          final horizontal = direction == LaneDirection.horizontal;
          final lanesTotal = laneSlices.fold(0.0, (sum, l) => sum + l.size);
          // 皮层盒子比泳道栈多留一个标题栏的余量（BOARD P2-3）：竖向窄道的标题栏按下限宽
          // 溢出到栈外时仍在盒内——RenderBox.hitTest 先按盒界筛，盒外的按钮看得见点不到。
          final skinExtent = lanesTotal + LaneTitleBar.minWidth;
          Widget laneShifted(Widget child) => ValueListenableBuilder<Matrix4>(
                valueListenable: transformController,
                builder: (context, m, c) {
                  final off = laneStackOffset(m, direction);
                  return Stack(
                    children: [
                      Positioned(
                        left: horizontal ? 0 : off,
                        top: horizontal ? off : 0,
                        width: horizontal ? size.width : skinExtent,
                        height: horizontal ? skinExtent : size.height,
                        child: c!,
                      ),
                    ],
                  );
                },
                child: child,
              );
          return Stack(
            children: [
              // 稿：24px 网格底（屏幕空间，不随缩放）。
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: CanvasGridPainter(colors.canvasGrid)),
                ),
              ),
              if (lanes.isNotEmpty)
                Positioned.fill(
                  child: laneShifted(
                    IgnorePointer(
                      child: LaneBackground(
                        lanes: lanes,
                        direction: direction,
                        canvasExtent:
                            horizontal ? size.width : size.height,
                        dividerColor: colors.borderSubtle,
                        railFallbackColor: colors.control,
                        collapsedIds: collapsedIds,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: _StagePanCursor(
                  canvasId: canvasId,
                  child: InteractiveViewer(
            transformationController: transformController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(kCanvasBoundaryMargin),
            minScale: kCanvasMinScale,
            maxScale: kCanvasMaxScale,
            // 平移生效：舞台内容（连线命中层 / 卡片 / 边删除钮）整层不收指针，命中落到
            // InteractiveViewer 自己的 opaque 手势层上——拖到卡片上也是拖画布。
            child: _PanGate(
              canvasId: canvasId,
              // 舞台坐标系的锚：拖线时卡片插槽往上找它，把指针的全局坐标换成舞台坐标。
              child: _StageSpace(
              child: SizedBox(
              width: stage.width,
              height: stage.height,
              child: Stack(
                // 分道位移组会把泳道内容平移出舞台矩形，不裁。
                clipBehavior: Clip.none,
                children: [
                  // 连线层（含点击命中）。translucent 让空白处也冒泡。卡片盖着的地方点不到这一层，
                  // 所以这里收到的双击 / 右键就是「空白处」的（_BlankPointerDetector）。
                  Positioned.fill(
                    child: _BlankPointerDetector(
                      onDoubleDown: onBlankDoubleDown,
                      onSecondaryDown: onBlankSecondaryDown,
                      child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: onEdgeLayerTap,
                      // HI-15：连线层独立 layer，节点局部动画不连带边层重绘。
                      // 拖拽位移/自定义连线色在此窄域 watch——每帧只重绘本层。
                      child: RepaintBoundary(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final drag = ref.watch(nodeDragDeltaProvider);
                            final style =
                                ref.watch(canvasStyleControllerProvider);
                            final typo = context.inkTypography;
                            final l = context.l10n;
                            final selectedNodeIds = ref.watch(
                              canvasSelectionControllerProvider(canvasId),
                            );
                            // 连线语义色（画布重设计稿）：叙事 fg4、产出 fg6、首帧 /
                            // 尾帧 / 参考各一色；当前链路仍是用户自定义连线色，没设
                            // 就是 accent。标签胶囊底 = 画布底色。
                            final palette = EdgePalette(
                              narrative: colors.fg4,
                              lineage: colors.fg6,
                              firstFrame: colors.edgeFirstFrame,
                              lastFrame: colors.edgeLastFrame,
                              reference: colors.edgeReference,
                              accent: style.edgeColor ?? colors.accent,
                              chipFill: colors.surface1,
                            );
                            // 锚点吃分道位移（与卡片渲染位置同源），缩放/平移
                            // 实时跟随。
                            return ValueListenableBuilder<Matrix4>(
                              valueListenable: transformController,
                              builder: (context, m, _) => CustomPaint(
                                painter: EdgePainter(
                                  edges: edges,
                                  lineage: lineage,
                                  nodes: displacedNodes(
                                    nodes: visibleNodes,
                                    lanes: laneSlices,
                                    direction: direction,
                                    transform: m,
                                  ),
                                  palette: palette,
                                  labelStyle: typo.micro,
                                  firstFrameLabel: l.inspectorRoleFirstFrame,
                                  lastFrameLabel: l.inspectorRoleLastFrame,
                                  referenceLabel: l.canvasEdgeLabelReference,
                                  direction: direction,
                                  selectedNodeIds: selectedNodeIds,
                                  selectedEdgeId: selectedEdgeId,
                                  dragNodeId: drag?.nodeId,
                                  dragDelta: drag?.delta ?? Offset.zero,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    ),
                  ),
                  // 无道节点：全局变换直出。
                  // HI-13/HI-15：拖拽位移在 NodeCard 内部局部累积，落点一次性
                  // 提交 moveNode；选中/链接态下沉到 _NodeCardSlot 各自 watch，
                  // RepaintBoundary 把拖拽/重绘隔离在本卡片 layer。
                  for (final node in freeNodes)
                    Positioned(
                      key: ValueKey('node-card-${node.id}'),
                      left: node.position.dx + kStageOrigin.dx,
                      top: node.position.dy + kStageOrigin.dy,
                      child: _NodeCardSlot(
                        node: node,
                        canvasId: canvasId,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                        hasInEdge: ports.inbound.contains(node.id),
                        hasOutEdge: ports.outbound.contains(node.id),
                        onTap: () => onNodeTap(node),
                        onWireDrop: onWireDrop,
                        onDelete: () => deleteNodeWithUndo(
                          context,
                          ref,
                          canvasId: canvasId,
                          nodeId: node.id,
                        ),
                      ),
                    ),
                  // 分道位移组：每条泳道一个 Transform.translate——以泳道起始边
                  // 为锚缩放，保证泳道内的卡片缩放/平移时不穿出泳道带。
                  // VLB 的 child 只建一次，缩放帧只更新 Transform（不重建卡片）。
                  // 折叠的道不建卡片（稿：折叠收成 36 轨，道内内容隐藏）。
                  for (final lane in lanes)
                    if (!collapsedIds.contains(lane.id))
                    Positioned.fill(
                      key: ValueKey('lane-group-${lane.id}'),
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: transformController,
                        builder: (context, m, child) {
                          final horizontal =
                              direction == LaneDirection.horizontal;
                          // lane-stack 空间锚定：无平移项（泳道栈随平移整体走）。
                          final d = lanePinDisplacement(
                            laneStart: laneStarts[lane.id]!,
                            scale: scaleOf(m),
                            crossTranslation: 0,
                          );
                          return Transform.translate(
                            offset:
                                horizontal ? Offset(0, d) : Offset(d, 0),
                            child: child,
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final node in nodes)
                              if (node.laneId == lane.id)
                                Positioned(
                                  key: ValueKey('node-card-${node.id}'),
                                  left: node.position.dx + kStageOrigin.dx,
                                  top: node.position.dy + kStageOrigin.dy,
                                  child: _NodeCardSlot(
                                    node: node,
                                    lane: lane,
                                    canvasId: canvasId,
                                    laneSlices: laneSlices,
                                    direction: direction,
                                    transform: transformController,
                                    hasInEdge: ports.inbound.contains(node.id),
                                    hasOutEdge:
                                        ports.outbound.contains(node.id),
                                    onTap: () => onNodeTap(node),
                                    onWireDrop: onWireDrop,
                                    onDelete: () => deleteNodeWithUndo(
                                      context,
                                      ref,
                                      canvasId: canvasId,
                                      nodeId: node.id,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  if (selectedGeometry != null)
                    // 删除按钮锚在连线中点：中点取渲染位置（含分道位移），
                    // 缩放/平移实时跟随。
                    Positioned.fill(
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: transformController,
                        builder: (context, m, _) {
                          final drawn = displacedNodes(
                            nodes: [
                              selectedGeometry.source,
                              selectedGeometry.target,
                            ],
                            lanes: laneSlices,
                            direction: direction,
                            transform: m,
                          );
                          final mid = edgeMidpoint(
                            source: drawn[0],
                            target: drawn[1],
                            direction: direction,
                          );
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: mid.dx - 14,
                                top: mid.dy - 14,
                                child: _EdgeDeleteButton(
                                  onPressed: () => _handleEdgeDelete(
                                    context,
                                    ref,
                                    selectedGeometry.edge,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  // 拖线中的实时虚线：画在卡片之上（拖过别的卡片时线不被压住），不收指针。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _PendingWireLayer(
                        canvasId: canvasId,
                        nodes: visibleNodes,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            ),
                  ),
                ),
              ),
              // 泳道标题栏 + 分界线拖拽条：视口层、随泳道栈同偏移平移。
              // 感应条必须压在标题栏之上——标题栏横跨整条泳道顶部，若反过来
              // 会盖住感应条下半段，边界拖拽十有八九落在标题栏上（宽度调不动）。
              // 平移生效时这一层同样不收指针：拖到标题栏 / 感应条上也是拖画布。
              if (lanes.isNotEmpty)
                Positioned.fill(
                  child: _PanGate(
                    canvasId: canvasId,
                    child: laneShifted(
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._buildLaneTitleBars(
                          context,
                          ref,
                          lanes,
                          laneSlices,
                          nodes,
                          direction,
                          collapsedIds,
                          size,
                        ),
                        if (lanes.length >= 2)
                          ..._buildResizeDividers(
                            context, ref, lanes, laneSlices, direction, collapsedIds, size,
                          ),
                      ],
                    ),
                  ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 为每条泳道生成标题栏 Positioned widget 列表（含拖拽重排 + 折叠）。
  ///
  /// lane-stack 空间（外层已随泳道栈偏移平移）：坐标/尺寸为屏幕像素，
  /// 道 i 起始边恒为 laneStart_i，不随缩放变化。
  List<Widget> _buildLaneTitleBars(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    List<({String id, double size})> laneSlices,
    List<CanvasNode> nodes,
    LaneDirection direction,
    Set<String> collapsedIds,
    Size viewport,
  ) {
    // 稿：标题栏 26px；横向固定 268 宽、左 14 / 道顶 +14；竖向 left = 道左 + 12、top 14、
    // 宽 min(道宽 − 24, 240)（下限 LaneTitleBar.minWidth，窄道时溢出但可命中——BOARD P2-3）。
    // 折叠道（36 轨）里标题栏垂直居中。
    const double kTitleBarHeight = LaneTitleBar.height;
    const double kTitleBarInsetH = 14.0;
    const double kTitleBarInsetV = 12.0;
    const double kTitleBarTop = 14.0;
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: direction == LaneDirection.horizontal
          ? viewport.width
          : viewport.height,
    );
    final counts = <String, int>{};
    for (final n in nodes) {
      if (n.laneId != null) counts[n.laneId!] = (counts[n.laneId!] ?? 0) + 1;
    }
    final result = <Widget>[];
    for (var i = 0; i < lanes.length; i++) {
      final lane = lanes[i];
      final rect = rects[i];
      final bool collapsed = collapsedIds.contains(lane.id);
      final double crossInset = collapsed ? (kCollapsedLaneSize - kTitleBarHeight) / 2 : kTitleBarTop;
      final double left;
      final double top;
      final double? width;
      if (direction == LaneDirection.horizontal) {
        left = kTitleBarInsetH;
        top = rect.top + crossInset;
        width = LaneTitleBar.horizontalWidth;
      } else {
        left = rect.left + kTitleBarInsetV;
        // 竖向道的标题栏钉在视口顶：同样让出浮动工具条那一条，否则居中的工具条一直盖着
        // 中间几条道的标题栏（横向道随泳道栈走，默认相机已让出）。
        top = InkToolbarSize.stageTopInset + crossInset;
        width = (rect.width - kTitleBarInsetV * 2)
            .clamp(LaneTitleBar.minWidth, LaneTitleBar.verticalMaxWidth);
      }
      // 拖拽重排：记录拖拽偏移，pan end 时计算目标 lane 并 reorderLanes。
      var dragOffset = Offset.zero;
      result.add(
        Positioned(
          left: left,
          top: top,
          width: width,
          height: kTitleBarHeight,
          child: GestureDetector(
            onPanUpdate: (d) => dragOffset += d.delta,
            onPanEnd: (_) {
              final moved = dragOffset;
              dragOffset = Offset.zero;
              if (moved.distance < 12) return; // 阈值：避免误触重排
              final dropPoint = direction == LaneDirection.horizontal
                  ? Offset(0, rect.top + kTitleBarHeight / 2 + moved.dy)
                  : Offset(rect.left + rect.width / 2 + moved.dx, 0);
              final targetId = laneIdAtPoint(
                point: dropPoint,
                lanes: laneSlices,
                direction: direction,
              );
              final ids = reorderedLaneIds(
                [for (final l in lanes) l.id],
                lane.id,
                targetId,
              );
              ref
                  .read(canvasLanesControllerProvider(canvasId).notifier)
                  .reorderLanes(ids);
            },
            child: LaneTitleBar(
              lane: lane,
              nodeCount: counts[lane.id] ?? 0,
              collapsed: collapsed,
              onToggleCollapse: () => ref
                  .read(laneCollapseProvider(canvasId).notifier)
                  .toggle(lane.id),
              onEdit: () => _onEditLane(context, ref, lane),
              onDelete: () => _onDeleteLane(context, ref, lane),
            ),
          ),
        ),
      );
    }
    return result;
  }

  // 拖拽分界线调整相邻泳道大小（~10px 透明感应条，仅命中不绘制）。
  // 视口层：厚度恒为屏幕像素；位置随泳道栈平移（laneStackOffset），缩放不改道厚。
  List<Widget> _buildResizeDividers(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    List<({String id, double size})> laneSlices,
    LaneDirection direction,
    Set<String> collapsedIds,
    Size viewport,
  ) {
    const double kStripThick = 10.0;
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: direction == LaneDirection.horizontal
          ? viewport.width
          : viewport.height,
    );
    final horizontal = direction == LaneDirection.horizontal;
    final result = <Widget>[];
    // 相邻泳道之间各一条感应条，以 upper lane id 为键。
    for (var i = 1; i < lanes.length; i++) {
      final upperLane = lanes[i - 1];
      // 折叠的道厚度是定值，不给拖。
      if (collapsedIds.contains(upperLane.id)) continue;
      final dividerPos = horizontal ? rects[i].top : rects[i].left;
      final upperLaneId = upperLane.id;
      final double currentSize = upperLane.size;
      double delta = 0;

      // 手势回调内 fire-and-forget：控制器失败时已回滚内存态，这里补用户提示。
      Future<void> commit() async {
        final newSize = clampLaneSize(currentSize, delta);
        delta = 0;
        try {
          await ref
              .read(canvasLanesControllerProvider(canvasId).notifier)
              .updateLane(upperLaneId, size: newSize);
        } on InkError catch (_) {
          if (context.mounted) {
            showCanvasSnack(context, context.l10n.laneUpdateFailed);
          }
        }
      }

      result.add(
        Positioned(
          left: horizontal ? 0 : dividerPos - kStripThick / 2,
          top: horizontal ? dividerPos - kStripThick / 2 : 0,
          width: horizontal ? viewport.width : kStripThick,
          height: horizontal ? kStripThick : viewport.height,
          child: MouseRegion(
            cursor: horizontal
                ? SystemMouseCursors.resizeRow
                : SystemMouseCursors.resizeColumn,
            // translucent：感应条自身收 pan（层序在标题栏之上，#184），
            // 同时不吞掉带下内容的命中——10px 带内连线/卡片仍可点选。
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => delta += horizontal ? d.delta.dy : d.delta.dx,
              onPanEnd: (_) => commit(),
            ),
          ),
        ),
      );
    }
    return result;
  }

  Future<void> _onEditLane(
    BuildContext context,
    WidgetRef ref,
    StyleLane lane,
  ) async {
    final r = await showLaneEditDialog(context, existing: lane);
    if (r == null) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(canvasLanesControllerProvider(canvasId).notifier)
          .updateLane(
            lane.id,
            label: r.label,
            stylePrompt: r.stylePrompt,
            tintColor: r.tintColor,
            clearTint: r.tintColor == null,
          );
    } on InkError catch (_) {
      if (context.mounted) {
        showCanvasSnack(context, context.l10n.laneUpdateFailed);
      }
    }
  }

  Future<void> _onDeleteLane(
    BuildContext context,
    WidgetRef ref,
    StyleLane lane,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.laneDeleteConfirmTitle),
          content: Text(l10n.laneDeleteConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.laneDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.laneDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(canvasLanesControllerProvider(canvasId).notifier)
          .deleteLane(lane.id);
    } on InkError catch (_) {
      if (context.mounted) {
        showCanvasSnack(context, context.l10n.laneDeleteFailed);
      }
    }
  }
}

/// 在 [edges]/[nodes] 中定位选中边及其端点节点；任一缺失返回 null。
({CanvasEdge edge, CanvasNode source, CanvasNode target})?
_selectedEdgeGeometry({
  required String? selectedEdgeId,
  required List<CanvasEdge> edges,
  required List<CanvasNode> nodes,
}) {
  if (selectedEdgeId == null) return null;
  CanvasEdge? edge;
  for (final e in edges) {
    if (e.id == selectedEdgeId) {
      edge = e;
      break;
    }
  }
  if (edge == null) return null;
  CanvasNode? source;
  CanvasNode? target;
  for (final n in nodes) {
    if (n.id == edge.sourceNodeId) source = n;
    if (n.id == edge.targetNodeId) target = n;
  }
  if (source == null || target == null) return null;
  return (edge: edge, source: source, target: target);
}

/// 单个节点卡片插槽：各自 watch 自己的选中/链接态——改选中只重建涉及的卡片，
/// 不连带整个舞台层（丝滑核心）。端口占用（[hasInEdge] / [hasOutEdge]）由舞台层
/// 按存量边 + 产出线整层算一次传进来。
///
/// 出端口拖线也从这里报：指针的全局坐标换成舞台坐标写进 canvasWireDragProvider，松手时把这条拖线
/// 交给舞台层（[onWireDrop]）判落点。
class _NodeCardSlot extends ConsumerWidget {
  const _NodeCardSlot({
    required this.node,
    this.lane,
    required this.canvasId,
    required this.laneSlices,
    required this.direction,
    required this.transform,
    required this.hasInEdge,
    required this.hasOutEdge,
    required this.onTap,
    required this.onDelete,
    required this.onWireDrop,
  });

  final CanvasNode node;
  /// 所在泳道（稿：卡片底部「继承 X」行）；无道节点为 null。
  final StyleLane? lane;
  final String canvasId;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;

  /// 画布世界→屏幕变换：泳道钉在视口层（屏幕坐标），落点归属须换算后判定。
  final TransformationController transform;

  /// 入口 / 出口这一侧真挂着画出来的线——端口常驻（见 NodeCard 头注）。
  final bool hasInEdge;
  final bool hasOutEdge;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// 从本卡出端口拖线后松手：舞台层判落点（连线 / 开新建菜单 / 什么都不做）。
  final void Function(WireDrag drag) onWireDrop;

  /// 指针全局坐标 → 舞台坐标：沿渲染树往上找舞台坐标系的锚（[_StageSpace]）。卡片可能在分道位移组
  /// 里，位移组在锚之下，所以换出来的是舞台坐标（与 displacedNodes 同一个坐标系），不是道内坐标。
  static Offset? _toStage(BuildContext context, Offset global) => context
      .findAncestorRenderObjectOfType<_RenderStageSpace>()
      ?.globalToLocal(global);

  PortDragCallbacks _portDrag(BuildContext context, WidgetRef ref) {
    WireDragController wire() =>
        ref.read(canvasWireDragProvider(canvasId).notifier);
    return PortDragCallbacks(
      onStart: (Offset global) {
        // 平移生效时舞台内容整层不收指针（_PanGate），端口本来就按不到；这里再拦一道，
        // 「平移时端口不可拖」不只靠那一层闸。
        if (ref.read(canvasPanActiveProvider(canvasId))) return;
        final Offset? stage = _toStage(context, global);
        if (stage != null) wire().start(node.id, stage);
      },
      onUpdate: (Offset global) {
        final Offset? stage = _toStage(context, global);
        if (stage != null) wire().moveTo(node.id, stage);
      },
      onEnd: () {
        // 已被 Esc 取消（或根本没开始）的拖线，finish 交回 null：松手什么都不做。
        final WireDrag? drag = wire().finish(node.id);
        if (drag != null) onWireDrop(drag);
      },
      onCancel: () {
        wire().finish(node.id);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select：仅当本节点的"是否被选中"翻转时才重建本卡片。
    final selected = ref.watch(
      canvasSelectionControllerProvider(canvasId).select((s) => s.contains(node.id)),
    );
    final linkSourceId = ref.watch(linkModeControllerProvider(canvasId));
    // 拖线的源：.select 掉指针位置——只在拖线开始 / 结束那一下翻转，指针每动一下不重建卡片。
    final String? wireSourceId = ref.watch(
      canvasWireDragProvider(canvasId).select((WireDrag? d) => d?.sourceNodeId),
    );
    // 拖线期间的高亮与连线模式同一套样式：源卡片 = 起点，其余卡片 = 可连的目标。
    final String? activeSourceId = linkSourceId ?? wireSourceId;
    return RepaintBoundary(
      child: NodeCard(
        node: node,
        lane: lane,
        selected: selected,
        onTap: onTap,
        onDragEnd: (totalDelta) {
          // 泳道钉死模型：落点中心先经"原道锚定"映射到屏幕坐标判归属，
          // 再按"新道锚定"逆映射回世界坐标——保证换道落点视觉位置不变。
          // 判定本体在 util/drop_placement.dart（resolveLaneDrop），新建菜单的落点调的是同一个函数。
          final horizontal = direction == LaneDirection.horizontal;
          final center =
              node.position +
              totalDelta +
              Offset(kNodeCardSize.width / 2, kNodeCardSize.height / 2);
          final crossWorld = horizontal ? center.dy : center.dx;
          final drop = resolveLaneDrop(
            centerCrossWorld: crossWorld,
            fromLaneId: node.laneId,
            laneSlices: laneSlices,
            direction: direction,
            scale: scaleOf(transform.value),
          );
          final laneId = drop.laneId;
          final newCrossWorld = drop.crossWorld;
          final adjustedDelta = horizontal
              ? Offset(totalDelta.dx, totalDelta.dy + newCrossWorld - crossWorld)
              : Offset(
                  totalDelta.dx + newCrossWorld - crossWorld, totalDelta.dy);
          // 手势回调内 fire-and-forget：控制器失败时已回滚内存态，补用户提示。
          Future<void> move() async {
            try {
              await ref
                  .read(canvasNodesControllerProvider(canvasId).notifier)
                  .moveNode(node.id, adjustedDelta, laneId: laneId);
            } on InkError catch (_) {
              if (context.mounted) {
                showCanvasSnack(context, context.l10n.nodeMoveFailed);
              }
            }
          }

          move();
        },
        onStartLink: () =>
            ref.read(linkModeControllerProvider(canvasId).notifier).start(node.id),
        onDelete: onDelete,
        isLinkSource: activeSourceId == node.id,
        isLinkCandidate: activeSourceId != null && activeSourceId != node.id,
        hasInEdge: hasInEdge,
        hasOutEdge: hasOutEdge,
        portDrag: _portDrag(context, ref),
      ),
    );
  }
}

/// 画布元数据（边/泳道/泳道方向）加载失败横幅插槽：非阻塞——节点已在
/// _CanvasStage 用 valueOrNull 降级照常渲染，这里仅补一条可忽略的错误横幅
/// 解释失败原因（此前静默吞错）。GAP-3 余量：方向读失败此前完全无提示；
/// lane_toolbar 会基于错误基线 horizontal 翻转写库（二元域下写入值仍在
/// 存量/意图之内,无损毁,但错误期 toggle 永远到不了 horizontal——置灰记债）。
class _EdgeLaneErrorSlot extends ConsumerStatefulWidget {
  const _EdgeLaneErrorSlot({required this.canvasId});

  final String canvasId;

  @override
  ConsumerState<_EdgeLaneErrorSlot> createState() => _EdgeLaneErrorSlotState();
}

class _EdgeLaneErrorSlotState extends ConsumerState<_EdgeLaneErrorSlot> {
  /// 每个错误源各记一条「已被用户忽略的那个错误对象」，顺序同 [_errorsOf]。
  ///
  /// 【为什么不能是一个字段】三个源会同时有错。原来是单个 `_dismissed` 配上
  /// `edgesError ?? lanesError ?? directionError`：关掉 edges 的错之后，只要它
  /// 还没恢复，`??` 链就一直短路在它身上，而它恰好 `identical` 于 `_dismissed`
  /// ⇒ 这期间并发出现的 lanes / direction 错**永远上不了屏**。按源分别记账、
  /// 取第一个「有错且未被忽略」的，才是三个源各自独立的语义。
  ///
  /// 定长三格而不是不断增长的集合：忽略只对「当下这个错误对象」生效，源一恢复
  /// 旧对象就再也不会出现，留着只是攒垃圾。
  final List<Object?> _dismissed = <Object?>[null, null, null];

  List<Object?> _errorsOf(WidgetRef ref) => <Object?>[
        ref.watch(canvasEdgesControllerProvider(widget.canvasId)).error,
        ref.watch(canvasLanesControllerProvider(widget.canvasId)).error,
        ref.watch(canvasLaneDirectionProvider(widget.canvasId)).error,
      ];

  @override
  Widget build(BuildContext context) {
    final List<Object?> errors = _errorsOf(ref);
    int? at;
    for (var i = 0; i < errors.length; i++) {
      final Object? e = errors[i];
      if (e != null && !identical(e, _dismissed[i])) {
        at = i;
        break;
      }
    }
    if (at == null) return const SizedBox.shrink();
    final int source = at;
    final Object error = errors[source]!;
    final colors = context.inkColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkErrorBanner(message: l10nAsyncError(context, error)),
        ),
        const SizedBox(width: InkSpacing.xs),
        IconButton(
          tooltip: context.l10n.commonClose,
          icon: Icon(Icons.close, size: InkSpacing.md, color: colors.danger),
          onPressed: () => setState(() => _dismissed[source] = error),
        ),
      ],
    );
  }
}

/// 链接提示条插槽：仅随 linkMode 变化重建。
class _LinkHintSlot extends ConsumerWidget {
  const _LinkHintSlot({required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(linkModeControllerProvider(canvasId)) != null;
    return active ? _LinkHintBanner() : const SizedBox.shrink();
  }
}

/// 多选计数 chip 插槽：仅随选中数量变化重建。
class _SelectionCountSlot extends ConsumerWidget {
  const _SelectionCountSlot({required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      canvasSelectionControllerProvider(canvasId).select((s) => s.length),
    );
    if (count < 2) return const SizedBox.shrink();
    return _SelectionCountChip(count: count);
  }
}

/// 平移闸：平移生效（工具 = 平移，或按住空格）时 [child] 整层不收指针。
///
/// IgnorePointer 恒在树上、只拨 ignoring——平移开关一拨就增删包装层的话，舞台整棵子树
/// 会被卸载重挂。watch 收在这一小层：开关只重建它自己，[child] 是上游传进来的同一个
/// 实例，舞台不跟着重建。
class _PanGate extends ConsumerWidget {
  const _PanGate({required this.canvasId, required this.child});

  final String canvasId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IgnorePointer(
        ignoring: ref.watch(canvasPanActiveProvider(canvasId)),
        child: child,
      );
}

/// 平移时的手形光标：平移生效 = grab，按住拖动中 = grabbing；不在平移时 defer
/// （交给卡片 / 分界线自己的光标）。理由同 [_PanGate]：MouseRegion / Listener 恒在树上，
/// 只换参数。平移时卡片与标题栏都被 [_PanGate] 挡掉命中，它们的光标不会盖过这里。
class _StagePanCursor extends ConsumerStatefulWidget {
  const _StagePanCursor({required this.canvasId, required this.child});

  final String canvasId;
  final Widget child;

  @override
  ConsumerState<_StagePanCursor> createState() => _StagePanCursorState();
}

class _StagePanCursorState extends ConsumerState<_StagePanCursor> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool panning = ref.watch(canvasPanActiveProvider(widget.canvasId));
    final MouseCursor cursor = !panning
        ? MouseCursor.defer
        : (_pressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab);
    return Listener(
      onPointerDown: (_) {
        _setPressed(true);
        CanvasShortcuts.reclaimFocus(context);
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: MouseRegion(cursor: cursor, child: widget.child),
    );
  }
}

/// 舞台坐标系的锚：拖线时卡片插槽沿渲染树往上找它，把指针的全局坐标换成舞台坐标
/// （globalToLocal 把 InteractiveViewer 的相机一并逆掉）。本身只透传：不画、不改布局、不改命中。
class _StageSpace extends SingleChildRenderObjectWidget {
  const _StageSpace({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStageSpace();
}

class _RenderStageSpace extends RenderProxyBox {}

/// 空白处的双击与右键：包在连线层上——卡片盖着的地方到不了这一层，收到的就是空白处的指针。
///
/// 不用 GestureDetector 的 onDoubleTap：双击识别器一进手势竞技场，连线层原来的单击（选连线 / 点空白
/// 清选中）就得等它放弃，每一次单击都慢 300ms。这里只听按下事件、自己数两下：第二下在
/// [kDoubleTapTimeout] 之内、[kDoubleTapSlop] 之内落下就算双击；不进竞技场，单击照旧即时生效。
/// 右键（次键按下）直接报。回调给的是本层的局部坐标 = 舞台坐标。
class _BlankPointerDetector extends StatefulWidget {
  const _BlankPointerDetector({
    required this.onDoubleDown,
    required this.onSecondaryDown,
    required this.child,
  });

  final ValueChanged<Offset> onDoubleDown;
  final ValueChanged<Offset> onSecondaryDown;
  final Widget child;

  @override
  State<_BlankPointerDetector> createState() => _BlankPointerDetectorState();
}

class _BlankPointerDetectorState extends State<_BlankPointerDetector> {
  /// 上一下主键按下的全局位置；双击窗口一过就清掉。
  Offset? _firstDown;
  Timer? _window;

  @override
  void dispose() {
    _window?.cancel();
    super.dispose();
  }

  void _reset() {
    _window?.cancel();
    _window = null;
    _firstDown = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryButton) {
      _reset();
      widget.onSecondaryDown(event.localPosition);
      return;
    }
    if (event.buttons != kPrimaryButton) return;
    final Offset? first = _firstDown;
    if (first != null && (event.position - first).distance <= kDoubleTapSlop) {
      _reset();
      widget.onDoubleDown(event.localPosition);
      return;
    }
    _window?.cancel();
    _firstDown = event.position;
    _window = Timer(kDoubleTapTimeout, _reset);
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerDown: _onPointerDown, child: widget.child);
}

/// 拖线中的实时虚线（从源卡片的出点到指针）：只随拖线状态与相机重建，不连带舞台；不在拖线时什么都不画。
class _PendingWireLayer extends ConsumerWidget {
  const _PendingWireLayer({
    required this.canvasId,
    required this.nodes,
    required this.laneSlices,
    required this.direction,
    required this.transform,
  });

  final String canvasId;

  /// 可见节点（折叠道里的不在内）：源卡片画在哪，线就从哪出。
  final List<CanvasNode> nodes;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final TransformationController transform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WireDrag? drag = ref.watch(canvasWireDragProvider(canvasId));
    if (drag == null) return const SizedBox.shrink();
    CanvasNode? source;
    for (final CanvasNode n in nodes) {
      if (n.id == drag.sourceNodeId) source = n;
    }
    final CanvasNode? from = source;
    if (from == null) return const SizedBox.shrink();
    final Color color = context.inkColors.accent;
    // 出点吃分道位移（与卡片渲染位置同源），缩放时跟着走。
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transform,
      builder: (BuildContext context, Matrix4 m, Widget? _) => CustomPaint(
        painter: PendingWirePainter(
          source: displacedNodes(
            nodes: <CanvasNode>[from],
            lanes: laneSlices,
            direction: direction,
            transform: m,
          ).single,
          to: drag.pointer,
          color: color,
          direction: direction,
        ),
      ),
    );
  }
}
