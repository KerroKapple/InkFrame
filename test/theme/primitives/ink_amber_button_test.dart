import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_amber_button.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  testWidgets('InkAmberButton uses cta bg + surfaceCanvas text + 44 height', (tester) async {
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
}
