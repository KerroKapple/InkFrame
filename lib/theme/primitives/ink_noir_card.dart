import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkNoirCard extends StatefulWidget {
  const InkNoirCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<InkNoirCard> createState() => _InkNoirCardState();
}

class _InkNoirCardState extends State<InkNoirCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final borderColor = widget.selected
        ? colors.accent
        : _hover
            ? colors.borderHover
            : colors.border;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.lg),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: widget.child,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? card
          : GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}
