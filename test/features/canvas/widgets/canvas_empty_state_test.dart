// CanvasEmptyState 渲染测试：标题/副文/双 CTA + 背景点击触发回调。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_empty_state.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('渲染插图 + 标题 + 副文 + 三 CTA', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This canvas is empty'), findsOneWidget);
    expect(find.text('Add your first node to start storyboarding.'),
        findsOneWidget);
    expect(find.text('Add image node'), findsOneWidget);
    expect(find.text('Add video node'), findsOneWidget);
    expect(find.text('Add shot node'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget); // illustration center
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('点击空白触发 onBackgroundTap', (tester) async {
    var taps = 0;
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () => taps++),
      ),
    );
    await tester.pumpAndSettle();
    // 点击屏幕左上角的空白处（远离 CTA 按钮和卡片）。
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(taps, 1);
  });
}
