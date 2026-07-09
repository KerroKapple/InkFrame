// CommandPaletteShortcuts：app 级 ⌘K / Ctrl+K 绑定（PL-1）。
//
// 挂在 _UnlockedShell 外层，studio / canvas / gallery / settings 全路由生效。
// dialog 路由是 Navigator overlay 的兄弟子树、不在本 widget 的 focus 链上，
// 面板打开期间 ⌘K 不会重复触发。带修饰键，不与输入框普通输入冲突。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'command_palette_dialog.dart';

class CommandPaletteShortcuts extends ConsumerWidget {
  const CommandPaletteShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() {
      showCommandPalette(context, ref);
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): open,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): open,
      },
      // 兜底焦点节点：无其他焦点时键盘事件也能进入本子树（不参与 Tab 遍历）。
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: child,
      ),
    );
  }
}
