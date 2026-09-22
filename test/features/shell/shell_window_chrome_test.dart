// V3：全树唯一窗口 chrome + 唯一根 Scaffold。
//
// 两条必须【分开】：只测 chrome 唯一的话，「去掉外壳根 Scaffold」这个变异会照绿；
// 只测 toast 单渲染的话，「把 chrome 加回画布子树」那个变异会照绿。
//
// V3a 同时断两个现象——窗口控件唯一（重复的最小化/关闭按钮是用户直接看得见的
// 那一半）与 InkWindowChrome 唯一（结构上的那一半）。只断后者的话，有人把
// _WindowButtons 单独多挂一份就打不中了。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
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

  // V3b 必须断【在台】而不只是【唯一】。
  //
  // 只断唯一是假绿：今天全树只有 CanvasScreen 与 SettingsScreen 自带 Scaffold，
  // StudioHomeScreen 是裸 ColoredBox——去掉外壳根 Scaffold 后，"画布 + Studio
  // 都物化"这个场景里 root Scaffold 仍然只有一个（画布的），SnackBar 还是一份，
  // 断言照绿。真正的回归是另一半：root Scaffold 落在某个【离台】子树里时，
  // toast 画在用户看不见的地方。
  testWidgets('V3b-1：激活无 Scaffold 的标签时，toast 仍在台上', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: '没有外壳根 Scaffold 时，唯一的 root Scaffold 是离台的画布 ⇒ '
          'toast 画在离台子树里，用户根本看不见',
    );
    expect(find.text('hello'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('V3b-2：画布标签 + 设置浮层同时在树时，一条 toast 只渲染一份',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_toast_single_');
    await pumpInkShell(
      tester,
      paths: paths,
      // 画布（自带 Scaffold）保活在下，设置浮层（自带 Scaffold）盖在上
      // ——全树仅有的两个 Scaffold 同时在场。
      initial: const ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.settings,
        canvasId: 'c1',
      ),
    );

    readShellContainer(tester).read(toastServiceProvider).show('hello');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byType(SnackBar, skipOffstage: false),
      findsOneWidget,
      reason: 'ScaffoldMessenger 对每个 root Scaffold 都推一份；外壳根 Scaffold '
          '让画布/设置自带的 Scaffold 变 nested 而被排除出广播',
    );
    expect(find.byType(SnackBar), findsOneWidget, reason: '那一份还得在台上');
  }, timeout: const Timeout(Duration(seconds: 10)));
}
