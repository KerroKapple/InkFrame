// InkButton：变体前景/禁用态视觉契约。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_button.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    InkThemeVariant variant = InkThemeVariant.dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(variant: variant, textScale: 1),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  Color labelColor(WidgetTester tester, String label) {
    final text = tester.widget<Text>(find.text(label));
    return text.style!.color!;
  }

  testWidgets('primary 前景用 surfaceCanvas（brand 底上不用浅色 fg1）', (tester) async {
    await pump(
      tester,
      InkButton(label: 'Go', onPressed: () {}),
    );
    expect(labelColor(tester, 'Go'), InkColors.dark().surfaceCanvas);
  });

  testWidgets('danger 前景用 surfaceCanvas', (tester) async {
    await pump(
      tester,
      InkButton(
        label: 'Del',
        onPressed: () {},
        variant: InkButtonVariant.danger,
      ),
    );
    expect(labelColor(tester, 'Del'), InkColors.dark().surfaceCanvas);
  });

  testWidgets('secondary/ghost 中性底保持 fg1 前景', (tester) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkButton(
            label: 'Sec',
            onPressed: () {},
            variant: InkButtonVariant.secondary,
          ),
          InkButton(
            label: 'Gho',
            onPressed: () {},
            variant: InkButtonVariant.ghost,
          ),
        ],
      ),
    );
    expect(labelColor(tester, 'Sec'), InkColors.dark().fg1);
    expect(labelColor(tester, 'Gho'), InkColors.dark().fg1);
  });

  testWidgets('禁用态（onPressed=null）前景压灰为 fg4 且不可点', (tester) async {
    await pump(
      tester,
      const InkButton(label: 'Off', onPressed: null),
    );
    expect(labelColor(tester, 'Off'), InkColors.dark().fg4);

    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('Off'), matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNull);
  });
}
