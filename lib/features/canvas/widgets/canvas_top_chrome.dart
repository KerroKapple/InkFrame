// CanvasTopChrome：Canvas 顶栏 —— 复用 InkWindowChrome，三槽位
// leading=Ink/Frame 小 logo，center=breadcrumb，trailing=⌘K + ▶ + avatar。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/primitives/ink_back_button.dart';
import '../../../theme/tokens.dart';
import '../providers/current_canvas_id.dart';
import 'episode_view_nav.dart';

class CanvasTopChrome extends ConsumerWidget implements PreferredSizeWidget {
  const CanvasTopChrome({super.key, required this.canvasName});

  final String canvasName;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: _LeadingRow(
        onBack: () =>
            ref.read(currentCanvasIdProvider.notifier).state = null,
      ),
      center: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(child: _Breadcrumb(canvasName: canvasName)),
          const SizedBox(width: InkSpacing.lg),
          const EpisodeViewNav(),
        ],
      ),
      trailing: const _Trailing(),
    );
  }
}

class _LeadingRow extends StatelessWidget {
  const _LeadingRow({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.headline.copyWith(fontSize: 16, color: colors.fg1);
    return Padding(
      padding: const EdgeInsets.only(right: InkSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkBackButton(onBack: onBack),
          const SizedBox(width: InkSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('Ink', style: base),
              Text('/', style: base.copyWith(color: colors.accent)),
              Text('Frame', style: base),
            ],
          ),
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.canvasName});
  final String canvasName;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final base = typo.body.copyWith(color: colors.fg2);
    final accent = typo.body.copyWith(color: colors.fg1);
    final chev = typo.body.copyWith(color: colors.fg4);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.canvasBreadcrumbProject, style: base),
          _chev(chev),
          Text(canvasName, style: base),
          _chev(chev),
          Text(l.canvasBreadcrumbCanvas, style: accent),
        ],
      ),
    );
  }

  Widget _chev(TextStyle s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        child: Text('›', style: s),
      );
}

class _Trailing extends StatelessWidget {
  const _Trailing();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(InkRadius.sm),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(
            '⌘ K',
            style: typo.caption.copyWith(color: colors.fg3),
          ),
        ),
        const SizedBox(width: InkSpacing.md),
        Icon(Icons.play_arrow, size: 18, color: colors.fg2),
        const SizedBox(width: InkSpacing.md),
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface3,
            shape: BoxShape.circle,
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(
            'K',
            style: typo.label.copyWith(color: colors.accent),
          ),
        ),
      ],
    );
  }
}
