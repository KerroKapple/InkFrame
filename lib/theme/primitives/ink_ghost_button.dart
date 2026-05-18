// InkGhostButton：默认透明、hover 才显边框的次按钮。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkGhostButton extends StatefulWidget {
  const InkGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  State<InkGhostButton> createState() => _InkGhostButtonState();
}

class _InkGhostButtonState extends State<InkGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: InkMotion.fast,
            height: widget.compact ? 28 : 36,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? InkSpacing.sm : InkSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _hover ? colors.surface3 : Colors.transparent,
              borderRadius: BorderRadius.circular(InkRadius.sm),
              border: Border.all(
                color: _hover ? colors.border : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 16, color: colors.fg2),
                  const SizedBox(width: InkSpacing.xs),
                ],
                Text(widget.label, style: typo.body.copyWith(color: colors.fg2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
