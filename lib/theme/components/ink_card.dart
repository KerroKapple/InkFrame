// InkCard：卡片/面板的默认容器，统一圆角/背景/阴影。
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(InkSpacing.md),
    this.elevation = InkCardElevation.flat,
  });

  final Widget child;
  final EdgeInsets padding;
  final InkCardElevation elevation;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (elevation) {
          InkCardElevation.flat => colors.surface2,
          InkCardElevation.raised => colors.surface3,
        },
        borderRadius: BorderRadius.circular(InkRadius.lg),
        boxShadow: switch (elevation) {
          InkCardElevation.flat => InkShadow.card,
          InkCardElevation.raised => InkShadow.elevated,
        },
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

enum InkCardElevation { flat, raised }
