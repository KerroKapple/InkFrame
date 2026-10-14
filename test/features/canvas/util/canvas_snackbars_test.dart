// showCanvasSnack / showCanvasUndoSnack：画布提示改走 toastServiceProvider（右下角通知卡）。
//
// 钉四件事：
//   1. 普通提示不传 kind 就是 error——画布里报的几乎都是失败；传了就照传；
//   2. 撤销提示是 undo 卡，主按钮文案走 l10n.commonUndo，按下去调到调用方的 onUndo；
//   3. 两条都从 toastServiceProvider 出去（覆盖成 RecordingToastService 就全记到），
//      不再往 ScaffoldMessenger 塞 SnackBar；
//   4. 画布提示都是用户自己刚做的操作的回应，不带 chime。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/util/canvas_snackbars.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations_zh.dart';

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
      overrides: <Override>[toastServiceProvider.overrideWithValue(toast)],
    );

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

  testWidgets('showCanvasUndoSnack：undo 卡，主按钮「Undo」按下去调 onUndo',
      (tester) async {
    int undos = 0;
    await _pumpTrigger(
      tester,
      toast: toast,
      onTap: (BuildContext context) => showCanvasUndoSnack(
        context,
        message: 'Node deleted',
        onUndo: () => undos += 1,
      ),
    );

    await _tapTrigger(tester);

    final RecordedToast card = toast.shown.single;
    expect(card.title, 'Node deleted');
    expect(card.kind, ToastKind.undo);
    expect(card.chime, isFalse, reason: '删除是用户自己刚做的操作，不响');
    expect(card.primary?.label, 'Undo');
    expect(undos, 0, reason: '弹卡本身不该触发撤销');

    card.primary!.onPressed();
    expect(undos, 1, reason: '卡上的「撤销」就是调用方给的 onUndo');
  });

  testWidgets('showCanvasUndoSnack：按钮文案走 l10n（zh 下是 commonUndo 的中文）',
      (tester) async {
    await _pumpTrigger(
      tester,
      toast: toast,
      locale: const Locale('zh'),
      onTap: (BuildContext context) => showCanvasUndoSnack(
        context,
        message: 'n',
        onUndo: () {},
      ),
    );

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
