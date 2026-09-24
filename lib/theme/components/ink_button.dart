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
    // 唯一彩底是琥珀（primary），前景走 onAccent（per-variant 锁 WCAG AA）。
    // danger 只做文字与小图标、不做容器底色：危险按钮 = 透明底 + 红字 + 次级边框。
    // 禁用态统一压灰。
    final (Color bg, Color fg, Color? border) = switch (variant) {
      InkButtonVariant.primary => enabled
          ? (colors.accent, colors.onAccent, null)
          : (colors.surface3, colors.fg4, colors.outline),
      InkButtonVariant.secondary => enabled
          ? (colors.surface3, colors.fg1, colors.controlStrong)
          : (colors.surface3, colors.fg4, colors.outline),
      InkButtonVariant.ghost => enabled
          ? (const Color(0x00000000), colors.fg1, colors.outline)
          : (const Color(0x00000000), colors.fg4, colors.outline),
      InkButtonVariant.danger => enabled
          ? (const Color(0x00000000), colors.danger, colors.controlStrong)
          : (colors.surface3, colors.fg4, colors.outline),
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
                      style: context.inkTypography.bodyStrong.copyWith(color: fg),
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
