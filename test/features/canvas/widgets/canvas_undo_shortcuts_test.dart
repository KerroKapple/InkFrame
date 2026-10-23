// 画布撤销 / 重做快捷键（shortcuts/undo_keys.dart）：Windows Ctrl Z · Ctrl Y，macOS ⌘Z · ⇧⌘Z；文本框有焦点时让位。
//
// 装置照 canvas_shortcuts_test.dart 的 _pump：CommandPaletteShortcuts > CanvasShortcuts > CanvasView，节点 'a' / 'b'。
// 撤销栈里预先登记两步脚本命令：A（受影响 'a'）、B（受影响 'b'），日志记 'revert:<名>' / 'apply:<名>'。
// CanvasView 不挂胶囊宿主、胶囊 provider 是 autoDispose：按键前先 container.listen 保活，才读得回来。
// 平台用 TargetPlatformVariant 切（框架在用例前后自己设 / 复位 debugDefaultTargetPlatformOverride）。
//
// 变异对照：
// - undo_keys.dart 两条绑定的 gate 改成 CanvasKeyGate.always ⇒「文本框有焦点时 Ctrl+Z 归文本框」红；
// - canvasRedo 的 PlannedKeys.redoOther 换成手写的 Ctrl+Shift+Z ⇒「Windows：Ctrl+Y 重做」「Windows：Ctrl+Shift+Z 不重做」红；
// - 删掉 done 分支的胶囊 ⇒「撤销后选中受影响节点、出 Undone · <步名> 胶囊」红；
// - failed 分支改成出胶囊 ⇒「revert 返回 failed ⇒ 出 Couldn't undo 错误卡」红。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_canvas_command.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _c1 = 'c1';

List<Override> _overrides() => <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: _c1)),
      ),
      canvasNodesControllerProvider
          .overrideWith(() => RecordingNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ];

typedef _Rig = ({ProviderContainer container, List<String> log});

/// 挂画布、给胶囊挂订阅、往撤销栈里登记 A、B 两步（B 的撤销脚本 = [revertB]）。
/// [around] 把画布包一层（文本框让位用例往子树里放一个 TextField）。
Future<_Rig> _pump(
  WidgetTester tester, {
  List<Object> revertB = const <Object>[],
  Widget Function(Widget canvas)? around,
}) async {
  const Widget canvas = CanvasView();
  await pumpInkApp(
    tester,
    Scaffold(
      body: CommandPaletteShortcuts(
        child: CanvasShortcuts(
          isActive: true,
          child: around == null ? canvas : around(canvas),
        ),
      ),
    ),
    overrides: _overrides(),
  );
  await tester.pumpAndSettle();
  final ProviderContainer container =
      ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
  container.listen(canvasCapsuleProvider(_c1), (_, _) {});
  final List<String> log = <String>[];
  final CanvasHistoryController history =
      container.read(canvasHistoryControllerProvider(_c1).notifier);
  history.record(
    ScriptedCanvasCommand('A', log: log, affectedNodeIds: <String>{'a'}),
  );
  history.record(
    ScriptedCanvasCommand(
      'B',
      log: log,
      affectedNodeIds: <String>{'b'},
      revertScript: revertB,
    ),
  );
  return (container: container, log: log);
}

/// 按住修饰键按 [key]（修饰键按下序：Ctrl / ⌘ 在前，Shift 在后；松开反序），然后等撤销的异步链走完。
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool meta = false,
  bool shift = false,
}) async {
  final List<LogicalKeyboardKey> modifiers = <LogicalKeyboardKey>[
    if (control) LogicalKeyboardKey.controlLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final LogicalKeyboardKey m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final LogicalKeyboardKey m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pumpAndSettle();
}

CanvasHistoryState _history(ProviderContainer c) =>
    c.read(canvasHistoryControllerProvider(_c1));

void main() {
  testWidgets(
    'Windows：Ctrl+Z 撤销栈顶一步',
    (tester) async {
      final _Rig rig = await _pump(tester);

      await _press(tester, LogicalKeyboardKey.keyZ, control: true);

      expect(rig.log, <String>['revert:B']);
      expect(_history(rig.container).undo, hasLength(1));
      expect(_history(rig.container).redo, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Windows：Ctrl+Y 重做',
    (tester) async {
      final _Rig rig = await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(rig.log, <String>['revert:B'], reason: '前提：先撤销一步');

      await _press(tester, LogicalKeyboardKey.keyY, control: true);

      expect(rig.log, <String>['revert:B', 'apply:B']);
      expect(_history(rig.container).redo, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Windows：Ctrl+Shift+Z 不重做（也不撤销）',
    (tester) async {
      final _Rig rig = await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(rig.log, <String>['revert:B'], reason: '前提：redo 栈里有一步');

      await _press(tester, LogicalKeyboardKey.keyZ, control: true, shift: true);

      expect(rig.log, <String>['revert:B'], reason: '既没有 apply: 也没有新的 revert:');
      expect(_history(rig.container).redo, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'macOS：⌘Z 撤销、⇧⌘Z 重做',
    (tester) async {
      final _Rig rig = await _pump(tester);

      await _press(tester, LogicalKeyboardKey.keyZ, meta: true);
      expect(rig.log, <String>['revert:B']);

      await _press(tester, LogicalKeyboardKey.keyZ, meta: true, shift: true);
      expect(rig.log, <String>['revert:B', 'apply:B']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'macOS：⌘Y 不重做',
    (tester) async {
      final _Rig rig = await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyZ, meta: true);
      expect(rig.log, <String>['revert:B'], reason: '前提：redo 栈里有一步');

      await _press(tester, LogicalKeyboardKey.keyY, meta: true);

      expect(rig.log, <String>['revert:B']);
      expect(_history(rig.container).redo, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('文本框有焦点时 Ctrl+Z 归文本框：画布栈不动', (tester) async {
    final TextEditingController field = TextEditingController();
    addTearDown(field.dispose);
    final _Rig rig = await _pump(
      tester,
      around: (Widget canvas) => Column(
        children: <Widget>[
          Expanded(child: canvas),
          // 检查器文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
          TextField(controller: field),
        ],
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue, reason: '前提：主焦点在 EditableText 里');

    await _press(tester, LogicalKeyboardKey.keyZ, control: true);
    await _press(tester, LogicalKeyboardKey.keyY, control: true);

    expect(rig.log, isEmpty, reason: '画布不消费 Ctrl+Z / Ctrl+Y');
    expect(_history(rig.container).undo, hasLength(2));
    expect(_history(rig.container).redo, isEmpty);
  });

  testWidgets('撤销后选中受影响节点、出「Undone · <步名>」胶囊（带 Redo + 本平台重做键）', (tester) async {
    final _Rig rig = await _pump(tester);
    rig.container
        .read(canvasSelectionControllerProvider(_c1).notifier)
        .select('a');
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.keyZ, control: true);

    expect(rig.container.read(canvasSelectionControllerProvider(_c1)), <String>{'b'});
    final CanvasCapsuleMessage? m = rig.container.read(canvasCapsuleProvider(_c1));
    expect(m, isNotNull);
    expect(m!.text, 'Undone · B');
    expect(m.actionLabel, 'Redo');
    expect(m.actionHint, 'Ctrl+Y', reason: 'flutter_test 缺省平台不是 macOS');
  });

  testWidgets("revert 返回 failed ⇒ 出 Couldn't undo 错误卡，栈顶不变", (tester) async {
    final _Rig rig = await _pump(
      tester,
      revertB: <Object>[CanvasCommandOutcome.failed],
    );

    await _press(tester, LogicalKeyboardKey.keyZ, control: true);

    final RecordingToastService toasts =
        rig.container.read(toastServiceProvider) as RecordingToastService;
    expect(toasts.titles, <String>["Couldn't undo"]);
    expect(toasts.kinds, <ToastKind>[ToastKind.error]);
    expect(rig.container.read(canvasCapsuleProvider(_c1)), isNull);
    expect(
      _history(rig.container).undo.last.command,
      isA<ScriptedCanvasCommand>()
          .having((ScriptedCanvasCommand c) => c.name, 'name', 'B'),
      reason: '那一步仍在栈顶',
    );
  });

  testWidgets('gone ⇒ 胶囊 This step can no longer be undone', (tester) async {
    final _Rig rig = await _pump(
      tester,
      revertB: <Object>[CanvasCommandOutcome.gone],
    );

    await _press(tester, LogicalKeyboardKey.keyZ, control: true);

    expect(
      rig.container.read(canvasCapsuleProvider(_c1))?.text,
      'This step can no longer be undone',
    );
    final RecordingToastService toasts =
        rig.container.read(toastServiceProvider) as RecordingToastService;
    expect(toasts.shown, isEmpty);
    expect(rig.log, <String>['revert:B'], reason: '不连带撤下一步');
  });
}
