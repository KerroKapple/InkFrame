// CanvasLeftToolbar：左侧 56 宽 surface1 工具栏，竖列 8 个 icon。
//
// 仅视觉；点击不接业务（Task 13 起接 selection / pan / etc.）。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class CanvasLeftToolbar extends StatelessWidget {
  const CanvasLeftToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.sm + 2),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _ToolButton(icon: Icons.near_me_outlined, active: true),
          _ToolButton(icon: Icons.pan_tool_outlined),
          _ToolButton(icon: Icons.crop_din),
          _ToolButton(icon: Icons.account_tree_outlined),
          _ToolButton(icon: Icons.category_outlined),
          _ToolButton(icon: Icons.text_format),
          _ToolButton(icon: Icons.image_outlined),
          _ToolButton(icon: Icons.view_in_ar_outlined),
        ],
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({required this.icon, this.active = false});
  final IconData icon;
  final bool active;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final bg = widget.active
        ? colors.surface2
        : _hover
            ? colors.surface3
            : Colors.transparent;
    final fg = widget.active
        ? colors.accent
        : _hover
            ? colors.fg1
            : colors.fg3;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.md),
            border: widget.active
                ? Border.all(color: colors.accent.withValues(alpha: 0.35))
                : null,
          ),
          child: Icon(widget.icon, size: 16, color: fg),
        ),
      ),
    );
  }
}
