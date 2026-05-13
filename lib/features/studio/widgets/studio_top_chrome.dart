// Studio 顶栏：复用 InkWindowChrome，三槽位填 leading=小 logo / center=breadcrumb /
// trailing=⌘K + Avatar。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';

class StudioTopChrome extends StatelessWidget implements PreferredSizeWidget {
  const StudioTopChrome({
    super.key,
    required this.studioName,
    required this.breadcrumbTail,
  });

  final String studioName;
  final String breadcrumbTail;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return InkWindowChrome(
      leading: const _MiniLogo(),
      center: _Breadcrumb(
        studioName: studioName,
        breadcrumbTail: breadcrumbTail,
      ),
      trailing: const _ChromeTrailing(),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.headline.copyWith(
      fontSize: 18,
      color: colors.fg1,
    );
    return Padding(
      padding: const EdgeInsets.only(right: InkSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text('Ink', style: base),
          Text('/', style: base.copyWith(color: colors.accent)),
          Text('Frame', style: base),
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.studioName,
    required this.breadcrumbTail,
  });

  final String studioName;
  final String breadcrumbTail;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.body.copyWith(color: colors.fg2);
    final accent = typo.body.copyWith(color: colors.fg1);
    final chev = typo.body.copyWith(color: colors.fg4);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(studioName, style: base),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
          child: Text('›', style: chev),
        ),
        Text('Projects', style: base),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
          child: Text('›', style: chev),
        ),
        Text(breadcrumbTail, style: accent),
      ],
      ),
    );
  }
}

class _ChromeTrailing extends StatelessWidget {
  const _ChromeTrailing();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.sm,
          ),
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
