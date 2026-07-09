import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkAmberButton extends StatefulWidget {
  const InkAmberButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  State<InkAmberButton> createState() => _InkAmberButtonState();
}

class _InkAmberButtonState extends State<InkAmberButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final bg = _hover ? colors.ctaHover : colors.cta;
    final child = AnimatedContainer(
      duration: InkMotion.fast,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InkRadius.md),
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(widget.icon, size: 18, color: colors.onAccent),
            const SizedBox(width: InkSpacing.sm),
          ],
          Text(
            widget.label,
            style: typo.body.copyWith(
              color: colors.onAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
          child: child,
        ),
      ),
    );
  }
}
