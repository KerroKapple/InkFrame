// Studio 顶栏：复用 InkWindowChrome，三槽位填 leading=小 logo / center=breadcrumb /
// trailing=⌘K + Settings + Avatar。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';

class StudioTopChrome extends StatelessWidget implements PreferredSizeWidget {
  const StudioTopChrome({
    super.key,
    required this.studioName,
    required this.breadcrumbTail,
    this.onOpenSettings,
  });

  static const Key settingsButtonKey = Key('studio.topChrome.openSettings');

  final String studioName;
  final String breadcrumbTail;
  final VoidCallback? onOpenSettings;

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
      trailing: _ChromeTrailing(onOpenSettings: onOpenSettings),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.headlineSm.copyWith(color: colors.fg1);
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
  const _ChromeTrailing({this.onOpenSettings});

  final VoidCallback? onOpenSettings;

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
        _SettingsIconButton(onPressed: onOpenSettings),
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

class _SettingsIconButton extends StatefulWidget {
  const _SettingsIconButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_SettingsIconButton> createState() => _SettingsIconButtonState();
}

class _SettingsIconButtonState extends State<_SettingsIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final enabled = widget.onPressed != null;
    final iconColor = !enabled
        ? colors.fg4
        : _hover
            ? colors.accent
            : colors.fg2;
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.studioOpenSettings,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled
              ? (_) => widget.onPressed?.call()
              : null,
          child: Tooltip(
            message: context.l10n.studioOpenSettings,
            child: AnimatedContainer(
              key: StudioTopChrome.settingsButtonKey,
              duration: InkMotion.fast,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover && enabled
                    ? colors.surface3
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(InkRadius.sm),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 16,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
