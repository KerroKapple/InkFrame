// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责：渲染状态 + 分发手势。业务逻辑走 CanvasNodesController / CanvasSelectionController。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_bootstrap_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/current_canvas_id.dart';
import 'config_node_inspector.dart';
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

    final Widget canvasArea;
    if (nodes.isEmpty) {
      canvasArea = GestureDetector(
        onTap: selectionCtrl.clear,
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
      canvasArea = GestureDetector(
        onTap: selectionCtrl.clear,
        child: Container(
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
                  for (final node in nodes)
                    Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      child: NodeCard(
                        node: node,
                        selected: selected.contains(node.id),
                        onTap: () => selectionCtrl.select(node.id),
                        onPanUpdate: (delta) =>
                            nodesCtrl.moveNode(node.id, delta),
                      ),
                    ),
                ],
              ),
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

    return Row(
      children: [
        Expanded(child: canvasArea),
        if (inspectorTarget != null)
          ConfigNodeInspector(
            key: ValueKey(inspectorTarget.id),
            node: inspectorTarget,
          ),
      ],
    );
  }
}
