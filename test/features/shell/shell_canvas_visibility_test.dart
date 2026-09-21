// 外壳 → 画布的可见性接线（T1 的安全修复在 T7 才真正通电）。
//
// T1 给了 CanvasShortcuts 一个 isActive 开关并单测了它的行为，但 app.dart 当时
// 传的是常量 true。真正的漏洞（不可见的画布吞掉 Delete / Backspace / Esc / ⌘A）
// 只有在接线接对了之后才关上，而 canvas_shortcuts_test.dart 直接 pump
// CanvasShortcuts(isActive: false)，【测不到接线】——把 CanvasTab 改回
// `CanvasScreen(isVisible: true)` 那个变异在全量测试下零红。本文件补上那一刀。
//
// 两条不可见都必须覆盖，且必须走同一个谓词（ShellState.isTabVisible）：
// ① 切走标签  ② 浮层盖住。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/shell_app.dart';

bool _canvasShortcutsActive(WidgetTester tester) =>
    tester
        .widget<CanvasShortcuts>(
          find.byType(CanvasShortcuts, skipOffstage: false),
        )
        .isActive;

void main() {
  testWidgets('画布标签在台 → CanvasShortcuts.isActive = true', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_canvas_vis_on_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );

    expect(_canvasShortcutsActive(tester), isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('切走标签 → 保活的画布交出快捷键（isActive = false）', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_canvas_vis_tab_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );

    readShellContainer(tester)
        .read(shellControllerProvider.notifier)
        .goTab(ShellTab.studio);
    await tester.pump();
    await tester.pump();

    // 画布仍在树里（保活），但不再是可见标签 ⇒ 不许再吞 Delete。
    expect(
      find.byType(CanvasShortcuts, skipOffstage: false),
      findsOneWidget,
      reason: '画布被销毁的话本用例就测不到接线了——先确认它还活着',
    );
    expect(_canvasShortcutsActive(tester), isFalse);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('浮层盖住 → 画布同样交出快捷键（同一个谓词）', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_canvas_vis_overlay_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );
    expect(_canvasShortcutsActive(tester), isTrue);

    readShellContainer(tester)
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.showcase);
    await tester.pump();
    await tester.pump();

    expect(_canvasShortcutsActive(tester), isFalse);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
