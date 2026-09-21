// spec §7.3 的最后一句：「标签条在浮层打开时仍可见、仍可点（点任一标签 =
// goTab = 关浮层 + 切标签）」——fix round 18（R90）补上的 widget 级护栏。
//
// 为什么它值一条用例：这是 **D11（浮层刻意不做 Esc 关闭）赖以成立的三条关闭
// 途径之一**（另两条是工具条返回键与 ⌘K）。D11 拿"关闭途径够用"当论据，那论据
// 就该有断言，而不是只靠"标签条是 ShellContentStack 在 Column 里的兄弟、不在
// IndexedStack 内"这条结构推理。
//
// 结构上确实成立、风险不高——所以本文件只有一条用例，不铺开。
//
// 【实跑的变异证明】两条，各打一半：
// - M4a `ink_shell.dart` 把标签条改成 `if (s.overlay == null) const ShellTabBar()`
//   → :34 红（Found 0 widgets with key <'shellTab-gallery'>）。守住"仍可见"。
// - M4b `ShellState.goTab` 改成 `ShellState(tab: next, overlay: overlay, ...)`
//   （即切标签不再关浮层）→ :44 红（Expected null, Actual ShellOverlay.settings）。
//   守住"点了 = 关浮层"。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';

import '../../_harness/shell_app.dart';

void main() {
  testWidgets('浮层打开时标签条仍可见、仍可点：点标签 = 关浮层 + 切标签',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_tabbar_overlay_');
    await pumpInkShell(
      tester,
      paths: paths,
      // 设置浮层盖在画布之上——最真实的那一种：用户开着画布点了 ⚙。
      initial: const ShellState(
        tab: ShellTab.canvas,
        canvasId: 'cv-1',
        overlay: ShellOverlay.settings,
      ),
    );

    // 仍【可见】：skipOffstage 用默认的 true——若标签条被挪进内容区（那才是
    // 真正的回归形态），它会随标签宿主一起离台，这条当场红。
    expect(
      find.byKey(ShellTabBar.keyOf(ShellTab.gallery)),
      findsOneWidget,
      reason: '浮层盖住标签条 ⇒ D11 的三条关闭途径少一条，Esc 又刻意不做',
    );

    // 仍【可点】，且点了是 goTab：关浮层 + 切标签，一次到位。
    await tapShellTab(tester, ShellTab.gallery);

    final ShellState s = readShellContainer(tester).read(shellControllerProvider);
    expect(s.overlay, isNull, reason: '点标签必须顺带关掉浮层，否则用户被困在设置里');
    expect(s.tab, ShellTab.gallery);
    // 关浮层不等于关画布：保活的 canvasId 一动不动。
    expect(s.canvasId, 'cv-1');
  }, timeout: const Timeout(Duration(seconds: 15)));
}
