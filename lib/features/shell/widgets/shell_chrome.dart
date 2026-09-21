// ShellChrome：全树【唯一】的 InkWindowChrome 宿主。
//
// 唯一性不是洁癖：InkWindowChrome 自带最小化/最大化/关闭三键，保活后两个已物化
// 标签各自带一份 = 用户看到两套窗口控件。V3a 钉死它
// （test/features/shell/shell_window_chrome_test.dart）。
//
// 槽位：leading = Ink/Frame 小 logo，center = ShellBreadcrumb，
// trailing = ⌘K chip + ⚙（设置浮层入口，复用 studioOpenSettings 文案）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';
import '../../command_palette/widgets/command_palette_chip.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';
import 'shell_breadcrumb.dart';

class ShellChrome extends ConsumerWidget {
  const ShellChrome({super.key});

  /// 保留原 StudioTopChrome.settingsButtonKey 的取值：⚙ 只是从 Studio 顶栏上移到
  /// 外壳 chrome，测试锚点没有理由跟着换。
  static const Key settingsButtonKey = Key('studio.topChrome.openSettings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: const _MiniLogo(),
      center: const ShellBreadcrumb(),
      trailing: _ChromeTrailing(
        onOpenSettings: () => ref
            .read(shellControllerProvider.notifier)
            .openOverlay(ShellOverlay.settings),
      ),
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

class _ChromeTrailing extends StatelessWidget {
  const _ChromeTrailing({required this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CommandPaletteChip(),
        const SizedBox(width: InkSpacing.md),
        _SettingsIconButton(onPressed: onOpenSettings),
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
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: enabled ? (_) => widget.onPressed?.call() : null,
          child: Tooltip(
            message: context.l10n.studioOpenSettings,
            child: AnimatedContainer(
              key: ShellChrome.settingsButtonKey,
              duration: InkMotion.fast,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover && enabled ? colors.surface3 : Colors.transparent,
                borderRadius: BorderRadius.circular(InkRadius.sm),
              ),
              child: Icon(Icons.settings_outlined, size: 16, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
