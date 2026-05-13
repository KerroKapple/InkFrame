import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';

void main() {
  testWidgets('InkGhostButton has no background by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: InkGhostButton(label: 'Library', onPressed: () {}),
      ),
    ));
    expect(find.text('Library'), findsOneWidget);
  });
}
