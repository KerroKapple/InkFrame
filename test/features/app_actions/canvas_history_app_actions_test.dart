// 动作表的撤销 / 重做两行（canvas/util/canvas_history_actions.dart 的 canvasHistoryAppActions，接进 kAppActions 的「编辑」段）。
//
// 装置照 app_action_catalog_test.dart 的 _pump：Consumer 交出 context / ref，AppActionContext.read(context, ref)。
// 节点控制器先挂订阅预热（生产里 CanvasScreen 常驻 watch）。
//
// 变异对照：
// - isEnabled 改成恒 true ⇒「画布上、栈空 ⇒ 灰着」红；
// - 删掉 inPalette ⇒「栈里有一步 ⇒ buildCommandActions 含 undo」红；
// - busy 时 disabledReason 返回 null（与 isEnabled 走岔）⇒「撤销在途 ⇒ isEnabled false 且原因非 null」红；
// - macKey / otherKey 另抄一份 SingleActivator ⇒「与 PlannedKeys 是同一对象」红。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/app_actions/app_action.dart';
import 'package:inkframe/features/app_actions/app_action_catalog.dart';
import 'package:inkframe/features/app_actions/app_action_ids.dart';
import 'package:inkframe/features/app_actions/planned_keys.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/command_palette/command_actions.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/fake_canvas_command.dart';
import '../../_harness/test_app.dart';

const String _c1 = 'c1';
const ProjectRef _project = ProjectRef(id: 'p1', name: 'Alpha');

const ShellState _onCanvas =
    ShellState(tab: ShellTab.canvas, canvasId: _c1, project: _project);
const ShellState _studio = ShellState();

class _Rig {
  _Rig(this.context, this.ref, this.container);

  final BuildContext context;
  final WidgetRef ref;
  final ProviderContainer container;

  AppLocalizations get l => AppLocalizations.of(context);

  AppActionContext get c => AppActionContext.read(context, ref);

  CanvasHistoryController get history =>
      container.read(canvasHistoryControllerProvider(_c1).notifier);

  List<String> get paletteIds => buildCommandActions(context, ref)
      .map((CommandAction a) => a.id)
      .toList();
}

Future<_Rig> _pump(WidgetTester tester, ShellState shell) async {
  late BuildContext captured;
  late WidgetRef capturedRef;
  await pumpInkApp(
    tester,
    Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        captured = context;
        capturedRef = ref;
        return const SizedBox.shrink();
      },
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: shell)),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
    ],
  );
  final ProviderContainer container = ProviderScope.containerOf(captured);
  container.listen(canvasNodesControllerProvider(_c1), (_, _) {});
  container.listen(canvasSelectionControllerProvider(_c1), (_, _) {});
  await container.read(canvasNodesControllerProvider(_c1).future);
  return _Rig(captured, capturedRef, container);
}

AppAction _row(String id) {
  final AppAction? a = appActionById(id);
  expect(a, isNotNull, reason: '动作表里没有 $id');
  return a!;
}

void main() {
  testWidgets('画布上、栈空 ⇒ 两行可见但灰着，原因 Nothing to undo / Nothing to redo', (tester) async {
    final _Rig rig = await _pump(tester, _onCanvas);
    final AppAction undo = _row(AppActionIds.undo);
    final AppAction redo = _row(AppActionIds.redo);

    expect(undo.isAvailable(rig.c), isTrue);
    expect(undo.isEnabled(rig.c), isFalse);
    expect(undo.disabledReason(rig.c, rig.l), 'Nothing to undo');
    expect(redo.isAvailable(rig.c), isTrue);
    expect(redo.isEnabled(rig.c), isFalse);
    expect(redo.disabledReason(rig.c, rig.l), 'Nothing to redo');
    expect(undo.labelFor(rig.c, rig.l), 'Undo');
    expect(redo.labelFor(rig.c, rig.l), 'Redo');
  });

  // 主 Agent 决定 1：不在画布上与动作表画布行同一约定——灰着不藏，原因「先打开一个画布」。
  testWidgets('不在画布标签 ⇒ 灰着不藏，原因 Open a canvas first', (tester) async {
    final _Rig rig = await _pump(tester, _studio);
    for (final String id in <String>[AppActionIds.undo, AppActionIds.redo]) {
      final AppAction a = _row(id);
      expect(a.isAvailable(rig.c), isTrue, reason: id);
      expect(a.isEnabled(rig.c), isFalse, reason: id);
      expect(a.disabledReason(rig.c, rig.l), 'Open a canvas first', reason: id);
      expect(a.inPalette!(rig.c), isFalse, reason: '$id 不在画布上不进 ⌘K');
    }
  });

  testWidgets('画布上、栈里有一步 ⇒ 撤销可点、重做灰着；⌘K 含 undo、不含 redo', (tester) async {
    final _Rig rig = await _pump(tester, _onCanvas);
    rig.history.record(ScriptedCanvasCommand('B'));

    expect(_row(AppActionIds.undo).isEnabled(rig.c), isTrue);
    expect(_row(AppActionIds.undo).disabledReason(rig.c, rig.l), isNull);
    expect(_row(AppActionIds.redo).isEnabled(rig.c), isFalse);
    expect(rig.paletteIds, contains(AppActionIds.undo));
    expect(rig.paletteIds, isNot(contains(AppActionIds.redo)));
  });

  testWidgets('画布上、栈空 ⇒ ⌘K 里两个都没有（⌘K 不画禁用行）', (tester) async {
    final _Rig rig = await _pump(tester, _onCanvas);
    expect(rig.paletteIds, isNot(contains(AppActionIds.undo)));
    expect(rig.paletteIds, isNot(contains(AppActionIds.redo)));
  });

  testWidgets('撤销在途（busy）⇒ isEnabled false 且 disabledReason 非 null', (tester) async {
    final _Rig rig = await _pump(tester, _onCanvas);
    final Completer<CanvasCommandOutcome> pending =
        Completer<CanvasCommandOutcome>();
    rig.history.record(ScriptedCanvasCommand('A'));
    rig.history.record(
      ScriptedCanvasCommand('B', revertScript: <Object>[pending]),
    );
    final Future<CanvasUndoResult> inFlight = rig.history.undo();
    expect(rig.container.read(canvasHistoryControllerProvider(_c1)).busy, isTrue);

    final AppAction undo = _row(AppActionIds.undo);
    expect(undo.isEnabled(rig.c), isFalse);
    expect(undo.disabledReason(rig.c, rig.l), isNotNull);
    expect(rig.paletteIds, isNot(contains(AppActionIds.undo)));

    pending.complete(CanvasCommandOutcome.done);
    await inFlight;
    expect(undo.isEnabled(rig.c), isTrue, reason: '做完了：A 还在栈顶');
    expect(_row(AppActionIds.redo).isEnabled(rig.c), isTrue, reason: 'B 进了 redo');
  });

  testWidgets('run：画布上执行撤销 / 重做 ⇒ 撤 / 重做栈顶那一步', (tester) async {
    final _Rig rig = await _pump(tester, _onCanvas);
    final List<String> log = <String>[];
    rig.history.record(ScriptedCanvasCommand('B', log: log));

    await _row(AppActionIds.undo).run(rig.c);
    expect(log, <String>['revert:B']);

    await _row(AppActionIds.redo).run(rig.c);
    expect(log, <String>['revert:B', 'apply:B']);
  });

  test('macKey / otherKey 与 PlannedKeys.undoMac / undoOther / redoMac / redoOther 是同一对象', () {
    final AppAction undo = _row(AppActionIds.undo);
    final AppAction redo = _row(AppActionIds.redo);
    expect(identical(undo.macKey, PlannedKeys.undoMac), isTrue);
    expect(identical(undo.otherKey, PlannedKeys.undoOther), isTrue);
    expect(identical(redo.macKey, PlannedKeys.redoMac), isTrue);
    expect(identical(redo.otherKey, PlannedKeys.redoOther), isTrue);
    expect(undo.group, AppActionGroup.edit);
    expect(redo.group, AppActionGroup.edit);
  });
}
