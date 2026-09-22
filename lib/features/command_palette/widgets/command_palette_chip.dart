// CommandPaletteChip：菜单栏 ⌘K 搜索入口（Workspace v2 稿：260 content 宽 + 2×10 内边距，
// 22 高 + 1px control 底线，无底色；放大镜 + 占位文 + 右侧等宽快捷键）。点击打开命令面板。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import 'command_palette_dialog.dart';

class CommandPaletteChip extends ConsumerWidget {
  const CommandPaletteChip({super.key});

  /// content 260 + padding 2×10。
  static const double width = 280;

  /// content 22 + border-bottom 1。
  static const double height = 23;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final label = context.l10n.commandPaletteTooltip;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showCommandPalette(context, ref),
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.control)),
              ),
              child: Row(
                children: <Widget>[
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: _SearchGlyph(colors.fg6),
                  ),
                  const SizedBox(width: InkSpacing.s6),
                  Expanded(
                    child: Text(
                      context.l10n.commandPaletteEntryPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.body.copyWith(color: colors.fg6),
                    ),
                  ),
                  Text(
                    commandPaletteShortcutLabel(),
                    style: typo.monoSmall.copyWith(color: colors.fg6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 稿上的 12×12 放大镜：圆 r3.6@(5.2,5.2) + 斜柄 (8,8)→(10.6,10.6)，1.3 描边。
class _SearchGlyph extends CustomPainter {
  const _SearchGlyph(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(const Offset(5.2, 5.2), 3.6, p);
    canvas.drawLine(const Offset(8, 8), const Offset(10.6, 10.6), p);
  }

  @override
  bool shouldRepaint(_SearchGlyph old) => old.color != color;
}
