import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/widgets/project_card.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('StudioProjectCard 渲染 name + metaLine + 「N canvases」徽标并响应 tap', (tester) async {
    var tapCount = 0;
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: StudioProjectCard(
              name: 'Side Quest',
              metaLine: '2 h ago',
              canvasCount: 3,
              onTap: () => tapCount += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Side Quest'), findsOneWidget);
    expect(find.text('2 h ago'), findsOneWidget);
    expect(find.text('3 canvases'), findsOneWidget);
    expect(find.byTooltip('Project options'), findsNothing, reason: '没给任何菜单回调就不画 ⋯');

    await tester.tap(find.text('Side Quest'));
    await tester.pump();
    expect(tapCount, 1);
  });
}
