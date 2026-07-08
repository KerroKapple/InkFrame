import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_amber_button.dart';

import '../wcag.dart';

void main() {
  testWidgets('InkAmberButton uses cta bg + onAccent text + 44 height', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: InkAmberButton(label: 'Unlock', onPressed: () {}),
      ),
    ));
    final box = tester.getSize(find.byType(InkAmberButton));
    expect(box.height, 44);
    expect(find.text('Unlock'), findsOneWidget);
  });

  // 对比率锁定（WCAG AA ≥4.5:1）：cta 琥珀底 × 三变体
  // （历史 bug：light 一刀切 surfaceCanvas 只有 2.57:1）。
  for (final variant in InkThemeVariant.values) {
    testWidgets('$variant: cta 底文字对比率 ≥4.5', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(variant: variant, textScale: 1),
        home: Scaffold(
          body: InkAmberButton(label: 'Unlock', onPressed: () {}),
        ),
      ));
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final bg = (container.decoration as BoxDecoration).color!;
      final text = tester.widget<Text>(find.text('Unlock'));
      expect(
        wcagContrast(bg, text.style!.color!),
        greaterThanOrEqualTo(4.5),
        reason: '$variant cta 底',
      );
    });
  }
}
