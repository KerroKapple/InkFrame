// 删节点进画布撤销栈（util/canvas_node_delete.dart → DeleteNodesCommand）：卡片只是提醒、栈才是本体。
//
// 装置：一颗按钮，按下时用自己那一处的 context / ref 调 deleteNodesWithUndo（照 canvas_snackbars_test 的
// _pumpTrigger 写法另抄一个，那个是私有的）。覆盖：节点控制器 = FakeNodesController 的记录子类、泳道 =
// EmptyLanesController（执行口后效会读泳道）、通知 = RecordingToastService、外壳停在画布 c1（撤销栈只在外壳
// canvasId 从 c1 变走时丢栈）。Ctrl Z 直接调 runCanvasUndo；「卡片收起」= 不点卡（卡只是提醒，收不收起栈都在）。
// 节点 / 选中 / 胶囊 / 相机 / 视口尺寸先挂订阅：都是 autoDispose（同 canvas_history_actions_test 头注）。
//
// 变异对照：
// - 删掉单选分支的 record ⇒「卡片收起后 Ctrl Z 仍复原」红；
// - showCanvasUndoSnackWith 的按钮改成 runCanvasUndo（撤栈顶）⇒「删 A、再删 B，点 A 的卡」红；
// - 删掉 bindCard ⇒「关掉画布 ⇒ 卡 dismissed」红；
// - DeleteNodesCommand.revert 删掉「返回 0 ⇒ gone」⇒「restoreAll 返回 0」红；
// - 多选失败分支改成照样 record ⇒「多删失败 ⇒ 栈为空」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_history_actions.dart';
import 'package:inkframe/features/canvas/util/canvas_node_delete.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations_en.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _c1 = 'c1';
const Key _trigger = Key('canvasNodeDeleteUndoTest.trigger');

/// 记下 removeNodes / restoreAll 的调用；restoreAll 的结果 / 失败、removeNodes 的失败可以改写。
class _Nodes extends FakeNodesController {
  _Nodes() : super(twoNodes);

  final List<Set<String>> removeNodesCalls = <Set<String>>[];
  final List<List<NodeDeletion>> restoreAllCalls = <List<NodeDeletion>>[];

  /// 非 null ⇒ restoreAll 不动内存、直接返回它。
  int? restoreResult;

  /// 非 null ⇒ restoreAll 抛它。
  InkError? restoreError;

  /// 非 null ⇒ removeNodes 抛它（整批回滚：内存不动）。
  InkError? removeError;

  @override
  Future<List<NodeDeletion>> removeNodes(Set<String> ids) {
    removeNodesCalls.add(Set<String>.of(ids));
    final InkError? error = removeError;
    if (error != null) return Future<List<NodeDeletion>>.error(error);
    return super.removeNodes(ids);
  }

  @override
  Future<int> restoreAll(List<NodeDeletion> deletions) {
    restoreAllCalls.add(List<NodeDeletion>.of(deletions));
    final InkError? error = restoreError;
    if (error != null) return Future<int>.error(error);
    final int? forced = restoreResult;
    if (forced != null) return Future<int>.value(forced);
    return super.restoreAll(deletions);
  }
}

/// 一颗按钮：按下时删 [ids()] 给的那几张（每次按都现取，好分两次删 A、B）。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _Nodes nodes,
  required RecordingToastService toast,
  required Set<String> Function() ids,
}) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) => TextButton(
          key: _trigger,
          onPressed: () => deleteNodesWithUndo(
            context,
            ref,
            canvasId: _c1,
            nodeIds: ids(),
          ),
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(tab: ShellTab.canvas, canvasId: _c1),
        ),
      ),
      canvasNodesControllerProvider.overrideWith(() => nodes),
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
      toastServiceProvider.overrideWithValue(toast),
    ],
  );
  final ProviderContainer c =
      ProviderScope.containerOf(tester.element(find.byKey(_trigger)));
  c.listen(canvasNodesControllerProvider(_c1), (_, _) {});
  c.listen(canvasLanesControllerProvider(_c1), (_, _) {});
  c.listen(canvasSelectionControllerProvider(_c1), (_, _) {});
  c.listen(canvasCapsuleProvider(_c1), (_, _) {});
  c.listen(canvasTransformControllerProvider(_c1), (_, _) {});
  c.listen(canvasViewportSizeProvider(_c1), (_, _) {});
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.byKey(_trigger));
  await tester.pumpAndSettle();
}

Set<String> _idsIn(ProviderContainer c) => <String>{
      for (final CanvasNode n in c.read(canvasNodesControllerProvider(_c1)).requireValue)
        n.id,
    };

CanvasHistoryState _history(ProviderContainer c) =>
    c.read(canvasHistoryControllerProvider(_c1));

void main() {
  late RecordingToastService toast;
  late _Nodes nodes;

  setUp(() {
    toast = RecordingToastService();
    nodes = _Nodes();
  });

  testWidgets('单删 ⇒ 一张卡 + 栈里一步「Delete 1 node」', (tester) async {
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{'a'});

    await _tapTrigger(tester);

    expect(toast.titles, <String>['Node deleted']);
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
    expect(_history(c).undo, hasLength(1));
    expect(_history(c).undo.single.command.label(AppLocalizationsEn()), 'Delete 1 node');
    expect(_history(c).undo.single.command.affectedNodeIds, <String>{'a'});
  });

  testWidgets('卡片收起后 Ctrl Z（runCanvasUndo）仍复原，且卡被 dismiss', (tester) async {
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{'a'});
    await _tapTrigger(tester);
    expect(_idsIn(c), <String>{'b'}, reason: '前置：a 删了');

    // 不点卡：卡只是提醒，撤销走栈。
    await runCanvasUndo(c.read, canvasId: _c1, l: AppLocalizationsEn(), isMac: false);
    await tester.pumpAndSettle();

    expect(nodes.restoreAllCalls, hasLength(1));
    expect(nodes.restoreAllCalls.single.single.node.id, 'a');
    expect(_idsIn(c), <String>{'a', 'b'});
    expect(toast.shown.single.dismissed, isTrue, reason: '这一步撤掉了，它的卡当场收起');
    expect(_history(c).redo, hasLength(1), reason: '撤完可以重做');
  });

  testWidgets('删 A、再删 B，点 A 的卡 ⇒ 只复原 A；B 那步仍在栈顶；重做栈为空', (tester) async {
    String next = 'a';
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{next});
    await _tapTrigger(tester);
    next = 'b';
    await _tapTrigger(tester);
    expect(_idsIn(c), isEmpty, reason: '前置：两张都删了');
    expect(toast.shown, hasLength(2));
    final String stepB = _history(c).undo.last.id;

    toast.shown.first.primary!.onPressed();
    await tester.pumpAndSettle();

    expect(_idsIn(c), <String>{'a'}, reason: '只复原卡上那一步');
    expect(nodes.restoreAllCalls.single.single.node.id, 'a');
    expect(_history(c).undo.map((CanvasHistoryStep s) => s.id), <String>[stepB]);
    expect(_history(c).redo, isEmpty, reason: '栈中间那步撤掉后不进重做栈');
    expect(toast.shown.first.dismissed, isTrue);
    expect(toast.shown.last.dismissed, isFalse);
  });

  testWidgets('关掉画布（openCanvas(c2)）⇒ 卡 dismissed；再点卡上的撤销 ⇒ 不复原、不出新卡',
      (tester) async {
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{'a'});
    await _tapTrigger(tester);
    final RecordedToast card = toast.shown.single;

    c.read(shellControllerProvider.notifier).openCanvas('c2');
    await tester.pumpAndSettle();

    expect(card.dismissed, isTrue, reason: '关画布丢栈，卡当场收起');

    card.primary!.onPressed();
    await tester.pumpAndSettle();

    expect(nodes.restoreAllCalls, isEmpty, reason: '残留的按钮不再假装成功');
    expect(toast.shown, hasLength(1), reason: '不出任何新卡');
  });

  testWidgets('restoreAll 返回 0 ⇒ 胶囊 This step can no longer be undone，栈里这步没了',
      (tester) async {
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{'a'});
    await _tapTrigger(tester);
    nodes.restoreResult = 0;

    toast.shown.single.primary!.onPressed();
    await tester.pumpAndSettle();

    expect(c.read(canvasCapsuleProvider(_c1))?.text, 'This step can no longer be undone');
    expect(_history(c).undo, isEmpty);
    expect(_history(c).redo, isEmpty);
    expect(toast.shown, hasLength(1), reason: '作废只出胶囊，不出卡');
  });

  testWidgets("restoreAll 抛 InkError ⇒ Couldn't undo 错误卡，步仍在栈顶", (tester) async {
    final ProviderContainer c =
        await _pump(tester, nodes: nodes, toast: toast, ids: () => <String>{'a'});
    await _tapTrigger(tester);
    final String stepId = _history(c).undo.single.id;
    nodes.restoreError = const LocalIOError();

    toast.shown.single.primary!.onPressed();
    await tester.pumpAndSettle();

    expect(toast.titles, <String>['Node deleted', "Couldn't undo"]);
    expect(toast.kinds.last, ToastKind.error);
    expect(_history(c).undo.single.id, stepId);
    expect(toast.shown.first.dismissed, isFalse, reason: '没撤成，卡不收');
  });

  testWidgets('多删 ⇒ 一步「Delete 2 nodes」+ 一张「2 nodes deleted」卡', (tester) async {
    final ProviderContainer c = await _pump(tester,
        nodes: nodes, toast: toast, ids: () => <String>{'a', 'b'});

    await _tapTrigger(tester);

    expect(nodes.removeNodesCalls.single, <String>{'a', 'b'});
    expect(toast.titles, <String>['2 nodes deleted']);
    expect(_history(c).undo, hasLength(1));
    expect(_history(c).undo.single.command.label(AppLocalizationsEn()), 'Delete 2 nodes');
  });

  testWidgets('多删失败 ⇒ 栈为空、没有撤销卡', (tester) async {
    nodes.removeError = const LocalIOError();
    final ProviderContainer c = await _pump(tester,
        nodes: nodes, toast: toast, ids: () => <String>{'a', 'b'});

    await _tapTrigger(tester);

    expect(toast.titles, <String>['Failed to delete node']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(toast.shown.single.primary, isNull);
    expect(_history(c).undo, isEmpty);
  });
}
