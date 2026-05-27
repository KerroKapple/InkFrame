import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/widgets/project_card.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('StudioProjectCard 渲染 name + metaLine 并响应 tap', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: StudioProjectCard(
              name: 'Side Quest',
              metaLine: '3 CANVASES · 12 NODES',
              onTap: () => tapCount += 1,
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Side Quest'), findsOneWidget);
    expect(find.text('3 CANVASES · 12 NODES'), findsOneWidget);

    await tester.tap(find.text('Side Quest'));
    await tester.pump();
    expect(tapCount, 1);
  });
}
