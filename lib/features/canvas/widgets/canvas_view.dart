// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责：渲染状态 + 分发手势。业务逻辑走 CanvasNodesController / CanvasSelectionController。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../providers/link_mode_controller.dart';
import '../providers/selected_edge_controller.dart';
import '../util/edge_hit_test.dart';
import 'node_inspector_router.dart';
import 'edge_painter.dart';
import 'node_card.dart';

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

class _CanvasBody extends ConsumerWidget {
  const _CanvasBody({required this.canvasId, required this.nodes});

  final String canvasId;
  final List<CanvasNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final selected = ref.watch(canvasSelectionControllerProvider);
    final selectionCtrl =
        ref.read(canvasSelectionControllerProvider.notifier);
    final nodesCtrl =
        ref.read(canvasNodesControllerProvider(canvasId).notifier);
    final linkSourceId = ref.watch(linkModeControllerProvider);
    final linkCtrl = ref.read(linkModeControllerProvider.notifier);
    final selectedEdgeId = ref.watch(selectedEdgeControllerProvider);
    final selectedEdgeCtrl = ref.read(selectedEdgeControllerProvider.notifier);

    void onEmptyTap() {
      if (linkSourceId != null) {
        linkCtrl.cancel();
      }
      selectionCtrl.clear();
      selectedEdgeCtrl.clear();
    }

    Future<void> handleTap(CanvasNode node) async {
      if (linkSourceId != null) {
        if (node.id == linkSourceId) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(context.l10n.linkSelfNotAllowed),
              duration: const Duration(seconds: 2),
            ),
          );
          linkCtrl.cancel();
          return;
        }
        try {
          await ref
              .read(canvasEdgesControllerProvider(canvasId).notifier)
              .addEdge(sourceNodeId: linkSourceId, targetNodeId: node.id);
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(context.l10n.linkCreated),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(context.l10n.linkAlreadyExists),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } finally {
          linkCtrl.cancel();
        }
        return;
      }
      selectionCtrl.select(node.id);
    }

    final Widget canvasArea;
    if (nodes.isEmpty) {
      canvasArea = GestureDetector(
        onTap: onEmptyTap,
        child: Container(
          color: colors.surface1,
          child: Center(
            child: Text(
              context.l10n.canvasEmptyHint,
              style: typo.body.copyWith(color: colors.fg3),
            ),
          ),
        ),
      );
    } else {
      final edgesAsync =
          ref.watch(canvasEdgesControllerProvider(canvasId));
      final edges = edgesAsync.valueOrNull ?? const <CanvasEdge>[];
      final edgesCtrl =
          ref.read(canvasEdgesControllerProvider(canvasId).notifier);

      void onEdgeLayerTap(TapDownDetails d) {
        final hitId = hitTestEdge(
          point: d.localPosition,
          edges: edges,
          nodes: nodes,
        );
        if (hitId != null) {
          selectedEdgeCtrl.select(hitId);
          return;
        }
        onEmptyTap();
      }

      // 定位当前选中边的端点节点，渲染删除按钮用。
      CanvasEdge? selectedEdge;
      CanvasNode? selSrc;
      CanvasNode? selDst;
      if (selectedEdgeId != null) {
        for (final e in edges) {
          if (e.id == selectedEdgeId) {
            selectedEdge = e;
            break;
          }
        }
        if (selectedEdge != null) {
          for (final n in nodes) {
            if (n.id == selectedEdge.sourceNodeId) selSrc = n;
            if (n.id == selectedEdge.targetNodeId) selDst = n;
          }
        }
      }

      canvasArea = Container(
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
                // 连线层（含点击命中）。GestureDetector translucent 让空白处也冒泡。
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: onEdgeLayerTap,
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
                  for (final node in nodes)
                    Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      child: NodeCard(
                        node: node,
                        selected: selected.contains(node.id),
                        onTap: () => handleTap(node),
                        onPanUpdate: (delta) =>
                            nodesCtrl.moveNode(node.id, delta),
                        onStartLink: () => linkCtrl.start(node.id),
                        onDelete: () async {
                          final nodeId = node.id;
                          selectionCtrl.removed(nodeId);
                          try {
                            await nodesCtrl.removeNode(nodeId);
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.nodeDeleted),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.nodeDeleteFailed),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        isLinkSource: linkSourceId == node.id,
                        isLinkCandidate:
                            linkSourceId != null && linkSourceId != node.id,
                      ),
                    ),
                  if (selectedEdge != null &&
                      selSrc != null &&
                      selDst != null)
                    Positioned(
                      left: edgeMidpoint(source: selSrc, target: selDst).dx - 14,
                      top: edgeMidpoint(source: selSrc, target: selDst).dy - 14,
                      child: _EdgeDeleteButton(
                        onPressed: () async {
                          final id = selectedEdge!.id;
                          selectedEdgeCtrl.clear();
                          try {
                            await edgesCtrl.removeEdge(id);
                          } catch (_) {
                            // 删失败时 SelectedEdge 已清，选择放手——
                            // EdgesController 已回滚内存，用户可重试。
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

    // Inspector 仅当单选且选中的是 config 节点时显示。
    CanvasNode? inspectorTarget;
    if (selected.length == 1) {
      final id = selected.first;
      inspectorTarget = nodes
          .where((n) => n.id == id && n.role == NodeRole.config)
          .cast<CanvasNode?>()
          .firstWhere((_) => true, orElse: () => null);
    }

    final Widget leftArea;
    if (linkSourceId != null) {
      leftArea = Stack(
        children: [
          Positioned.fill(child: canvasArea),
          Positioned(
            top: InkSpacing.md,
            left: InkSpacing.md,
            right: InkSpacing.md,
            child: _LinkHintBanner(),
          ),
        ],
      );
    } else {
      leftArea = canvasArea;
    }

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
