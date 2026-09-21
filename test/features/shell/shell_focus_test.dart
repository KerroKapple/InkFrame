// V2 端到端：焦点归属正确。
//
// 【与 canvas_shortcuts_test.dart / shell_canvas_visibility_test.dart 的分工】
//  - canvas_shortcuts_test：直接 pump CanvasShortcuts(isActive: …)，测的是
//    【那个开关本身的行为】，测不到接线。
//  - shell_canvas_visibility_test：读 CanvasShortcuts.isActive 这个字段，测的是
//    【接线接对了】，但不按任何一个键。
//  - 本文件：从外壳出发，真按 Delete / ⌘K，测的是【用户真的按下去会发生什么】。
//    三段合起来才是 V2，缺中间任何一段都能被一个变异悄悄穿过去。
//
// 【两条 Delete 断言的鉴别力，如实记录（T8 变异实测）】
// 「不可见画布不吞 Delete」由【三条互相独立、各自充分】的机制共同保证：
//   ① CanvasTab 把 isVisible 直通 CanvasShortcuts.isActive（本仓库的接线）；
//   ② IndexedStack 给非 index 子套 ExcludeFocus(excluding: true)
//      （basic.dart:4883 → visibility.dart:267，框架保证）。注意【有两层】：
//      外层 shell_content_stack.dart 的 IndexedStack 管"开浮层"，
//      内层 shell_keep_alive_host.dart 的 IndexedStack 管"切标签"；
//   ③ ShellContentStack._shellFocus 在 tab / overlay 变化时无条件夺焦，
//      把焦点从画布身上拿走（它同时还是 ⌘K 的护栏，见下面那条断言）。
//
// 因此要把这两条断言打红，必须【三重同时变异】。实测配方（照抄，别省）：
//   1. shell_content_stack.dart 的 `CanvasTab(isVisible: _isVisible(...))`
//      → `CanvasTab(isVisible: true)`
//   2. 【两处 IndexedStack 都要换成 Stack + Offstage】——
//      shell_content_stack.dart 的外层，**以及** shell_keep_alive_host.dart
//      的内层逐槽 Offstage。只换一处只摘掉一半 ExcludeFocus，跑出来仍是绿的。
//   3. shell_content_stack.dart 的 `_shellFocus.requestFocus()` → no-op
// 缺任何一条都不红（单变异、双变异都实测过：Delete 两条恒绿，只有 V2-C 会红）。
//
// 所以这两条是纵深防御断言，不是某一处实现的靶子——但它们【有靶子】，别当死
// 断言删掉：删了之后，V2 那条「切走标签后按 Delete 不会误删」在 lib/ 侧就没有
// 端到端护栏了。各机制自己的单点靶子：① 在 shell_canvas_visibility_test.dart，
// ② 是框架契约，③ 是本文件的 ⌘K 断言。第三条正向对照则护住
// CanvasShortcuts.didUpdateWidget 的 post-frame 复焦。
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

List<Override> _canvasOverrides() => <Override>[
  canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
  canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
  canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
  fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
];

/// 保活的画布离台后仍在树里 ⇒ 断言节点数必须 skipOffstage:false，
/// 否则"没被删"与"整棵子树离台"这两件完全不同的事会读出同一个结果。
Finder get _nodeCards => find.byType(NodeCard, skipOffstage: false);

void main() {
  const ProjectRef alpha = ProjectRef(id: 'p1', name: 'Alpha');
  const ShellState onCanvas = ShellState(
    tab: ShellTab.canvas,
    canvasId: 'c1',
    project: alpha,
  );

  testWidgets('V2：画布保活但不可见时，Delete 不删节点', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_a_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: onCanvas,
      extraOverrides: _canvasOverrides(),
    );
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tapShellTab(tester, ShellTab.studio); // 画布保活但离台
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();

    expect(
      _nodeCards,
      findsNWidgets(2),
      reason: '离台画布吞 Delete 会在用户看不见的界面上软删节点——这是安全问题',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('V2：浮层打开时画布不可见，Delete 不删节点且 ⌘K 仍可用', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_b_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: onCanvas,
      extraOverrides: _canvasOverrides(),
    );
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    c.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_nodeCards, findsNWidgets(2));

    // 让出的必须是画布焦点，不是把键盘整个掐死。
    await sendMeta(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump();
    expect(
      find.byType(CommandPaletteDialog),
      findsOneWidget,
      // 【本断言就是 ShellContentStack._shellFocus 的护栏】T8 实测（两次变异，
      // 输出见 task-8-report.md）：
      //   · 把 _shellFocus 的 post-frame 重夺改成 no-op → 本行红
      //   · 给它加 if (!_shellFocus.hasFocus) 守卫       → 本行同样红
      // 机理与 shell_content_stack.dart 的注释逐字吻合：开浮层那一刻画布的
      // FocusNode 尚未 unfocus，_shellFocus.hasFocus 仍为 true，守卫跳过请求；
      // 随后 IndexedStack 的 ExcludeFocus 把画布焦点掐掉，焦点向上落到
      // _ModalScopeState 的 FocusScope——它在 CommandPaletteShortcuts 之【上】，
      // ⌘K 的 CallbackShortcuts 不在按键分发链上，全 app 的 ⌘K 当场失效。
      // （CommandPaletteShortcuts 自己那个 autofocus 兜底节点只在首次挂载时
      // 生效，事后焦点掉出去它不会自动抢回来。）
      reason: '画布不可见时让出的必须只是自己的焦点，不能让焦点整个掉出外壳子树：'
          '⌘K 仍须冒泡到祖先命令面板层',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('V2 正向对照：切回画布标签后不点任何东西，Delete 直接生效', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_focus_c_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: onCanvas,
      extraOverrides: _canvasOverrides(),
    );
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tapShellTab(tester, ShellTab.studio);
    await tapShellTab(tester, ShellTab.canvas);
    await tester.pump(); // 等 post-frame 复焦

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();

    expect(
      _nodeCards,
      findsNWidgets(1),
      reason: 'ExcludeFocus 文档明说重新可见不会自动复焦——没有这条正向对照，'
          '"永远不给焦点"也能让上面两条通过',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
