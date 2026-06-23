// 泳道标题栏：半透明悬浮条，显示泳道名 + 编辑/删除操作。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/style_lane.dart';

class LaneTitleBar extends StatelessWidget {
  const LaneTitleBar({
    super.key,
    required this.lane,
    required this.onEdit,
    required this.onDelete,
  });

  final StyleLane lane;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typography = context.inkTypography;
    final l10n = context.l10n;

    return Material(
      color: colors.surface3.withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(InkRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.sm,
          vertical: InkSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lane.label.isEmpty ? l10n.laneUntitled : lane.label,
                style: typography.label.copyWith(color: colors.fg1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: l10n.laneEditTitle,
              iconSize: InkSpacing.md,
              color: colors.fg2,
              padding: const EdgeInsets.all(InkSpacing.xs),
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: l10n.laneDelete,
              iconSize: InkSpacing.md,
              color: colors.fg2,
              padding: const EdgeInsets.all(InkSpacing.xs),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
