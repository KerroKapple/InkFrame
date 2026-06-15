// LightboxScrubSlider 测试（LO-10）：拖动期间不触发 seek，松手才 seek 一次；
// 拖动期间滑块跟随手指（本地值），不被外部 position 回弹。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/video_lightbox.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('拖动中不 seek，松手只 seek 一次', (tester) async {
    final seeks = <Duration>[];
    await pumpInkApp(
      tester,
      Scaffold(
        body: LightboxScrubSlider(
          position: Duration.zero,
          duration: const Duration(seconds: 60),
          onSeek: seeks.add,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    // 多次移动模拟连续拖动 tick
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    expect(seeks, isEmpty, reason: '拖动期间不得触发 seek');

    await gesture.up();
    await tester.pump();
    expect(seeks, hasLength(1), reason: '松手后只 seek 一次');
    expect(seeks.single, greaterThan(Duration.zero));
  });

  testWidgets('拖动期间滑块用本地值，不被外部 position 回弹', (tester) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    addTearDown(position.dispose);
    await pumpInkApp(
      tester,
      Scaffold(
        body: ValueListenableBuilder<Duration>(
          valueListenable: position,
          builder: (_, pos, _) => LightboxScrubSlider(
            position: pos,
            duration: const Duration(seconds: 60),
            onSeek: (_) {},
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    final dragging = tester.widget<Slider>(find.byType(Slider)).value;
    expect(dragging, greaterThan(0));

    // 外部 position 流推进触发重建，不应覆盖本地拖动值
    position.value = const Duration(seconds: 5);
    await tester.pump();
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      dragging,
      reason: '拖动中外部 position 更新不得回弹滑块',
    );
    await gesture.up();
    await tester.pump();
  });

  testWidgets('duration 为零时滑块禁用且不崩溃', (tester) async {
    final seeks = <Duration>[];
    await pumpInkApp(
      tester,
      Scaffold(
        body: LightboxScrubSlider(
          position: Duration.zero,
          duration: Duration.zero,
          onSeek: seeks.add,
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(seeks, isEmpty);
  });
}
