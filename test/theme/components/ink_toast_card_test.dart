// InkToastCard：通知卡呈现件的契约（纯数据 + 回调；文案全部由调用方给——theme 层不碰 ARB）。
//
// 进行中那条有转圈 / 不确定态动画：全文件只 pump 固定帧，不 pumpAndSettle。
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/components/ink_toast_card.dart';

import '../../_harness/test_app.dart';

/// 卡片放在 360 宽的槽里（右下角卡片栈的宽度）。
Future<void> _pump(
  WidgetTester tester,
  Widget Function(BuildContext context) build,
) =>
    pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: Builder(builder: build)),
        ),
      ),
    );

double _closeOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(InkToastCard.closeKey)).opacity;

void main() {
  testWidgets('标题 / 正文 / 出处三行都画出来', (tester) async {
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.info,
        title: 'Shot 3 is ready',
        body: 'Saved to the canvas',
        meta: 'Alpha · Main',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(find.text('Shot 3 is ready'), findsOneWidget);
    expect(find.text('Saved to the canvas'), findsOneWidget);
    expect(find.text('Alpha · Main'), findsOneWidget);
  });

  testWidgets('没有缩略图画类型图块；有缩略图换成图', (tester) async {
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.success,
        title: 'no thumb',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(find.byType(InkToastLeading), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.success,
        title: 'with thumb',
        thumbnail: MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3])),
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('进行中：确定态画进度条 + 百分比；不确定态只有进度条；别的类型没有进度条',
      (tester) async {
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.progress,
        title: 'Exporting',
        progress: 0.4,
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.4,
    );
    expect(find.text('40%'), findsOneWidget);

    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.progress,
        title: 'Exporting',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(find.textContaining('%'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));

    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.success,
        title: 'Done',
        progress: 0.4,
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('两个按钮：次按钮在左、主按钮在右，各走各的回调', (tester) async {
    int primary = 0;
    int secondary = 0;
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.undo,
        title: 'Node deleted',
        primaryLabel: 'Undo',
        onPrimary: () => primary++,
        secondaryLabel: 'Details',
        onSecondary: () => secondary++,
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(
      tester.getCenter(find.text('Details')).dx,
      lessThan(tester.getCenter(find.text('Undo')).dx),
    );
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(primary, 1, reason: '按主按钮只触发一次（不能连同整卡点击再触发一次）');
    expect(secondary, 0);
    await tester.tap(find.text('Details'));
    await tester.pump();
    expect(secondary, 1);
    expect(primary, 1, reason: '次按钮不该触发主动作');
  });

  testWidgets('点卡片空白处 = 主按钮；没有主按钮时点卡片什么都不发生', (tester) async {
    int primary = 0;
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.success,
        title: 'Shot 3 is ready',
        primaryLabel: 'View',
        onPrimary: () => primary++,
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    await tester.tap(find.text('Shot 3 is ready'));
    await tester.pump();
    expect(primary, 1);

    int dismissed = 0;
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.info,
        title: 'Plain',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () => dismissed++,
      ),
    );
    await tester.tap(find.text('Plain'));
    await tester.pump();
    expect(dismissed, 0, reason: '点卡片不是关卡片');
  });

  testWidgets('只给文案不给回调的按钮不画', (tester) async {
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.info,
        title: 't',
        primaryLabel: 'View',
        secondaryLabel: 'Later',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    expect(find.text('View'), findsNothing);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('× 只在悬停时显形；点它走 onDismiss', (tester) async {
    int dismissed = 0;
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.error,
        title: 'Generation failed',
        body: 'Network offline',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () => dismissed++,
      ),
    );
    expect(_closeOpacity(tester), 0.0, reason: '没悬停时不显形');

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Generation failed')));
    await tester.pump();
    expect(_closeOpacity(tester), 1.0, reason: '悬停卡片时显形');

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(_closeOpacity(tester), 0.0, reason: '移开后再藏起来');

    await tester.tap(find.byKey(InkToastCard.closeKey));
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('× 的读屏标签就是调用方给的 toastDismiss 文案，且不显形时也在',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      (BuildContext context) => InkToastCard(
        tone: InkToastTone.info,
        title: 'Saved',
        dismissLabel: context.l10n.toastDismiss,
        onDismiss: () {},
      ),
    );
    final String label =
        tester.element(find.byType(InkToastCard)).l10n.toastDismiss;
    expect(label, isNotEmpty);
    expect(_closeOpacity(tester), 0.0);
    expect(
      find.bySemanticsLabel(label),
      findsOneWidget,
      reason: '× 单独成一个节点，标签不与标题合并；透明只是画面上的',
    );
    handle.dispose();
  });

  testWidgets('失败卡原地换成一条新的失败（去重替换，State 沿用）：读屏再播报一次', (tester) async {
    final List<String> announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        final Map<dynamic, dynamic> event = message as Map<dynamic, dynamic>;
        if (event['type'] == 'announce') {
          announced.add((event['data'] as Map<dynamic, dynamic>)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));

    Widget card(String title, String body) => MediaQuery(
          data: const MediaQueryData(supportsAnnounce: true),
          child: InkToastCard(
            key: const ValueKey<String>('same-card'),
            tone: InkToastTone.error,
            title: title,
            body: body,
            dismissLabel: 'Dismiss',
            onDismiss: () {},
          ),
        );

    await _pump(tester, (_) => card('Generation failed', 'offline'));
    await tester.pump();
    expect(announced, <String>['Generation failed']);

    // 同一节点又失败了一次，原因不同：同一张卡、同一个 State，只换了内容。
    await _pump(tester, (_) => card('Generation failed', 'quota exceeded'));
    await tester.pump();
    expect(announced, hasLength(2), reason: '否则读屏用户只听得到第一次失败');

    // 内容没变的重建不重复播报。
    await _pump(tester, (_) => card('Generation failed', 'quota exceeded'));
    await tester.pump();
    expect(announced, hasLength(2));
  });

}
