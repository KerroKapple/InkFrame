// InkShell：外壳根——唯一根 Scaffold + 唯一 chrome + 持久标签条 + 内容区。
//
// 【根 Scaffold 的理由】ToastService 走 MaterialApp.scaffoldMessengerKey 的单
// messenger，而 ScaffoldMessengerState._updateScaffolds 对【每个 root Scaffold】
// 都推一份 SnackBar。保活之后画布与 Studio 自带的 Scaffold 是 IndexedStack 里的
// 兄弟，两个都算 root ⇒ 一条 toast 渲染两份；而激活序列/导出标签（无 Scaffold）
// 时 toast 全画在离台子树里，用户根本看不见。
// 修法：外壳持一个根 Scaffold，画布与设置自带的 Scaffold【原样保留】，它们因为
// 有了 Scaffold 祖先而变成 nested，_isRoot 返回 false，被自动排除出广播。
// V3b 钉死它（test/features/shell/shell_window_chrome_test.dart）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';
import 'shell_chrome.dart';
import 'shell_content_stack.dart';
import 'shell_tab_bar.dart';

class InkShell extends ConsumerWidget {
  const InkShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState s = ref.watch(shellControllerProvider);
    return Scaffold(
      backgroundColor: context.inkColors.surfaceCanvas,
      body: Column(
        children: <Widget>[
          const ShellChrome(), // 56：全树唯一 InkWindowChrome
          const ShellTabBar(), // 44：在 DragToMoveArea 之外（见该文件头注）
          Expanded(child: ShellContentStack(tab: s.tab, overlay: s.overlay)),
        ],
      ),
    );
  }
}
