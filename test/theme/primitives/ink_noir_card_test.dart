import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_noir_card.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  testWidgets('InkNoirCard uses surface2 bg + border 1px no shadow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: InkNoirCard(padding: EdgeInsets.all(8), child: Text('x')),
      ),
    ));
    final container = tester.widgetList<AnimatedContainer>(find.descendant(
      of: find.byType(InkNoirCard),
      matching: find.byType(AnimatedContainer),
    )).first;
    final deco = container.decoration as BoxDecoration;
    expect(deco.color, InkColors.dark().surface2);
    expect(deco.boxShadow, isNull);
    expect((deco.border as Border?)?.top.width, 1);
  });

  testWidgets('selected card uses accent border', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: InkNoirCard(
          padding: EdgeInsets.all(8),
          selected: true,
          child: Text('x'),
        ),
      ),
    ));
    final container = tester.widgetList<AnimatedContainer>(find.descendant(
      of: find.byType(InkNoirCard),
      matching: find.byType(AnimatedContainer),
    )).first;
    final deco = container.decoration as BoxDecoration;
    final borderColor = (deco.border as Border).top.color;
    expect(borderColor, InkColors.dark().accent);
  });
}
