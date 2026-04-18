// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责：渲染状态 + 分发手势。业务逻辑走 CanvasViewModel。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../providers/canvas_view_model.dart';
import 'node_card.dart';

class CanvasView extends ConsumerWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasViewModelProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final vm = ref.read(canvasViewModelProvider.notifier);

    if (state.nodes.isEmpty) {
      return GestureDetector(
        onTap: vm.clearSelection,
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
    }

    return GestureDetector(
      onTap: vm.clearSelection,
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
                for (final node in state.nodes)
                  Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    child: NodeCard(
                      node: node,
                      selected: state.selectedIds.contains(node.id),
                      onTap: () => vm.select(node.id),
                      onPanUpdate: (delta) => vm.moveNode(node.id, delta),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
