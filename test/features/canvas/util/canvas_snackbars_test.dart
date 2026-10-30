// showCanvasSnack / showCanvasUndoSnack：画布提示改走 toastServiceProvider（右下角通知卡）。
//
// 钉五件事：
//   1. 普通提示不传 kind 就是 error——画布里报的几乎都是失败；传了就照传；
//   2. 按步的撤销卡（canvasId + stepId）是 undo 卡，主按钮文案走 l10n.commonUndo，按下去按步撤销卡上那一步
//      （runCanvasUndoStep → undoSpecific），撤的是那一步的命令、后做的步原样留在栈里；
//   3. 按步的卡绑在那一步上：那一步被撤掉（比如 Ctrl Z）⇒ 卡当场收起；
//   4. 两条都从 toastServiceProvider 出去（覆盖成 RecordingToastService 就全记到），
//      不再往 ScaffoldMessenger 塞 SnackBar；
//   5. 画布提示都是用户自己刚做的操作的回应，不带 chime。
//
// 变异对照：showCanvasUndoSnackWith 的按钮改成撤栈顶（runCanvasUndo）⇒「按下去撤的是卡上那一步」红；
// 删掉 bindCard ⇒「步被撤掉 ⇒ 卡 dismissed」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_snackbars.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations_zh.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_canvas_command.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const Key _trigger = Key('canvasSnackbarsTest.trigger');

/// 一颗按钮：按下时用它自己那一处的 context 调 [onTap]——画布里的调用点也是拿
/// widget 的 context 调这两个函数。
Future<void> _pumpTrigger(
  WidgetTester tester, {
  required RecordingToastService toast,
  required void Function(BuildContext context) onTap,
  Locale locale = const Locale('en'),
  List<Override> overrides = const <Override>[],
}) =>
    pumpInkApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            key: _trigger,
            onPressed: () => onTap(context),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
      locale: locale,
      overrides: <Override>[
        toastServiceProvider.overrideWithValue(toast),
        ...overrides,
      ],
    );

/// 按步的用例要的覆盖：撤销后的后效会读节点 / 泳道，不覆盖就去碰库。
List<Override> _stepOverrides() => <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
    ];

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byKey(_trigger)));

CanvasHistoryController _historyOf(WidgetTester tester) =>
    _containerOf(tester).read(canvasHistoryControllerProvider('c1').notifier);

Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.byKey(_trigger));
  await tester.pump();
}

void main() {
  late RecordingToastService toast;

  setUp(() => toast = RecordingToastService());

  testWidgets('showCanvasSnack：不传 kind 就是 error，没有按钮、不响', (tester) async {
    await _pumpTrigger(
      tester,
      toast: toast,
      onTap: (BuildContext context) =>
          showCanvasSnack(context, 'Failed to move node'),
    );

    await _tapTrigger(tester);

    expect(toast.titles, <String>['Failed to move node']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(toast.shown.single.primary, isNull);
    expect(toast.shown.single.chime, isFalse,
        reason: '画布提示都是用户刚做的操作的回应，不是后台事件');
  });

  testWidgets('showCanvasSnack：传了 kind 就照传', (tester) async {
    await _pumpTrigger(
      tester,
      toast: toast,
      onTap: (BuildContext context) {
        showCanvasSnack(context, 'Link created', kind: ToastKind.success);
        showCanvasSnack(context, 'Link already exists',
            kind: ToastKind.warning);
        showCanvasSnack(context, 'Node deleted', kind: ToastKind.info);
      },
    );

    await _tapTrigger(tester);

    expect(toast.titles,
        <String>['Link created', 'Link already exists', 'Node deleted']);
    expect(toast.kinds,
        <ToastKind>[ToastKind.success, ToastKind.warning, ToastKind.info]);
  });

  testWidgets('showCanvasUndoSnack 按步：undo 卡，主按钮「Undo」按下去撤的是卡上那一步',
      (tester) async {
    final List<String> log = <String>[];
    late String stepId;
    await _pumpTrigger(
      tester,
      toast: toast,
      overrides: _stepOverrides(),
      onTap: (BuildContext context) => showCanvasUndoSnack(
        context,
        message: 'Node deleted',
        canvasId: 'c1',
        stepId: stepId,
      ),
    );
    stepId = _historyOf(tester).record(ScriptedCanvasCommand('step', log: log));
    await _tapTrigger(tester);
    // 卡出来之后又做了一步：卡上的「撤销」仍只撤它自己那一步，不是栈顶。
    final ScriptedCanvasCommand later = ScriptedCanvasCommand('later', log: log);
    _historyOf(tester).record(later);

    final RecordedToast card = toast.shown.single;
    expect(card.title, 'Node deleted');
    expect(card.kind, ToastKind.undo);
    expect(card.chime, isFalse, reason: '删除是用户自己刚做的操作，不响');
    expect(card.primary?.label, 'Undo');
    expect(log, isEmpty, reason: '弹卡本身不该触发撤销');

    card.primary!.onPressed();
    await tester.pumpAndSettle();

    expect(log, <String>['revert:step'], reason: '卡上的「撤销」撤卡上那一步');
    final CanvasHistoryState state =
        _containerOf(tester).read(canvasHistoryControllerProvider('c1'));
    expect(state.undo.single.command, same(later), reason: '后做的那步原样留在栈里');
  });

  testWidgets('showCanvasUndoSnack 按步：步被撤掉 ⇒ 卡 dismissed', (tester) async {
    late String stepId;
    await _pumpTrigger(
      tester,
      toast: toast,
      overrides: _stepOverrides(),
      onTap: (BuildContext context) => showCanvasUndoSnack(
        context,
        message: 'Link deleted',
        canvasId: 'c1',
        stepId: stepId,
      ),
    );
    stepId = _historyOf(tester).record(ScriptedCanvasCommand('step'));
    await _tapTrigger(tester);
    expect(toast.shown.single.dismissed, isFalse, reason: '前置：卡还在');

    await _historyOf(tester).undo();

    expect(toast.shown.single.dismissed, isTrue, reason: '这一步离开撤销栈，卡跟着收起');
  });

  test('showUndoToast：不靠 context 也出同一张 undo 卡（层可能已卸载的调用点用它）', () {
    final RecordingToastService direct = RecordingToastService();
    int undos = 0;
    showUndoToast(
      direct,
      message: 'Link deleted',
      undoLabel: 'Undo',
      onUndo: () => undos += 1,
    );

    final RecordedToast card = direct.shown.single;
    expect(card.title, 'Link deleted');
    expect(card.kind, ToastKind.undo);
    expect(card.chime, isFalse);
    expect(card.primary?.label, 'Undo');
    card.primary!.onPressed();
    expect(undos, 1);
  });

  testWidgets('showCanvasUndoSnack 按步：按钮文案走 l10n（zh 下是 commonUndo 的中文）',
      (tester) async {
    late String stepId;
    await _pumpTrigger(
      tester,
      toast: toast,
      locale: const Locale('zh'),
      overrides: _stepOverrides(),
      onTap: (BuildContext context) => showCanvasUndoSnack(
        context,
        message: 'n',
        canvasId: 'c1',
        stepId: stepId,
      ),
    );
    stepId = _historyOf(tester).record(ScriptedCanvasCommand('step'));

    await _tapTrigger(tester);

    expect(toast.shown.single.primary?.label, AppLocalizationsZh().commonUndo);
  });

  testWidgets('两条都不再往 ScaffoldMessenger 塞 SnackBar', (tester) async {
    await _pumpTrigger(
      tester,
      toast: toast,
      onTap: (BuildContext context) {
        showCanvasSnack(context, 'Failed to delete lane');
        showCanvasUndoSnack(context, message: 'Link deleted', onUndo: () {});
      },
    );

    await _tapTrigger(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
    expect(toast.kinds, <ToastKind>[ToastKind.error, ToastKind.undo]);
  });
}
