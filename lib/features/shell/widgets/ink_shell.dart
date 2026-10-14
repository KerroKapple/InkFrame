// InkShell：外壳根——唯一根 Scaffold + 唯一 chrome + 持久标签条 + 内容区。
//
// 【根 Scaffold】给整个外壳一个 Material 祖先（文字输入、墨水效果都要）。通知不走它：
// 通知卡画在 MaterialApp.builder 的 ToastLayer 里、在所有路由之上（features/notifications），
// lib 里也已经没有直接弹 SnackBar 的地方（test/quality/no_direct_snackbar_test.dart 守着）。
// 画布自带的 Scaffold 原样保留；当初为 SnackBar 广播加的 V3c 用例还在
// （test/features/shell/shell_window_chrome_test.dart），只当根 Scaffold 在场的回归闸。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';
import 'shell_chrome.dart';
import 'shell_content_stack.dart';
import 'shell_status_bar.dart';
import 'shell_tab_bar.dart';

class InkShell extends ConsumerWidget {
  const InkShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState s = ref.watch(shellControllerProvider);
    return Scaffold(
      backgroundColor: context.inkColors.surface0,
      body: Column(
        children: <Widget>[
          const ShellChrome(), // 31：全树唯一 InkWindowChrome（菜单栏）
          const ShellTabBar(), // 35：在 DragToMoveArea 之外（见该文件头注）；面包屑在这一行
          Expanded(child: ShellContentStack(tab: s.tab, overlay: s.overlay)),
          const ShellStatusBar(), // 23：壳级状态栏，内容随当前标签
        ],
      ),
    );
  }
}
