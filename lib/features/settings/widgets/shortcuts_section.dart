// ShortcutsSection — 设置「快捷键」页（Screens 稿第 3 屏左导航第 3 项）。
//
// 只读清单：数据来自 util/shortcut_catalog.dart，而那份清单又是从生产代码里
// 真正注册的 Shortcuts 表反推的——这一页改不了键位，但永远不会显示一个不存在的键。
// 表形照 API 密钥页：26+1 表头（11px fg6）+ 逐行 1px borderSubtle 分隔。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../util/shortcut_catalog.dart';

class ShortcutsSection extends StatelessWidget {
  const ShortcutsSection({super.key, this.isMacOverride});

  /// 平台注入口（测试用）；null 时读 defaultTargetPlatform。
  final bool? isMacOverride;

  /// 稿的键位列：右对齐等宽，宽度够放下「Ctrl+Shift+Delete」这类长串。
  static const double keyColumnWidth = 180;

  static String actionLabel(AppLocalizations l, ShortcutAction a) =>
      switch (a) {
        ShortcutAction.commandPalette => l.settingsShortcutCommandPalette,
        ShortcutAction.overlayDismiss => l.settingsShortcutOverlayDismiss,
        ShortcutAction.canvasDelete => l.settingsShortcutCanvasDelete,
        ShortcutAction.canvasEscape => l.settingsShortcutCanvasEscape,
        ShortcutAction.canvasSelectAll => l.settingsShortcutCanvasSelectAll,
        ShortcutAction.canvasZoomIn => l.settingsShortcutCanvasZoomIn,
        ShortcutAction.canvasZoomOut => l.settingsShortcutCanvasZoomOut,
        ShortcutAction.canvasZoomReset => l.settingsShortcutCanvasZoomReset,
      };

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final bool isMac =
        isMacOverride ?? defaultTargetPlatform == TargetPlatform.macOS;
    final TextStyle head = t.meta.copyWith(color: c.fg6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 27, // content 26 + border-bottom 1
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.borderStrong)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(l.settingsColumnAction, style: head)),
              SizedBox(
                width: keyColumnWidth,
                child: Text(
                  l.settingsColumnShortcut,
                  style: head,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        for (final ShortcutRow row in buildShortcutRows(isMac: isMac))
          Container(
            height: 29, // content 28 + border-bottom 1
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.borderSubtle)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    actionLabel(l, row.action),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.fg2),
                  ),
                ),
                SizedBox(
                  width: keyColumnWidth,
                  child: Text(
                    // 一个动作可以绑多个键（Delete / Backspace），逐个列出。
                    row.keys.join('  ·  '),
                    style: t.mono.copyWith(color: c.fg1),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: InkSpacing.s12),
        Text(
          l.settingsShortcutsNote,
          style: t.meta.copyWith(color: c.fg5, height: 1.5),
        ),
      ],
    );
  }
}
