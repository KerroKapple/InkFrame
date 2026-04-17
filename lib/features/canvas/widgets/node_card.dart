// NodeCard：画布上的单个节点卡片。
//
// 负责渲染 + 选中态视觉 + 拖拽手势。不含业务逻辑。

import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';

class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onPanUpdate,
  });

  final CanvasNode node;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset delta) onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (d) => onPanUpdate(d.delta),
      child: Container(
        width: node.size.width,
        height: node.size.height,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(InkRadius.lg),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? InkShadow.elevated : InkShadow.card,
        ),
        padding: const EdgeInsets.all(InkSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconFor(node.type),
                  size: 16,
                  color: colors.fg3,
                ),
                const SizedBox(width: InkSpacing.xs),
                Text(
                  _typeLabel(context, node.type),
                  style: typo.caption.copyWith(color: colors.fg3),
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.sm),
            Text(
              node.label,
              style: typo.body.copyWith(color: colors.fg1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(CanvasNodeType type) => switch (type) {
        CanvasNodeType.image => Icons.image_outlined,
        CanvasNodeType.text => Icons.text_fields,
        CanvasNodeType.video => Icons.videocam_outlined,
        CanvasNodeType.shot => Icons.movie_outlined,
      };

  static String _typeLabel(BuildContext context, CanvasNodeType type) =>
      switch (type) {
        CanvasNodeType.image => context.l10n.canvasNodeImageType,
        _ => type.name,
      };
}
