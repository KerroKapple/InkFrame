// InkShell：外壳根——唯一根 Scaffold + 唯一 chrome + 持久标签条 + 内容区。
//
// 【根 Scaffold 的理由】通知卡（ToastService）已经不走 ScaffoldMessenger——它画在
// MaterialApp.builder 的 ToastLayer 里，在所有路由之上（features/notifications）。
// 但仍有少数调用点直接 ScaffoldMessenger.of(context).showSnackBar（画廊动作等），
// 而 ScaffoldMessengerState._updateScaffolds 对【每个 root Scaffold】都推一份
// SnackBar。保活之后画布自带的 Scaffold 是 IndexedStack 里的一个子：没有外壳根
// Scaffold 时它就是唯一的 root ⇒ 激活序列/导出标签（无 Scaffold）时 SnackBar 全画在
// 离台的画布子树里，用户根本看不见。
// 修法：外壳持一个根 Scaffold，画布自带的 Scaffold【原样保留】，它因为有了 Scaffold
// 祖先而变成 nested，_isRoot 返回 false，被自动排除出广播。
// V3c 钉死它（test/features/shell/shell_window_chrome_test.dart）。
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
