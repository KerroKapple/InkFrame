// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责切分（HI-18）：
//   - _CanvasBody：状态装配 + 节点 tap 语义 + 连线事件 → snackbar 副作用（ref.listen）
//   - _CanvasStage：InteractiveViewer 舞台（连线层 / 节点卡片 / 边删除按钮）
//   - 可播放性 IO 判定在 playableVideoPathProvider；连线编排在 LinkActionController

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_bootstrap_controller.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/current_canvas_id.dart';
import '../providers/link_action_controller.dart';
import '../providers/link_mode_controller.dart';
import '../providers/playable_video_path.dart';
import '../providers/selected_edge_controller.dart';
import '../util/edge_hit_test.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../util/lane_geometry.dart';
import 'canvas_empty_state.dart';
import 'edge_painter.dart';
import 'lane_background.dart';
import 'lane_edit_dialog.dart';
import 'lane_title_bar.dart';
import 'lane_toolbar.dart';
import 'node_card.dart';
import 'node_inspector_router.dart';
import 'video_lightbox.dart';

const _kSnackBarDuration = Duration(seconds: 2);

// 删除防误伤（PL-4a）：Deleted · [Undo] 的驻留时长即撤销窗口（~5s）。
const _kUndoSnackBarDuration = Duration(seconds: 5);

// InteractiveViewer 平移越界余量（画布外延展空间，非视觉 token）
const double kCanvasBoundaryMargin = 2000;

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(text), duration: _kSnackBarDuration),
  );
}

/// 删除防误伤（PL-4a）：弹一条带 Undo 动作的 snackbar，[onUndo] 在窗口内点击时
/// 触发复原；窗口内不点 → snackbar 自行消失，软删生效。
void _showUndoSnack(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final colors = context.inkColors;
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _kUndoSnackBarDuration,
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          textColor: colors.accent,
          onPressed: onUndo,
        ),
      ),
    );
}

class CanvasView extends ConsumerWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    final colors = context.inkColors;
    if (canvasId == null) {
      return _NoCanvasOpen(colors: colors);
    }

    final nodesAsync = ref.watch(canvasNodesControllerProvider(canvasId));
    return nodesAsync.when(
      loading: () => Container(
        color: colors.surface1,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _LoadError(message: err.toString()),
      data: (nodes) => _CanvasBody(canvasId: canvasId, nodes: nodes),
    );
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
              style: typo.caption.copyWith(color: colors.fg1),
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
            Icon(Icons.link, size: 16, color: colors.brand),
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

class _NoCanvasOpen extends ConsumerWidget {
  const _NoCanvasOpen({required this.colors});
  final InkColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typo = context.inkTypography;
    return Container(
      color: colors.surface1,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.canvasNoCanvasOpen,
              style: typo.body.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.md),
            FilledButton(
              onPressed: () async {
                final bootstrap =
                    ref.read(canvasBootstrapControllerProvider);
                await bootstrap.createSample(
                  projectName: context.l10n.canvasSampleProjectName,
                  canvasName: context.l10n.canvasSampleCanvasName,
                );
              },
              child: Text(context.l10n.canvasCreateSampleCanvas),
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
              style: typo.caption.copyWith(color: colors.fg3),
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

  /// 连线结果事件 → snackbar 映射（ME-08：duplicate / failed 分流）。
  void _onLinkEvent(BuildContext context, LinkActionEvent? event) {
    if (event == null) return;
    final l10n = context.l10n;
    final text = switch (event.result) {
      LinkActionResult.created => l10n.linkCreated,
      LinkActionResult.selfLinkRejected => l10n.linkSelfNotAllowed,
      LinkActionResult.duplicate => l10n.linkAlreadyExists,
      LinkActionResult.failed => l10n.linkCreateFailed,
    };
    _showSnack(context, text);
  }

  Future<void> _handleNodeTap(
    BuildContext context,
    WidgetRef ref,
    CanvasNode node,
  ) async {
    // link 模式：编排交给 LinkActionController，结果经 ref.listen 出 snackbar。
    if (ref.read(linkModeControllerProvider) != null) {
      await ref
          .read(linkActionControllerProvider(canvasId).notifier)
          .linkTo(node.id);
      return;
    }

    final selectionCtrl = ref.read(canvasSelectionControllerProvider.notifier);

    // 可播放 video result → 打开 Lightbox，不走常规多选。
    final playablePath = ref.read(playableVideoPathProvider(node));
    if (playablePath != null) {
      selectionCtrl.select(node.id);
      await showVideoLightbox(context, videoPath: playablePath);
      return;
    }

    final keyboard = HardwareKeyboard.instance;
    final modifierHeld = keyboard.isShiftPressed ||
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
      if (ref.read(linkModeControllerProvider) != null) {
        ref.read(linkModeControllerProvider.notifier).cancel();
      }
      ref.read(canvasSelectionControllerProvider.notifier).clear();
      ref.read(selectedEdgeControllerProvider.notifier).clear();
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

    final Widget leftArea = Stack(
      children: [
        Positioned.fill(child: canvasArea),
        // 边/泳道加载失败 → 非阻塞横幅（节点照常渲染），可忽略。
        Positioned(
          top: InkSpacing.md,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: _EdgeLaneErrorSlot(canvasId: canvasId),
        ),
        // 链接提示条：仅随 linkMode 重建。
        const Positioned(
          top: InkSpacing.md,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: _LinkHintSlot(),
        ),
        // 多选计数 chip：仅随选中数量重建。
        const Positioned(
          top: InkSpacing.md,
          right: InkSpacing.md,
          child: _SelectionCountSlot(),
        ),
        // 泳道工具栏：左下角固定，位于链接提示条之下。
        Positioned(
          bottom: InkSpacing.md,
          left: InkSpacing.md,
          child: LaneToolbar(canvasId: canvasId),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(child: leftArea),
        // Inspector：单选 config 节点时浮出，仅随选中态重建。
        _InspectorSlot(nodes: nodes),
      ],
    );
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

  Future<void> _handleNodeDelete(
    BuildContext context,
    WidgetRef ref,
    String nodeId,
  ) async {
    ref.read(canvasSelectionControllerProvider.notifier).removed(nodeId);
    final nodesCtrl =
        ref.read(canvasNodesControllerProvider(canvasId).notifier);
    try {
      final deletion = await nodesCtrl.removeNode(nodeId);
      if (!context.mounted) return;
      if (deletion == null) {
        _showSnack(context, context.l10n.nodeDeleted);
        return;
      }
      _showUndoSnack(
        context,
        message: context.l10n.nodeDeleted,
        onUndo: () => _restoreNode(context, nodesCtrl, deletion),
      );
    } on InkError catch (_) {
      if (context.mounted) {
        _showSnack(context, context.l10n.nodeDeleteFailed);
      }
    }
  }

  Future<void> _restoreNode(
    BuildContext context,
    CanvasNodesController ctrl,
    NodeDeletion deletion,
  ) async {
    try {
      await ctrl.restore(deletion);
    } on InkError catch (_) {
      if (context.mounted) _showSnack(context, context.l10n.undoFailed);
    }
  }

  Future<void> _handleEdgeDelete(
    BuildContext context,
    WidgetRef ref,
    CanvasEdge edge,
  ) async {
    ref.read(selectedEdgeControllerProvider.notifier).clear();
    final edgesCtrl =
        ref.read(canvasEdgesControllerProvider(canvasId).notifier);
    try {
      final removed = await edgesCtrl.removeEdge(edge.id);
      if (removed == null || !context.mounted) return;
      _showUndoSnack(
        context,
        message: context.l10n.edgeDeleted,
        onUndo: () => _restoreEdge(context, edgesCtrl, removed),
      );
    } on InkError catch (_) {
      // 删失败：EdgesController 已回滚内存，SelectedEdge 已清，用户可重试。
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
      if (context.mounted) _showSnack(context, context.l10n.undoFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    // 选中/链接态不在本层 watch——下沉到 _NodeCardSlot 各自 watch，改选中
    // 只重建涉及的卡片，不再整层重建（丝滑核心）。
    final selectedEdgeId = ref.watch(selectedEdgeControllerProvider);
    final edges = ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    // 泳道数据。
    final lanes = ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ?? const <StyleLane>[];
    final direction = ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ?? LaneDirection.horizontal;
    // 折叠态（纯 UI，不持久化）。
    final collapsedIds = ref.watch(laneCollapseProvider(canvasId));
    // 拖拽落点 → 泳道归属用的切片，整层算一次复用给各卡片插槽。
    final laneSlices = [for (final l in lanes) (id: l.id, size: l.size)];

    void onEdgeLayerTap(TapDownDetails d) {
      final hitId = hitTestEdge(
        point: d.localPosition,
        edges: edges,
        nodes: nodes,
      );
      if (hitId != null) {
        ref.read(selectedEdgeControllerProvider.notifier).select(hitId);
        return;
      }
      onEmptyTap();
    }

    final selectedGeometry = _selectedEdgeGeometry(
      selectedEdgeId: selectedEdgeId,
      edges: edges,
      nodes: nodes,
    );

    return Container(
      color: colors.surface1,
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(kCanvasBoundaryMargin),
        minScale: 0.1,
        maxScale: 3.0,
        child: SizedBox(
          width: 4000,
          height: 4000,
          child: Stack(
            children: [
              // 泳道背景层：最底部，不拦截事件。
              if (lanes.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: LaneBackground(
                      lanes: lanes,
                      direction: direction,
                      canvasExtent: 4000,
                      dividerColor: colors.borderSubtle,
                      collapsedIds: collapsedIds,
                    ),
                  ),
                ),
              // 连线层（含点击命中）。translucent 让空白处也冒泡。
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: onEdgeLayerTap,
                  // HI-15：连线层独立 layer，节点局部动画不连带边层重绘。
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: EdgePainter(
                        edges: edges,
                        nodes: nodes,
                        dataColor: colors.accent,
                        narrativeColor: colors.fg3,
                        generationSourceColor: colors.fg3,
                        selectedColor: colors.brand,
                        selectedEdgeId: selectedEdgeId,
                      ),
                    ),
                  ),
                ),
              ),
              // 泳道分界线拖拽条：置于节点层之下——节点手势优先；strip 用
              // translucent，空白分界线处可拖、点击穿透到连线层（HI-1 fix）。
              if (lanes.length >= 2)
                ..._buildResizeDividers(context, ref, lanes, direction),
              for (final node in nodes)
                Positioned(
                  key: ValueKey('node-card-${node.id}'),
                  left: node.position.dx,
                  top: node.position.dy,
                  // HI-13/HI-15：拖拽位移在 NodeCard 内部局部累积，落点一次性
                  // 提交 moveNode；选中/链接态下沉到 _NodeCardSlot 各自 watch，
                  // RepaintBoundary 把拖拽/重绘隔离在本卡片 layer。
                  child: _NodeCardSlot(
                    node: node,
                    canvasId: canvasId,
                    laneSlices: laneSlices,
                    direction: direction,
                    onTap: () => onNodeTap(node),
                    onDelete: () => _handleNodeDelete(context, ref, node.id),
                  ),
                ),
              // 泳道标题栏：节点层之上，边删除按钮之下。
              if (lanes.isNotEmpty)
                ..._buildLaneTitleBars(context, ref, lanes, direction, collapsedIds),
              if (selectedGeometry != null)
                Positioned(
                  left: edgeMidpoint(
                        source: selectedGeometry.source,
                        target: selectedGeometry.target,
                      ).dx -
                      14,
                  top: edgeMidpoint(
                        source: selectedGeometry.source,
                        target: selectedGeometry.target,
                      ).dy -
                      14,
                  child: _EdgeDeleteButton(
                    onPressed: () =>
                        _handleEdgeDelete(context, ref, selectedGeometry.edge),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 为每条泳道生成标题栏 Positioned widget 列表（含拖拽重排 + 折叠）。
  List<Widget> _buildLaneTitleBars(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    LaneDirection direction,
    Set<String> collapsedIds,
  ) {
    const double kTitleBarHeight = 32.0;
    const double kTitleBarWidth = 200.0;
    final laneSlices = [for (final l in lanes) (id: l.id, size: l.size)];
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: 4000,
    );
    final result = <Widget>[];
    for (var i = 0; i < lanes.length; i++) {
      final lane = lanes[i];
      final rect = rects[i];
      final double left;
      final double top;
      final double? width;
      if (direction == LaneDirection.horizontal) {
        left = 0;
        top = rect.top;
        width = 4000;
      } else {
        left = rect.left;
        top = 0;
        width = kTitleBarWidth;
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
                  : Offset(rect.left + kTitleBarWidth / 2 + moved.dx, 0);
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
              collapsed: collapsedIds.contains(lane.id),
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
  List<Widget> _buildResizeDividers(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    LaneDirection direction,
  ) {
    const double kStripThick = 10.0;
    final laneSlices = [for (final l in lanes) (id: l.id, size: l.size)];
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: 4000,
    );
    final horizontal = direction == LaneDirection.horizontal;
    final result = <Widget>[];
    // 相邻泳道之间各一条感应条，以 upper lane id 为键。
    for (var i = 1; i < lanes.length; i++) {
      final upperLane = lanes[i - 1];
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
            _showSnack(context, context.l10n.laneUpdateFailed);
          }
        }
      }

      result.add(
        Positioned(
          left: horizontal ? 0 : dividerPos - kStripThick / 2,
          top: horizontal ? dividerPos - kStripThick / 2 : 0,
          width: horizontal ? 4000 : kStripThick,
          height: horizontal ? kStripThick : 4000,
          child: MouseRegion(
            cursor: horizontal
                ? SystemMouseCursors.resizeRow
                : SystemMouseCursors.resizeColumn,
            // translucent：strip 接收拖拽，但 tap 等穿透到下方连线层。
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) =>
                  delta += horizontal ? d.delta.dy : d.delta.dx,
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
        _showSnack(context, context.l10n.laneUpdateFailed);
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
        _showSnack(context, context.l10n.laneDeleteFailed);
      }
    }
  }
}

/// 在 [edges]/[nodes] 中定位选中边及其端点节点；任一缺失返回 null。
({CanvasEdge edge, CanvasNode source, CanvasNode target})? _selectedEdgeGeometry({
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
/// 不连带整个舞台层（丝滑核心）。NodeCard 公共 API 不变。
class _NodeCardSlot extends ConsumerWidget {
  const _NodeCardSlot({
    required this.node,
    required this.canvasId,
    required this.laneSlices,
    required this.direction,
    required this.onTap,
    required this.onDelete,
  });

  final CanvasNode node;
  final String canvasId;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select：仅当本节点的"是否被选中"翻转时才重建本卡片。
    final selected = ref.watch(
      canvasSelectionControllerProvider.select((s) => s.contains(node.id)),
    );
    final linkSourceId = ref.watch(linkModeControllerProvider);
    return RepaintBoundary(
      child: NodeCard(
        node: node,
        selected: selected,
        onTap: onTap,
        onDragEnd: (totalDelta) {
          // 拖拽落点中心 → 计算归属泳道，一并传给 moveNode。
          final center = node.position +
              totalDelta +
              Offset(node.size.width / 2, node.size.height / 2);
          final laneId = laneIdAtPoint(
            point: center,
            lanes: laneSlices,
            direction: direction,
          );
          // 手势回调内 fire-and-forget：控制器失败时已回滚内存态，补用户提示。
          Future<void> move() async {
            try {
              await ref
                  .read(canvasNodesControllerProvider(canvasId).notifier)
                  .moveNode(node.id, totalDelta, laneId: laneId);
            } on InkError catch (_) {
              if (context.mounted) {
                _showSnack(context, context.l10n.nodeMoveFailed);
              }
            }
          }

          move();
        },
        onStartLink: () =>
            ref.read(linkModeControllerProvider.notifier).start(node.id),
        onDelete: onDelete,
        isLinkSource: linkSourceId == node.id,
        isLinkCandidate: linkSourceId != null && linkSourceId != node.id,
      ),
    );
  }
}

/// 边/泳道加载失败横幅插槽：非阻塞——节点已在 _CanvasStage 用 valueOrNull 降级
/// 照常渲染，这里仅补一条可忽略的错误横幅解释失败原因（此前静默吞错）。
class _EdgeLaneErrorSlot extends ConsumerStatefulWidget {
  const _EdgeLaneErrorSlot({required this.canvasId});

  final String canvasId;

  @override
  ConsumerState<_EdgeLaneErrorSlot> createState() => _EdgeLaneErrorSlotState();
}

class _EdgeLaneErrorSlotState extends ConsumerState<_EdgeLaneErrorSlot> {
  // 已被用户忽略的错误对象；仅当出现新错误时横幅重新弹出。
  Object? _dismissed;

  @override
  Widget build(BuildContext context) {
    final edgesError =
        ref.watch(canvasEdgesControllerProvider(widget.canvasId)).error;
    final lanesError =
        ref.watch(canvasLanesControllerProvider(widget.canvasId)).error;
    final error = edgesError ?? lanesError;
    if (error == null || identical(error, _dismissed)) {
      return const SizedBox.shrink();
    }
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
          onPressed: () => setState(() => _dismissed = error),
        ),
      ],
    );
  }
}

/// 链接提示条插槽：仅随 linkMode 变化重建。
class _LinkHintSlot extends ConsumerWidget {
  const _LinkHintSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(linkModeControllerProvider) != null;
    return active ? _LinkHintBanner() : const SizedBox.shrink();
  }
}

/// 多选计数 chip 插槽：仅随选中数量变化重建。
class _SelectionCountSlot extends ConsumerWidget {
  const _SelectionCountSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      canvasSelectionControllerProvider.select((s) => s.length),
    );
    if (count < 2) return const SizedBox.shrink();
    return _SelectionCountChip(count: count);
  }
}

/// Inspector 插槽：单选节点时浮出（config/result 分流交 NodeInspectorRouter）；
/// 仅随选中态重建，不连带画布。
class _InspectorSlot extends ConsumerWidget {
  const _InspectorSlot({required this.nodes});

  final List<CanvasNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(canvasSelectionControllerProvider);
    CanvasNode? target;
    if (selected.length == 1) {
      final id = selected.first;
      for (final n in nodes) {
        if (n.id == id) {
          target = n;
          break;
        }
      }
    }
    if (target == null) return const SizedBox.shrink();
    return NodeInspectorRouter(key: ValueKey(target.id), node: target);
  }
}
