// InkDashedSlot：虚线边"未填"空槽容器。
//
// 用途：参考图空位、待填写的占位按钮。CustomPainter 画虚线 RRect 外框。
// 默认 dash 6px / gap 4px；border 色取 inkColors.border；tap hover 淡色底。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../motion.dart';
import '../tokens.dart';

class InkDashedSlot extends StatefulWidget {
  const InkDashedSlot({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(
      horizontal: InkSpacing.s10,
      vertical: InkSpacing.s6,
    ),
    this.borderRadius = const Radius.circular(InkRadius.md),
    this.dashLength = 6,
    this.gapLength = 4,
    this.strokeWidth = 1,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final Radius borderRadius;
  // 虚线参数
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  @override
  State<InkDashedSlot> createState() => _InkDashedSlotState();
}

class _InkDashedSlotState extends State<InkDashedSlot> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final enabled = widget.onPressed != null;
    double scale = 1.0;
    if (_down) {
      scale = InkMotionSpring.tapScale;
    } else if (_hover && enabled) {
      scale = InkMotionSpring.hoverScale;
    }

    final content = CustomPaint(
      painter: _DashedBorderPainter(
        color: colors.border,
        radius: widget.borderRadius,
        dashLength: widget.dashLength,
        gapLength: widget.gapLength,
        strokeWidth: widget.strokeWidth,
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    final animated = AnimatedScale(
      scale: scale,
      duration: InkMotion.fast,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: InkMotion.fast,
        decoration: BoxDecoration(
          color: _hover && enabled
              ? colors.surface2.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.all(widget.borderRadius),
        ),
        child: content,
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: animated,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    this.dashLength = 6,
    this.gapLength = 4,
    this.strokeWidth = 1,
  });

  final Color color;
  final Radius radius;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      radius,
    );

    final path = Path()..addRRect(rect);
    final dashed = _dashPath(path, dashLength, gapLength);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dashLen, double gapLen) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLen;
        dest.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gapLen;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}
