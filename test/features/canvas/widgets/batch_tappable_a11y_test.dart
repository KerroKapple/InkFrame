// BatchTappable（批量 slot 动作的统一点击壳）的可达性。
//
// 由来（BOARD 214）：对比浮层与检查器网格里**所有** slot 动作都从这一件出去——
// 「完成」（InkPrimaryButton）、「设为产物 / 重跑此 slot / 取消」
// （InkSecondaryButton）、「⎘ 以该种子重跑」、以及网格里的动作词。此前它是裸
// MouseRegion + GestureDetector，键盘一个都到不了。点击壳换成 theme 层的
// InkActivatable 之后，本文件钉三件事：
//   1. 可点的动作能 Tab 到、Enter 激活，且走的是**同一条** onTap；
//   2. 「失败落 toast」那条链路（runBatchSlotAction）在键盘路径上一字未变——
//      这是任务书点名要当心的那条：换壳不许换掉动作的执行口；
//   3. onTap == null 的格子不是"灰按钮"，而是**根本不是按钮**：不挂手势，连焦点
//      壳都没有。既有用例「『当前』不是按钮：不挂手势」
//      （batch_results_grid_test.dart）钉的是前半句，本文件补后半句。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/widgets/batch_slot_parts.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/theme/components/ink_primitives.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';

import '../../../_harness/a11y.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const Key _action = Key('batch.tappable.action');
const Key _statusWord = Key('batch.tappable.statusWord');

/// 可点的动作 + 一个不可点的状态词并排：Tab 必须落在前者、跳过后者。
Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function() action,
  required RecordingToastService toast,
}) =>
    pumpInkApp(
      tester,
      Scaffold(
        body: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) => Column(
            children: <Widget>[
              BatchTappable(
                key: _action,
                semanticLabel: 'Set as artifact',
                // 与真实接线逐字相同：动作一律从 runBatchSlotAction 出去。
                onTap: () =>
                    unawaited(runBatchSlotAction(context, ref, action)),
                child: const InkSecondaryButton('Set as artifact', height: 26),
              ),
              const BatchTappable(
                key: _statusWord,
                semanticLabel: 'Current',
                onTap: null,
                child: Text('Current'),
              ),
            ],
          ),
        ),
      ),
      surfaceSize: const Size(600, 300),
      overrides: <Override>[toastServiceProvider.overrideWithValue(toast)],
    );

void main() {
  late RecordingToastService toast;

  setUp(() => toast = RecordingToastService());

  testWidgets('可点的动作：Tab 到得了', (tester) async {
    await _pump(tester, toast: toast, action: () async {});

    expect(
      await tabUntilFocused(tester, activatableFocus(tester, _action)),
      isTrue,
      reason: '批量动作不可聚焦 ⇒ 键盘用户到不了「设为产物 / 重跑 / 取消」',
    );
  });

  testWidgets('Enter 激活：走的是同一条 runBatchSlotAction', (tester) async {
    int runs = 0;
    await _pump(tester, toast: toast, action: () async => runs += 1);

    await activateByKey(tester, activatableFocus(tester, _action));
    await tester.pumpAndSettle();

    expect(runs, 1, reason: '回车必须和鼠标点击走同一条动作');
    expect(toast.shown, isEmpty, reason: '动作成功不该弹 toast');
  });

  testWidgets('键盘激活失败 → 照旧落 toast（换壳不许换掉动作的执行口）',
      (tester) async {
    await _pump(
      tester,
      toast: toast,
      action: () async => throw const MissingApiKeyError('gemini-image'),
    );

    await activateByKey(tester, activatableFocus(tester, _action));
    await tester.pumpAndSettle();

    expect(
      toast.kinds,
      <ToastKind>[ToastKind.error],
      reason: 'runBatchSlotAction 的「失败落 toast」在键盘路径上必须同样成立',
    );
    expect(toast.shown.single.title, 'API key is missing');
    expect(toast.shown.single.chime, isFalse,
        reason: 'slot 动作是用户刚点的那一下，失败是即时回应，不是后台事件');
  });

  testWidgets('onTap == null：不挂手势、连焦点壳都没有', (tester) async {
    await _pump(tester, toast: toast, action: () async {});

    expect(
      find.descendant(
        of: find.byKey(_statusWord),
        matching: find.byType(InkActivatable),
      ),
      findsNothing,
      reason: '网格里的「当前」是状态词不是按钮：它既不该挂手势，也不该有焦点壳——'
          '聚焦上去按回车什么都不会发生就是假可达',
    );
    expect(
      find.descendant(
        of: find.byKey(_statusWord),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
      reason: '既有用例「『当前』不是按钮：不挂手势」钉的同一件事，这里一起守住',
    );
  });

  testWidgets('Tab 跳过不可点的状态词', (tester) async {
    await _pump(tester, toast: toast, action: () async {});

    // 焦点环里只有可点的那一件：按满一圈，焦点仍落在它身上。
    final FocusNode node = activatableFocus(tester, _action);
    expect(await tabUntilFocused(tester, node), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      await tabUntilFocused(tester, node),
      isTrue,
      reason: '不可点的状态词不该出现在焦点环里',
    );
  });
}
