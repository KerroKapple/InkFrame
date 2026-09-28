// ⌘K 面板的两条键盘 / 焦点纪律（用户 2026-09-23），在真外壳里验：
//   ① ⌘/Ctrl+↵ 撞键：面板开着时归面板；关闭后【同一次】按键不能再触发生成。
//   ② 焦点归还：Esc 关闭（没执行动作）→ 还给原持有者（CanvasShortcuts）；
//      执行了切标签的动作 → 不还，交给目标界面自己抢。
// 全外壳测试禁 pumpAndSettle（见 test/_harness/shell_app.dart）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

/// 只计数、不落盘不生成的提交控制器。
class _CountingSubmitController extends InspectorSubmitController {
  static int submits = 0;

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async {
    submits++;
  }
}

/// 一个带提示词的图像 config 节点：选中后画布底部出现提示词条（⌘↵ 生成的宿主）。
const List<CanvasNode> _shotNodes = <CanvasNode>[
  CanvasNode(
    id: 'img',
    label: 'Sunrise',
    type: CanvasNodeType.image,
    canvasId: 'c1',
    projectId: 'p1',
    position: Offset(40, 40),
    size: Size(180, 120),
    typeConfig: <String, Object?>{'prompt': 'a sunrise over the ridge'},
  ),
];

List<Override> _overrides() => <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_shotNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      inspectorSubmitControllerProvider.overrideWith(_CountingSubmitController.new),
    ];

const ShellState _onCanvas = ShellState(
  tab: ShellTab.canvas,
  canvasId: 'c1',
  project: ProjectRef(id: 'p1', name: 'Alpha'),
);

Future<void> _pumpFrames(WidgetTester tester, [int n = 4]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _ctrlEnter(WidgetTester tester) => sendCtrl(tester, LogicalKeyboardKey.enter);

String? _focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  setUp(() => _CountingSubmitController.submits = 0);

  testWidgets('⌘↵ 撞键：面板开着时归面板，关闭后同一次按键不触发生成', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_palette_enter_');
    await pumpInkShell(tester, paths: paths, initial: _onCanvas, extraOverrides: _overrides());
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).select('img');
    await _pumpFrames(tester);
    expect(find.byType(CanvasPromptBar), findsOneWidget);

    // 用户正在提示词条里打字（焦点在它的 TextField）。
    final Finder promptField = find.descendant(of: find.byType(CanvasPromptBar), matching: find.byType(TextField));
    await tester.tap(promptField);
    await _pumpFrames(tester);

    await sendCtrl(tester, LogicalKeyboardKey.keyK);
    await _pumpFrames(tester);
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(CommandPaletteDialog), matching: find.byType(TextField)), 'Sun');
    await _pumpFrames(tester);
    expect(find.text('Shots · current canvas'), findsOneWidget);

    // 面板里的 ⌘↵ = 在画布中定位：面板关闭，生成【没有】被触发。
    await _ctrlEnter(tester);
    await _pumpFrames(tester);
    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(_CountingSubmitController.submits, 0, reason: '面板消费掉的那次 ⌘↵ 不能漏给提示词条');

    // 正向对照：同一夹具下提示词条自己收到 ⌘↵ 确实会提交——否则上面的 0 没有鉴别力。
    await tester.tap(promptField);
    await _pumpFrames(tester);
    await _ctrlEnter(tester);
    await _pumpFrames(tester);
    expect(_CountingSubmitController.submits, 1);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('焦点归还 ①：Esc 关闭（没执行动作）→ 焦点回到 CanvasShortcuts', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_palette_focus_esc_');
    await pumpInkShell(tester, paths: paths, initial: _onCanvas, extraOverrides: _overrides());
    await _pumpFrames(tester);
    expect(_focusLabel(), 'CanvasShortcuts', reason: '前置：画布在台时由 CanvasShortcuts 持焦');

    await sendCtrl(tester, LogicalKeyboardKey.keyK);
    await _pumpFrames(tester);
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
    expect(_focusLabel(), isNot('CanvasShortcuts'), reason: '面板开着时焦点在它的输入框');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpFrames(tester);
    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(_focusLabel(), 'CanvasShortcuts');
    expect(readShellContainer(tester).read(shellControllerProvider).tab, ShellTab.canvas);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('焦点归还 ②：执行了切标签的动作 → 不还给画布，目标界面自己持焦', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_palette_focus_tab_');
    await pumpInkShell(tester, paths: paths, initial: _onCanvas, extraOverrides: _overrides());
    await _pumpFrames(tester);
    expect(_focusLabel(), 'CanvasShortcuts');

    await sendCtrl(tester, LogicalKeyboardKey.keyK);
    await _pumpFrames(tester);
    await tester.tap(find.text('Back to Studio'));
    await _pumpFrames(tester);

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(readShellContainer(tester).read(shellControllerProvider).tab, ShellTab.studio);
    expect(_focusLabel(), isNot('CanvasShortcuts'), reason: '离台的画布不能拿回键盘——否则 Delete 会在看不见的画布上删节点');
    expect(FocusManager.instance.primaryFocus, isNotNull, reason: '焦点不能掉出外壳（⌘K 要还能用）');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
