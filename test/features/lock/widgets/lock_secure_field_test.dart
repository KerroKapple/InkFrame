import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/lock/widgets/lock_secure_field.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('LockSecureField 默认 obscure，眼图标可切换可见', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LockSecureField(
          controller: controller,
          hintText: 'API Key',
        ),
      ),
    ));

    expect(find.text('API Key'), findsOneWidget);
    TextField field = tester.widget(find.byType(TextField));
    expect(field.obscureText, true);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    field = tester.widget(find.byType(TextField));
    expect(field.obscureText, false);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('LockSecureField onSubmitted 透传', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LockSecureField(
          controller: controller,
          hintText: 'k',
          onSubmitted: (v) => submitted = v,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'abc');
  });
}
