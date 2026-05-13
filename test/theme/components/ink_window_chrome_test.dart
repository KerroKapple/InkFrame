import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';

void main() {
  testWidgets('InkWindowChrome height is 56', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: InkWindowChrome(center: Text('Studio › Projects')),
      ),
    ));
    final size = tester.getSize(find.byType(InkWindowChrome));
    expect(size.height, 56);
    expect(find.text('Studio › Projects'), findsOneWidget);
  });
}
