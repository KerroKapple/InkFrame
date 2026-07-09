// CommandPaletteChip：顶栏 ⌘K 入口——PL-1 起做真，点击打开命令面板。
// canvas / studio 两处顶栏共用（原先各自内联的纯展示 chip 已收敛到此）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import 'command_palette_dialog.dart';

class CommandPaletteChip extends ConsumerStatefulWidget {
  const CommandPaletteChip({super.key});

  @override
  ConsumerState<CommandPaletteChip> createState() =>
      _CommandPaletteChipState();
}

class _CommandPaletteChipState extends ConsumerState<CommandPaletteChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
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
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showCommandPalette(context, ref),
            child: AnimatedContainer(
              duration: InkMotion.fast,
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover ? colors.surface3 : colors.surface2,
                borderRadius: BorderRadius.circular(InkRadius.sm),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                commandPaletteShortcutLabel(),
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
