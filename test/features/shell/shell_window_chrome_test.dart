// V3：全树唯一窗口 chrome；通知卡恰好一份、在台、点得到；外壳仍持唯一根 Scaffold。
//
// 三组必须【分开】：只测 chrome 唯一的话，「去掉外壳根 Scaffold」这个变异会照绿；
// 只测通知卡的话，「把 chrome 加回画布子树」那个变异会照绿。通知卡早已不走
// ScaffoldMessenger（画在 MaterialApp.builder 的 ToastLayer 里，在所有路由之上），
// 所以根 Scaffold 那一半改由 V3c 守：仓库里仍有调用点直接
// ScaffoldMessenger.of(context).showSnackBar（画廊动作等）。
//
// V3a 同时断两个现象——窗口控件唯一（重复的最小化/关闭按钮是用户直接看得见的
// 那一半）与 InkWindowChrome 唯一（结构上的那一半）。只断后者的话，有人把
// _WindowButtons 单独多挂一份就打不中了。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/widgets/ink_shell.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';

import '../../_harness/shell_app.dart';

void main() {
  testWidgets('V3a：两个标签都物化后，全树仍恰好一个 InkWindowChrome + 一组窗口控件',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_chrome_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'),
    );
    await tapShellTab(tester, ShellTab.studio); // 让 Studio 也物化

    expect(
      find.byType(InkWindowChrome, skipOffstage: false),
      findsOneWidget,
      reason: '两个标签都物化后仍只能有一个窗口 chrome',
    );
    // 用户看得见的那一半：关闭键只能有一个（测试平台非 macOS ⇒ 自绘三键在场）。
    expect(
      find.byIcon(Icons.close, skipOffstage: false),
      findsOneWidget,
      reason: '重复的窗口控件 = 两套最小化/最大化/关闭',
    );
    expect(
      find.byIcon(Icons.remove, skipOffstage: false),
      findsOneWidget,
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // V3b 断【在台 + 可命中】而不只是【在树】：通知卡要是挂在某个标签的子树里，
  // 切走那个标签它就跟着离台；挂在路由里，设置浮层的遮罩就盖住它。
  testWidgets('V3b-1：激活无 Scaffold 的标签时，通知卡仍在台上、点得到', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_toast_onstage_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'),
    );
    // 序列标签自己不带 Scaffold；切过去之后画布（唯一自带 Scaffold 的标签）离台。
    await tapShellTab(tester, ShellTab.sequence);

    readShellContainer(tester).read(toastServiceProvider).show('hello');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('hello'), findsOneWidget, reason: '在台');
    expect(find.text('hello').hitTestable(), findsOneWidget, reason: '没被任何东西盖住');
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('V3b-2：画布标签 + 设置浮层同时在树时，一条通知只画一份，且在浮层遮罩之上',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_toast_single_');
    await pumpInkShell(
      tester,
      paths: paths,
      // 画布保活在下，设置浮层（ModalBarrier 遮罩）盖在上。
      initial: const ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.settings,
        canvasId: 'c1',
      ),
    );

    readShellContainer(tester).read(toastServiceProvider).show('hello');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('hello', skipOffstage: false), findsOneWidget, reason: '只画一份');
    expect(
      find.text('hello').hitTestable(),
      findsOneWidget,
      reason: '通知卡层在 Navigator 之上，浮层的 ModalBarrier 挡不住它',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // V3c：根 Scaffold 那一半。只断「唯一」是假绿：今天全树只有 CanvasScreen 自带
  // Scaffold——去掉外壳根 Scaffold 后，画布就成了唯一的 root Scaffold，SnackBar 仍然
  // 只有一份，但画在离台的画布子树里，用户根本看不见。所以断的是【在台】。
  testWidgets('V3c：直调 ScaffoldMessenger 的 SnackBar——激活无 Scaffold 的标签时仍在台上、只一份',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_snackbar_onstage_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'),
    );
    await tapShellTab(tester, ShellTab.sequence);

    ScaffoldMessenger.of(tester.element(find.byType(InkShell)))
        .showSnackBar(const SnackBar(content: Text('snack')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byType(SnackBar, skipOffstage: false),
      findsOneWidget,
      reason: 'ScaffoldMessenger 对每个 root Scaffold 都推一份；外壳根 Scaffold '
          '让画布自带的 Scaffold 变 nested 而被排除出广播',
    );
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: '没有外壳根 Scaffold 时，唯一的 root Scaffold 是离台的画布 ⇒ '
          'SnackBar 画在离台子树里，用户根本看不见',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
