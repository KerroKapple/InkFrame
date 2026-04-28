// Glass 毛玻璃三态容器：Card / Panel / Pill（对应 CineFlow globals.css
// .glass-card / .glass-panel / .glass-pill）。
//
// 共同特征：BackdropFilter 做模糊+饱和度、半透明 surface1 底色、
// 细白边（0.08~0.10 opacity）、overlay shadow。
// 差异：圆角（card=lg / panel=md / pill=pill），
//      blur 强度（card=40 / panel=24），
//      saturation boost（card=1.5 / panel=1.25），
//      不透明度（card=0.95 / panel=0.90）。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum _GlassKind { card, panel, pill }

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.kind,
    required this.child,
    this.padding,
  });

  final _GlassKind kind;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final (double radius, double blur, double satBoost, double opacity, double borderAlpha) =
        switch (kind) {
      _GlassKind.card => (InkRadius.lg, 40.0, 1.50, 0.95, 0.10),
      _GlassKind.panel => (InkRadius.md, 24.0, 1.25, 0.90, 0.08),
      _GlassKind.pill => (InkRadius.pill, 40.0, 1.50, 0.95, 0.10),
    };

    final borderRadius = BorderRadius.circular(radius);
    final filter = ui.ImageFilter.compose(
      outer: ui.ColorFilter.matrix(_saturationMatrix(satBoost)),
      inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: filter,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.surface1.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
              width: 0.8,
            ),
            boxShadow: InkShadow.overlay,
          ),
          child: child,
        ),
      ),
    );
  }

  static List<double> _saturationMatrix(double s) {
    final r = 0.213 * (1 - s);
    final g = 0.715 * (1 - s);
    final b = 0.072 * (1 - s);
    return <double>[
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

class InkGlassCard extends StatelessWidget {
  const InkGlassCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.card, padding: padding, child: child);
}

class InkGlassPanel extends StatelessWidget {
  const InkGlassPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.panel, padding: padding, child: child);
}

class InkGlassPill extends StatelessWidget {
  const InkGlassPill({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.pill, padding: padding, child: child);
}
