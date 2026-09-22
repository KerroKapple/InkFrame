// ShellChrome：全树【唯一】的 InkWindowChrome 宿主（Workspace v2 稿的 30px 菜单栏）。
//
// 唯一性不是洁癖：InkWindowChrome 自带最小化/最大化/关闭三键，保活后两个已物化
// 标签各自带一份 = 用户看到两套窗口控件。V3a 钉死它
// （test/features/shell/shell_window_chrome_test.dart）。
//
// 槽位：leading = 16px 琥珀方块「If」+「InkFrame」，center = 六个菜单标签，
// trailing = ⌘K 搜索入口 + ⚙（设置浮层入口，复用 studioOpenSettings 文案）。
//
// 【菜单标签目前是纯文字】稿上有「文件 / 编辑 / 画布 / 节点 / 窗口 / 帮助」六项，
// 但仓库里没有对应的菜单命令；按「不做稿上没有的合理补充」与
// test/quality/no_dead_interactive_test.dart（不许挂死交互）两条，先只画标签、
// 不挂 hover / 点击，菜单内容另开卡。
//
// 【面包屑不在这里】稿把面包屑放在标签栏（标签 › 竖线 › 面包屑），见 shell_tab_bar.dart。
//
// 【别把标签条放进这三个槽位】leading + center 包在 DragToMoveArea 里，其
// onDoubleTap 让其中任何单击等满 kDoubleTapTimeout(300ms)——标签是全应用最高频
// 交互，300ms 延迟是真 UX 回归。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';
import '../../command_palette/widgets/command_palette_chip.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';

class ShellChrome extends ConsumerWidget {
  const ShellChrome({super.key});

  /// 保留原 StudioTopChrome.settingsButtonKey 的取值：⚙ 只是从 Studio 顶栏上移到
  /// 外壳 chrome，测试锚点没有理由跟着换。
  static const Key settingsButtonKey = Key('studio.topChrome.openSettings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: const _Logo(),
      center: const _MenuLabels(),
      trailing: _ChromeTrailing(
        onOpenSettings: () => ref
            .read(shellControllerProvider.notifier)
            .openOverlay(ShellOverlay.settings),
      ),
    );
  }
}

/// 16×16 琥珀方块「If」+「InkFrame」12/500，右侧 1px control 竖线（padding-right 18 + margin-right 6）。
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      padding: const EdgeInsets.only(right: InkSpacing.s18),
      margin: const EdgeInsets.only(right: InkSpacing.s6),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colors.control)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Text(
              'If',
              style: typo.micro.copyWith(
                color: colors.onAccent,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text('InkFrame', style: typo.bodyStrong.copyWith(color: colors.fg1)),
        ],
      ),
    );
  }
}

class _MenuLabels extends StatelessWidget {
  const _MenuLabels();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final List<String> items = <String>[
      l.shellMenuFile,
      l.shellMenuEdit,
      l.shellMenuCanvas,
      l.shellMenuNode,
      l.shellMenuWindow,
      l.shellMenuHelp,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final String item in items)
          Container(
            height: InkWindowChrome.height,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            alignment: Alignment.center,
            child: Text(item, style: typo.body.copyWith(color: colors.fg3)),
          ),
      ],
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
        const SizedBox(width: InkSpacing.s12),
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
        ? colors.fg6
        : _hover
            ? colors.fg1
            : colors.fg3;
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
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover && enabled ? colors.surface5 : Colors.transparent,
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Icon(Icons.settings_outlined, size: 14, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
