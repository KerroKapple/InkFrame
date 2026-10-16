// InkShell：外壳根——唯一根 Scaffold + 唯一 chrome + 持久标签条 + 内容区。
//
// 【根 Scaffold】给整个外壳一个 Material 祖先（文字输入、墨水效果都要）。通知不走它：
// 通知卡画在 MaterialApp.builder 的 ToastLayer 里、在所有路由之上（features/notifications），
// lib 里也已经没有直接弹 SnackBar 的地方（test/quality/no_direct_snackbar_test.dart 守着）。
// 画布自带的 Scaffold 原样保留；当初为 SnackBar 广播加的 V3c 用例还在
// （test/features/shell/shell_window_chrome_test.dart），只当根 Scaffold 在场的回归闸。
//
// 【画布侧的 job 监听挂在这里】CanvasJobListener（features/canvas）在 job 到终态时让 job 所在画布的节点控制器
// 重新读库。挂在外壳根、不挂在画布页里：job 是全局的，没开画布、开着别的画布时照样会落产物；任务弹层在任何
// 标签下都能开，开着时会保活 job 所在画布的节点控制器。监听要是跟着画布页挂载，画布页不在的那段时间落的产物
// 就没人让控制器失效，「定位」过去看到的还是旧节点表（test/features/shell/shell_canvas_job_listener_test.dart）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../canvas/widgets/canvas_job_listener.dart';
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
    return CanvasJobListener(
      child: Scaffold(
        backgroundColor: context.inkColors.surface0,
        body: Column(
          children: <Widget>[
            const ShellChrome(), // 31：全树唯一 InkWindowChrome（菜单栏）
            const ShellTabBar(), // 35：在 DragToMoveArea 之外（见该文件头注）；面包屑在这一行
            Expanded(child: ShellContentStack(tab: s.tab, overlay: s.overlay)),
            const ShellStatusBar(), // 23：壳级状态栏，内容随当前标签
          ],
        ),
      ),
    );
  }
}
