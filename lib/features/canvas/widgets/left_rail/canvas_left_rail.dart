// CanvasLeftRail：画布左侧 43px 图标导航条（画布重设计稿 main.js「左侧导航条」，图标集 v1）。
//
// 42 + 1px 右沿（borderStrong），surface4 底；纵向排列，上下内边距 8、键间距 4。
// 上：大纲 / 素材 / 角色三个页键；Spacer 之后：快捷键 / 收起。键 32×32、圆角 4、图标 20。
//   - 页键（LeftRailController.tapPage）：点非当前页 = 展开并切到该页；点展开着的当前页 = 收起。
//     点亮 = 面板展开且停在这一页：图标 accent + accentWash 底；其余图标 fg4。
//   - 快捷键：设置浮层落在「快捷键」页——先置 settingsPageProvider，再开浮层。
//   - 收起：面板开合，与画布快捷键 Ctrl+\ / ⌘\ 同一个动作；tooltip 带键位（取 CanvasToolKeys
//     的同一个常量，经 shortcut_catalog 的 formatShortcutActivator 出字——改键位不会只改一半）。
// 稿上的「剧本」「帮助」不画：剧本原文没有落库（导入只生成镜头链），帮助没有内容——无后端不画，
// 不画假键。hover 照抄浮动工具条的工具键（surface5 底）；每个键都走 InkActivatable。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_icon.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../../theme/primitives/ink_activatable.dart';
import '../../../../theme/tokens.dart';
import '../../../settings/providers/settings_page.dart';
import '../../../settings/util/shortcut_catalog.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/shell_controller.dart';
import '../../providers/left_rail_state.dart';
import '../canvas_shortcuts.dart';

class CanvasLeftRail extends ConsumerWidget {
  const CanvasLeftRail({super.key});

  /// 稿：border-box 43 = 42 + 1px 右沿。
  static const double width = 43;

  /// 键边长：与浮动工具条的键同尺寸。
  static const double keySize = InkToolbarSize.button;

  /// 键的测试锚点：outline / assets / characters（= LeftRailPage.name）/ shortcuts / toggle。
  static Key keyOf(String id) => ValueKey<String>('canvasLeftRail-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final l = context.l10n;
    final LeftRailState rail = ref.watch(leftRailProvider);
    final LeftRailController control = ref.read(leftRailProvider.notifier);

    Widget pageKey(LeftRailPage page, InkGlyph glyph, String label) {
      final bool active = rail.isActive(page);
      return _RailKey(
        key: keyOf(page.name),
        glyph: glyph,
        label: label,
        idleColor: c.fg4,
        active: active,
        selected: active,
        onTap: () => control.tapPage(page),
      );
    }

    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final String? keys = formatShortcutActivator(
      isMac
          ? CanvasToolKeys.toggleLeftRailMeta
          : CanvasToolKeys.toggleLeftRailControl,
      isMac: isMac,
    );
    final String toggleLabel =
        rail.expanded ? l.leftRailCollapse : l.leftRailExpand;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        children: <Widget>[
          pageKey(LeftRailPage.outline, InkGlyph.outline, l.leftRailOutline),
          const SizedBox(height: InkSpacing.xs),
          pageKey(LeftRailPage.assets, InkGlyph.assets, l.leftRailAssets),
          const SizedBox(height: InkSpacing.xs),
          pageKey(
            LeftRailPage.characters,
            InkGlyph.characters,
            l.leftRailCharacters,
          ),
          const Spacer(),
          _RailKey(
            key: keyOf('shortcuts'),
            glyph: InkGlyph.shortcuts,
            label: l.leftRailShortcuts,
            idleColor: c.fg5,
            onTap: () => _openShortcutSettings(ref),
          ),
          const SizedBox(height: InkSpacing.xs),
          _RailKey(
            key: keyOf('toggle'),
            glyph: InkGlyph.panelToggle,
            label: toggleLabel,
            tooltip: keys == null ? toggleLabel : '$toggleLabel  $keys',
            idleColor: c.fg5,
            onTap: control.toggle,
          ),
        ],
      ),
    );
  }

  /// 设置浮层落在「快捷键」页：先置页（浮层每次打开都读它），再开浮层。
  static void _openShortcutSettings(WidgetRef ref) {
    ref.read(settingsPageProvider.notifier).state = SettingsPage.shortcuts;
    ref
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.settings);
  }
}

/// 导航条上的一个键：32×32、圆角 4、图标 20。点亮 = accent 图标 + accentWash 底；hover = surface5 底。
class _RailKey extends StatelessWidget {
  const _RailKey({
    super.key,
    required this.glyph,
    required this.label,
    required this.idleColor,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.selected,
  });

  final InkGlyph glyph;

  /// 读屏名；没给 [tooltip] 时也当 tooltip。
  final String label;

  /// 未点亮时的图标色（页键 fg4，底部两键 fg5）。
  final Color idleColor;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  /// 页键报 selected（开 / 关两态）；动作键不声明。
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      tooltip: tooltip ?? label,
      focusRingRadius: BorderRadius.circular(InkRadius.sm),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        width: CanvasLeftRail.keySize,
        height: CanvasLeftRail.keySize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accentWash : (hovered ? c.surface5 : null),
          borderRadius: BorderRadius.circular(InkRadius.sm),
        ),
        child: InkIcon(
          glyph,
          size: InkIconSize.md,
          color: active ? c.accent : idleColor,
        ),
      ),
    );
  }
}
