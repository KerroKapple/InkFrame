// InkSurfaceButton：surface-2 单色按钮（工具栏辅助控件）。
//
// 两个 flavor：
//   - InkSurfaceButton(label, icon?, onPressed)       — 常规 padding 10x6
//   - InkSurfaceButton.icon(icon, onPressed, tooltip) — 28x28 方形图标
// 通用：bg surface2 → hover surface3；hover 1.05 / tap 0.95；disabled 0.4 opacity。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../motion.dart';
import '../tokens.dart';

class InkSurfaceButton extends StatefulWidget {
  const InkSurfaceButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  })  : _iconOnly = false,
        tooltip = null;

  const InkSurfaceButton.icon({
    super.key,
    required IconData this.icon,
    required this.onPressed,
    this.tooltip,
  })  : label = '',
        _iconOnly = true;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool _iconOnly;

  @override
  State<InkSurfaceButton> createState() => _InkSurfaceButtonState();
}

class _InkSurfaceButtonState extends State<InkSurfaceButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final enabled = widget.onPressed != null;

    final bg = _hover ? colors.surface3 : colors.surface2;
    double scale = 1.0;
    if (_down) {
      scale = InkMotionSpring.tapScale;
    } else if (_hover) {
      scale = InkMotionSpring.hoverScale;
    }

    Widget child;
    if (widget._iconOnly) {
      child = SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Icon(widget.icon, size: 16, color: colors.fg1),
        ),
      );
    } else {
      child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.icon != null) ...<Widget>[
              Icon(widget.icon, size: 16, color: colors.fg1),
              const SizedBox(width: InkSpacing.xs),
            ],
            Text(
              widget.label,
              style: typo.caption.copyWith(color: colors.fg1),
            ),
          ],
        ),
      );
    }

    final decorated = AnimatedScale(
      scale: scale,
      duration: InkMotion.fast,
      curve: Curves.easeOut,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: InkMotion.fast,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.md),
          ),
          child: child,
        ),
      ),
    );

    final tappable = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: decorated,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: tappable);
    }
    return tappable;
  }
}
