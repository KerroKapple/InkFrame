// InkInput：enabled / autofocus 透传契约。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_input.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('默认 enabled=true → TextField 可编辑', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await pump(tester, InkInput(controller: ctrl));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.enterText(find.byType(TextField), 'abc');
    expect(ctrl.text, 'abc');
  });

  testWidgets('enabled=false → TextField 禁用', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await pump(tester, InkInput(controller: ctrl, enabled: false));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('autofocus 默认关；autofocus=true → 挂上就持焦', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await pump(tester, InkInput(controller: ctrl));
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);

    await pump(tester, InkInput(key: const ValueKey<String>('af'), controller: ctrl, autofocus: true));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus, isTrue);
  });
}
