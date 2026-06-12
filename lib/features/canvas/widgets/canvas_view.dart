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
import 'canvas_empty_state.dart';
import 'edge_painter.dart';
import 'node_card.dart';
import 'node_inspector_router.dart';
import 'video_lightbox.dart';

const _kSnackBarDuration = Duration(seconds: 2);

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(text), duration: _kSnackBarDuration),
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

    final selected = ref.watch(canvasSelectionControllerProvider);
    final linkSourceId = ref.watch(linkModeControllerProvider);

    void onEmptyTap() {
      if (linkSourceId != null) {
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

    // Inspector 仅当单选且选中的是 config 节点时显示。
    CanvasNode? inspectorTarget;
    if (selected.length == 1) {
      final id = selected.first;
      inspectorTarget = nodes
          .where((n) => n.id == id && n.role == NodeRole.config)
          .cast<CanvasNode?>()
          .firstWhere((_) => true, orElse: () => null);
    }

    final Widget leftArea = Stack(
      children: [
        Positioned.fill(child: canvasArea),
        if (linkSourceId != null)
          Positioned(
            top: InkSpacing.md,
            left: InkSpacing.md,
            right: InkSpacing.md,
            child: _LinkHintBanner(),
          ),
        if (selected.length >= 2)
          Positioned(
            top: InkSpacing.md,
            right: InkSpacing.md,
            child: _SelectionCountChip(count: selected.length),
          ),
      ],
    );

    return Row(
      children: [
        Expanded(child: leftArea),
        if (inspectorTarget != null)
          NodeInspectorRouter(
            key: ValueKey(inspectorTarget.id),
            node: inspectorTarget,
          ),
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
      await nodesCtrl.removeNode(nodeId);
      if (context.mounted) {
        _showSnack(context, context.l10n.nodeDeleted);
      }
    } on InkError catch (_) {
      if (context.mounted) {
        _showSnack(context, context.l10n.nodeDeleteFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final selected = ref.watch(canvasSelectionControllerProvider);
    final linkSourceId = ref.watch(linkModeControllerProvider);
    final selectedEdgeId = ref.watch(selectedEdgeControllerProvider);
    final edges = ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];

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
        boundaryMargin: const EdgeInsets.all(2000),
        minScale: 0.1,
        maxScale: 3.0,
        child: SizedBox(
          width: 4000,
          height: 4000,
          child: Stack(
            children: [
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
              for (final node in nodes)
                Positioned(
                  key: ValueKey('node-card-${node.id}'),
                  left: node.position.dx,
                  top: node.position.dy,
                  // HI-13/HI-15：拖拽位移在 NodeCard 内部局部累积，落点
                  // 一次性提交 moveNode；RepaintBoundary 把拖拽重绘隔离
                  // 在本卡片 layer，不放大到全画布。
                  child: RepaintBoundary(
                    child: NodeCard(
                      node: node,
                      selected: selected.contains(node.id),
                      onTap: () => onNodeTap(node),
                      onDragEnd: (totalDelta) => ref
                          .read(canvasNodesControllerProvider(canvasId).notifier)
                          .moveNode(node.id, totalDelta),
                      onStartLink: () => ref
                          .read(linkModeControllerProvider.notifier)
                          .start(node.id),
                      onDelete: () => _handleNodeDelete(context, ref, node.id),
                      isLinkSource: linkSourceId == node.id,
                      isLinkCandidate:
                          linkSourceId != null && linkSourceId != node.id,
                    ),
                  ),
                ),
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
                    onPressed: () async {
                      final id = selectedGeometry.edge.id;
                      ref.read(selectedEdgeControllerProvider.notifier).clear();
                      try {
                        await ref
                            .read(canvasEdgesControllerProvider(canvasId)
                                .notifier)
                            .removeEdge(id);
                      } on InkError catch (_) {
                        // 删失败时 SelectedEdge 已清，EdgesController 已回滚内存，
                        // 用户可重试。
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
