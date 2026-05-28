import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/lock/widgets/lock_logo.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('LockLogo 渲染 Ink / Frame 三段', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(body: Center(child: LockLogo())),
    ));
    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
  });
}
