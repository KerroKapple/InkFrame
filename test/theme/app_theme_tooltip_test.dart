// tooltip 主题：浮层令牌（surface4 底 + overlayBorder 边 + fg2 字），三种主题变体一致。
//
// 没有这层主题时 Material 取 colorScheme.inverseSurface——buildAppTheme 的 ColorScheme
// 没给它，回落成 onSurface（fg1，浅灰），暗色界面里每个 tooltip 都是一块浅底黑字。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  for (final InkThemeVariant variant in InkThemeVariant.values) {
    test('tooltip 走浮层令牌（${variant.name}）', () {
      final ThemeData theme = buildAppTheme(variant: variant, textScale: 1);
      final InkColors c = theme.extension<AppThemeExtension>()!.colors;
      final TooltipThemeData tooltip = theme.tooltipTheme;
      final BoxDecoration box = tooltip.decoration! as BoxDecoration;

      expect(box.color, c.surface4);
      expect((box.border! as Border).top.color, c.overlayBorder);
      expect(tooltip.textStyle!.color, c.fg2);
    });
  }

  testWidgets('真弹出来的 tooltip：浮层底色 + fg2 字，不是 Material 默认的浅底', (tester) async {
    final ThemeData theme =
        buildAppTheme(variant: InkThemeVariant.dark, textScale: 1);
    final InkColors c = theme.extension<AppThemeExtension>()!.colors;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: Center(
          child: Tooltip(
            message: 'Pan  H',
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    ));

    tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
    await tester.pumpAndSettle();

    final DecoratedBox shell = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('Pan  H'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect((shell.decoration as BoxDecoration).color, c.surface4);
    expect(
      tester.renderObject<RenderParagraph>(find.text('Pan  H')).text.style?.color,
      c.fg2,
    );
  });
}
