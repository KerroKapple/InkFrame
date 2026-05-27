// ProjectCard：16:10 占位静帧 + 衬线标题 + mono 元数据。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';

class StudioProjectCard extends StatelessWidget {
  const StudioProjectCard({
    super.key,
    required this.name,
    required this.metaLine,
    required this.onTap,
  });

  final String name;
  final String metaLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkNoirCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(InkRadius.lg),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colors.surface3,
                    colors.surface1,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.md,
              InkSpacing.md - 2,
              InkSpacing.md,
              InkSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: typo.headline.copyWith(color: colors.fg1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: InkSpacing.xs),
                Text(
                  metaLine,
                  style: typo.caption.copyWith(
                    color: colors.fg3,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
