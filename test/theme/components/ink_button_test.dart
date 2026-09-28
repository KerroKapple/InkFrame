// InkButton：变体前景/禁用态视觉契约。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_button.dart';
import 'package:inkframe/theme/tokens.dart';

import '../wcag.dart';

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

  testWidgets('primary 前景用 onAccent（brand 底上不用浅色 fg1）', (tester) async {
    await pump(
      tester,
      InkButton(label: 'Go', onPressed: () {}),
    );
    expect(labelColor(tester, 'Go'), InkColors.dark().onAccent);
  });

  testWidgets('danger 变体：透明底 + danger 红字（不做容器底色）', (tester) async {
    await pump(
      tester,
      InkButton(
        label: 'Del',
        onPressed: () {},
        variant: InkButtonVariant.danger,
      ),
    );
    expect(labelColor(tester, 'Del'), InkColors.dark().danger);
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

  // 对比率锁定（WCAG AA ≥4.5:1）：唯一彩底（primary 琥珀）× 三变体逐一锁死，
  // 防 per-variant 前景取色再翻车（历史 bug：light 一刀切 surfaceCanvas）。
  for (final variant in InkThemeVariant.values) {
    testWidgets('$variant: primary 前景对琥珀底对比率 ≥4.5，danger 透明底红字', (tester) async {
      await pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkButton(label: 'Go', onPressed: () {}),
            InkButton(
              label: 'Del',
              onPressed: () {},
              variant: InkButtonVariant.danger,
            ),
          ],
        ),
        variant: variant,
      );
      Color bgOf(String label) {
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color!;
      }

      expect(
        wcagContrast(bgOf('Go'), labelColor(tester, 'Go')),
        greaterThanOrEqualTo(4.5),
        reason: '$variant primary(accent 底)',
      );
      // danger 不做容器底色（README：语义色只做文字与小图标）：透明底 + danger 红字。
      // 红字落在下方面板上的对比率是 README 取值的既有属性，不在按钮层锁。
      expect(bgOf('Del').a, 0, reason: '$variant danger 底必须透明');
      expect(
        labelColor(tester, 'Del'),
        switch (variant) {
          InkThemeVariant.dark => InkColors.dark().danger,
          InkThemeVariant.light => InkColors.light().danger,
          InkThemeVariant.highContrast => InkColors.highContrast().danger,
        },
      );
    });
  }

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
