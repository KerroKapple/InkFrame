// EpisodeViewPlaceholder：非 Canvas 视图的占位屏，后续 04–08 计划逐一替换。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_episode_view.dart';

class EpisodeViewPlaceholder extends StatelessWidget {
  const EpisodeViewPlaceholder({super.key, required this.view});

  final EpisodeView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final label = switch (view) {
      EpisodeView.canvas => l.episodeViewCanvas,
      EpisodeView.storyboard => l.episodeViewStoryboard,
      EpisodeView.script => l.episodeViewScript,
      EpisodeView.generation => l.episodeViewGeneration,
      EpisodeView.queue => l.episodeViewQueue,
    };
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.construction_outlined, size: 32, color: colors.fg4),
            const SizedBox(height: InkSpacing.md),
            Text(
              l.episodeViewComingSoon(label),
              style: typo.body.copyWith(color: colors.fg3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
