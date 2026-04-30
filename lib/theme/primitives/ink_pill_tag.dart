// InkPillTag：圆胶囊展示标签（rounded-full + 弱边 + 半透明 bg）。
//
// 圆角 pill；padding 8x2；label 用 micro；可选 leading icon 12；纯展示不 tap。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkPillTag extends StatelessWidget {
  const InkPillTag({
    super.key,
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(InkRadius.pill),
        border: Border.all(color: colors.borderSubtle, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: colors.fg2),
            const SizedBox(width: InkSpacing.xs),
          ],
          Text(label, style: typo.micro.copyWith(color: colors.fg2)),
        ],
      ),
    );
  }
}
