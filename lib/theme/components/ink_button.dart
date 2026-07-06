// InkButton：按钮基础组件，区分 primary / secondary / ghost / danger。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum InkButtonVariant { primary, secondary, ghost, danger }

class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = InkButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final InkButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final bool enabled = onPressed != null;
    // 彩色底（brand/danger）上的前景用画布最底色（对齐 InkAmberButton），
    // fg1 在暗色变体是浅米色，放琥珀上对比度不足；禁用态统一压灰。
    final (Color bg, Color fg, Color? border) = switch (variant) {
      InkButtonVariant.primary => enabled
          ? (colors.brand, colors.surfaceCanvas, null)
          : (colors.surface3, colors.fg4, colors.border),
      InkButtonVariant.secondary => enabled
          ? (colors.surface3, colors.fg1, colors.border)
          : (colors.surface3, colors.fg4, colors.border),
      InkButtonVariant.ghost => enabled
          ? (const Color(0x00000000), colors.fg1, colors.border)
          : (const Color(0x00000000), colors.fg4, colors.border),
      InkButtonVariant.danger => enabled
          ? (colors.danger, colors.surfaceCanvas, null)
          : (colors.surface3, colors.fg4, colors.border),
    };

    return Semantics(
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.xs,
          vertical: InkSpacing.xs,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.md),
            border: border != null ? Border.all(color: border) : null,
          ),
          child: Material(
            color: const Color(0x00000000),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(InkRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.md,
                  vertical: InkSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: InkSpacing.md, color: fg),
                      const SizedBox(width: InkSpacing.sm),
                    ],
                    Text(
                      label,
                      style: context.inkTypography.label.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
