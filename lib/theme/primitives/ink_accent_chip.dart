// InkAccentChip：accent 半透明激活态芯片
// (border-accent-primary/50 bg-accent-primary/10 text-accent-primary)。
//
// padding 10x4；圆角 md；label 用 micro；可选 leading icon 16；onPressed 可选。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkAccentChip extends StatelessWidget {
  const InkAccentChip({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.50),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: colors.accent),
            const SizedBox(width: InkSpacing.xs),
          ],
          Text(
            label,
            style: typo.micro.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onPressed == null) return body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onPressed, child: body),
    );
  }
}
