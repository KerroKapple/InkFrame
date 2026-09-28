// 命令面板（Screens 稿第 4 屏右）：宽 620 距顶 64；44 输入行 | 分组 24 + 行 42 | 32 提示条。
//
// 键盘：↑↓ 移动、↵ 打开、⌘/Ctrl+↵ 在画布中定位、Esc 关闭。面板开着时 ⌘/Ctrl+↵ 由面板独占
//（对话框路由持焦，画布提示词条收不到同一次按键）。
//
// 焦点归还（用户 2026-09-23）：打开前记下持焦节点；只有【没执行任何动作】关闭（Esc / 点外部）
// 才还给它，且先查 node.context != null；执行了动作就不还——动作可能切了标签 / 画布，
// 交给目标界面自己抢（CanvasShortcuts 可见时会 claimFocus）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../palette_entry.dart';
import '../palette_search.dart';

Future<void> showCommandPalette(BuildContext context, WidgetRef ref) async {
  final FocusNode? before = primaryFocus;
  final PaletteChoice? choice = await showDialog<PaletteChoice>(
    context: context,
    barrierColor: context.inkColors.scrim,
    builder: (_) => const CommandPaletteDialog(),
  );
  if (!context.mounted) return;
  if (choice == null) {
    // 没执行动作：还给原持有者（它可能已被销毁——先查 context）。
    if (before != null && before.context != null && before.canRequestFocus) before.requestFocus();
    return;
  }
  await choice.action(context, ref);
}

class CommandPaletteDialog extends ConsumerStatefulWidget {
  const CommandPaletteDialog({super.key});

  static const double width = 620;
  static const double top = 64;

  @override
  ConsumerState<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta, int n) {
    if (n == 0) return;
    setState(() => _selected = (_selected + delta + n) % n);
  }

  void _choose(List<PaletteEntry> entries, {required bool locate}) {
    if (entries.isEmpty) return;
    final PaletteEntry e = entries[_selected.clamp(0, entries.length - 1)];
    Navigator.of(context).pop(PaletteChoice(e, locate: locate));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.inkColors;
    final t = context.inkTypography;
    final List<PaletteEntry> entries = buildPaletteEntries(context, ref, _controller.text);
    final int selectedIndex = entries.isEmpty ? 0 : _selected.clamp(0, entries.length - 1);

    // 分组顺序固定：镜头 → 产物 → 动作。
    final List<Widget> body = <Widget>[];
    int flat = 0;
    for (final PaletteGroup g in PaletteGroup.values) {
      final List<PaletteEntry> rows = entries.where((PaletteEntry e) => e.group == g).toList();
      if (rows.isEmpty) continue;
      body.add(_GroupHeader(title: switch (g) {
        PaletteGroup.shots => l.commandPaletteGroupShots,
        PaletteGroup.artifacts => l.commandPaletteGroupArtifacts,
        PaletteGroup.actions => l.commandPaletteGroupActions,
      }));
      for (final PaletteEntry e in rows) {
        final int i = flat++;
        body.add(_EntryRow(
          entry: e,
          selected: i == selectedIndex,
          hint: i == selectedIndex ? '↵' : '',
          onHover: () => setState(() => _selected = i),
          onTap: () => Navigator.of(context).pop(PaletteChoice(e)),
        ));
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: CommandPaletteDialog.top, left: InkSpacing.xl, right: InkSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CommandPaletteDialog.width),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, entries.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, entries.length),
            const SingleActivator(LogicalKeyboardKey.enter): () => _choose(entries, locate: false),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () => _choose(entries, locate: false),
            // 面板开着时 ⌘/Ctrl+↵ 归面板：定位（没有定位的条目退回打开）。
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => _choose(entries, locate: true),
            const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _choose(entries, locate: true),
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
          },
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface4,
              border: Border.all(color: c.overlayBorder),
              borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
              boxShadow: InkShadow.overlay,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 稿：44 高 + 1px 下沿；⌘K（琥珀等宽）| 查询 | N 条结果。
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSubtle))),
                  child: Row(
                    children: <Widget>[
                      Text(commandPaletteShortcutLabel(), style: t.mono.copyWith(color: c.accent)),
                      const SizedBox(width: InkSpacing.s10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          style: t.body.copyWith(color: c.fg1),
                          cursorColor: c.accent,
                          cursorWidth: 1,
                          decoration: InputDecoration.collapsed(
                            hintText: l.commandPaletteSearchHint,
                            hintStyle: t.body.copyWith(color: c.fg6),
                          ),
                          onChanged: (_) => setState(() => _selected = 0),
                        ),
                      ),
                      const SizedBox(width: InkSpacing.s10),
                      Text(l.commandPaletteResultCount(entries.length), style: t.meta.copyWith(color: c.fg6)),
                    ],
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(InkSpacing.md),
                    child: Text(l.commandPaletteNoResults, style: t.meta.copyWith(color: c.fg3)),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
                    ),
                  ),
                // 稿：32 高提示条，surface3 底 + 1px 上沿，10px fg6。
                Container(
                  height: 33,
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
                  decoration: BoxDecoration(
                    color: c.surface3,
                    border: Border(top: BorderSide(color: c.borderSubtle)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(l.commandPaletteHintMove, style: t.micro.copyWith(color: c.fg6)),
                      const SizedBox(width: InkSpacing.s14),
                      Text(l.commandPaletteHintOpen, style: t.micro.copyWith(color: c.fg6)),
                      const SizedBox(width: InkSpacing.s14),
                      Text(l.commandPaletteHintLocate(submitShortcutLabel()), style: t.micro.copyWith(color: c.fg6)),
                      const Spacer(),
                      Text(l.commandPaletteHintClose, style: t.micro.copyWith(color: c.fg6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 稿：24 高 surface3 底，10px fg6，letter-spacing .6。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      color: c.surface3,
      alignment: Alignment.centerLeft,
      child: Text(title, style: t.micro.copyWith(color: c.fg6, letterSpacing: 0.6)),
    );
  }
}

/// 稿：行 content-box 34 + padding 4×2 = 42；28×18 缩略图 | 名称 + 10px 路径 | 等宽提示。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.selected,
    required this.hint,
    required this.onHover,
    required this.onTap,
  });

  final PaletteEntry entry;
  final bool selected;
  final String hint;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.xs),
          color: selected ? c.surface5 : null,
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 18,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.surface4,
                  borderRadius: BorderRadius.circular(InkRadius.xs),
                ),
                child: entry.thumbFile != null
                    ? Image.file(entry.thumbFile!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                    : entry.icon != null
                        ? Icon(entry.icon, size: 14, color: selected ? c.accent : c.fg4)
                        : null,
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(color: selected ? c.fg1 : c.fg2)),
                    Text(entry.path, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.micro.copyWith(color: c.fg6, height: 1.45)),
                  ],
                ),
              ),
              if (hint.isNotEmpty) ...<Widget>[
                const SizedBox(width: InkSpacing.s12),
                Text(hint, style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
