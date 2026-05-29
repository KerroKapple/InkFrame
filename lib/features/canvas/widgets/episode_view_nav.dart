// EpisodeViewNav：跨视图切换栏（复刻 mockup .view-nav）。
// 等宽 11px；active=accent+surface2，hover=fg1+surface2，常态 fg3。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_episode_view.dart';

class EpisodeViewNav extends ConsumerWidget {
  const EpisodeViewNav({super.key});

  static Key tabKey(EpisodeView view) => Key('episode.viewNav.${view.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentEpisodeViewProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final view in EpisodeView.values) ...<Widget>[
          _ViewTab(
            view: view,
            label: _label(context, view),
            active: view == current,
            onTap: () =>
                ref.read(currentEpisodeViewProvider.notifier).state = view,
          ),
          if (view != EpisodeView.values.last) const SizedBox(width: 2),
        ],
      ],
    );
  }

  String _label(BuildContext context, EpisodeView view) {
    final l = context.l10n;
    return switch (view) {
      EpisodeView.canvas => l.episodeViewCanvas,
      EpisodeView.storyboard => l.episodeViewStoryboard,
      EpisodeView.script => l.episodeViewScript,
      EpisodeView.generation => l.episodeViewGeneration,
      EpisodeView.queue => l.episodeViewQueue,
    };
  }
}

class _ViewTab extends StatefulWidget {
  const _ViewTab({
    required this.view,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final EpisodeView view;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ViewTab> createState() => _ViewTabState();
}

class _ViewTabState extends State<_ViewTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Color fg = widget.active
        ? colors.accent
        : _hover
            ? colors.fg1
            : colors.fg3;
    final Color bg =
        (widget.active || _hover) ? colors.surface2 : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: EpisodeViewNav.tabKey(widget.view),
          duration: InkMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.sm + 2,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.sm),
          ),
          child: Text(
            widget.label,
            style: typo.caption.copyWith(color: fg, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}
