// CommandPaletteDialog：⌘K 搜索式命令面板（PL-1）。
//
// 键盘：↑/↓ 选择、Enter 执行、Esc 关闭；鼠标 hover 选中、点击执行。
// 选中项以 Navigator.pop(action) 返回，执行由 showCommandPalette 在
// 打开方 context 上完成——避免在已销毁的 dialog context 上导航/弹窗。
// CallbackShortcuts 位于搜索框与 app 根之间：↑/↓/Enter 先于
// DefaultTextEditingShortcuts 被拦截，搜索框正常输入不受影响。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_compact_text_field.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';
import '../command_actions.dart';

/// 打开命令面板；用户选中动作后在 [context]/[ref] 上执行。
Future<void> showCommandPalette(BuildContext context, WidgetRef ref) async {
  final actions = buildCommandActions(context, ref);
  final selected = await showDialog<CommandAction>(
    context: context,
    barrierColor: context.inkColors.scrim,
    builder: (_) => CommandPaletteDialog(actions: actions),
  );
  if (selected == null || !context.mounted) return;
  await selected.run(context, ref);
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key, required this.actions});

  final List<CommandAction> actions;

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CommandAction> get _filtered {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return widget.actions;
    return <CommandAction>[
      for (final a in widget.actions)
        if (a.label.toLowerCase().contains(q)) a,
    ];
  }

  void _move(int delta) {
    final n = _filtered.length;
    if (n == 0) return;
    setState(() => _selected = (_selected + delta + n) % n);
  }

  void _submit() {
    final list = _filtered;
    if (list.isEmpty) return;
    Navigator.of(context).pop(list[_selected.clamp(0, list.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final filtered = _filtered;
    final selectedIndex =
        filtered.isEmpty ? 0 : _selected.clamp(0, filtered.length - 1);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.xl,
        vertical: InkSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _move(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _move(-1),
            const SingleActivator(LogicalKeyboardKey.enter): _submit,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(),
          },
          child: InkNoirCard(
            padding: const EdgeInsets.all(InkSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkCompactTextField(
                  controller: _controller,
                  placeholder: l.commandPaletteSearchHint,
                  autofocus: true,
                  onChanged: (_) => setState(() => _selected = 0),
                ),
                const SizedBox(height: InkSpacing.sm),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(InkSpacing.sm),
                    child: Text(
                      l.commandPaletteNoResults,
                      style: typo.caption.copyWith(color: colors.fg3),
                    ),
                  )
                else
                  for (var i = 0; i < filtered.length; i++)
                    _ActionRow(
                      action: filtered[i],
                      selected: i == selectedIndex,
                      onHover: () => setState(() => _selected = i),
                      onTap: () => Navigator.of(context).pop(filtered[i]),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final CommandAction action;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: InkMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.sm,
            vertical: InkSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(InkRadius.sm),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                action.icon,
                size: 16,
                color: selected ? colors.accent : colors.fg2,
              ),
              const SizedBox(width: InkSpacing.sm),
              Expanded(
                child: Text(
                  action.label,
                  style: typo.body.copyWith(
                    color: selected ? colors.fg1 : colors.fg2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
