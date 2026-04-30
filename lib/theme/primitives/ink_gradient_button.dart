// InkGradientButton：彩条渐变类型按钮（工具栏类型选择控件）。
//
// 6 变体：image / video / text / upload / editor / neutral
// 尺寸：padding 12x6（h:md=16 去一点，v:sm=8 去一点）
// 圆角 md (8px)、label 用 caption 字号、icon 20
// hover 1.05 / tap 0.95（InkMotionSpring）
// disabled（onPressed == null）：opacity 0.4，不 tap
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../motion.dart';
import '../tokens.dart';

enum InkGradientVariant { image, video, text, upload, editor, neutral }

class InkGradientButton extends StatefulWidget {
  const InkGradientButton({
    super.key,
    required this.variant,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final InkGradientVariant variant;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 公开供测试/showcase 读取变体色对。
  static (Color, Color) colorsOf(InkGradientVariant v) => switch (v) {
        InkGradientVariant.image => (const Color(0xFFEAB308), const Color(0xFFF97316)),
        InkGradientVariant.video => (const Color(0xFFA855F7), const Color(0xFFEC4899)),
        InkGradientVariant.text => (const Color(0xFF3B82F6), const Color(0xFF06B6D4)),
        InkGradientVariant.upload => (const Color(0xFF22C55E), const Color(0xFF10B981)),
        InkGradientVariant.editor => (const Color(0xFF22C55E), const Color(0xFF14B8A6)),
        InkGradientVariant.neutral => (const Color(0xFF4B5563), const Color(0xFF374151)),
      };

  @override
  State<InkGradientButton> createState() => _InkGradientButtonState();
}

class _InkGradientButtonState extends State<InkGradientButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final typo = context.inkTypography;
    final colors = context.inkColors;
    final enabled = widget.onPressed != null;
    final (from, to) = InkGradientButton.colorsOf(widget.variant);

    double scale = 1.0;
    if (_down) {
      scale = InkMotionSpring.tapScale;
    } else if (_hover) {
      scale = InkMotionSpring.hoverScale;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[from, to],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(InkRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(widget.icon, size: 20, color: colors.fg1),
                  const SizedBox(width: InkSpacing.xs),
                  Text(
                    widget.label,
                    style: typo.caption.copyWith(
                      color: colors.fg1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
