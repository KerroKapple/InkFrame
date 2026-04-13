import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';
import 'package:inkframe/theme/typography.dart';

void main() {
  group('InkColors variants', () {
    test('dark variant returns opaque dark surface1', () {
      final colors = InkColors.dark();
      expect(colors.surface1.a, 1.0); // 完全不透明
      // 深色底色：亮度接近 0
      expect(colors.surface1.computeLuminance(), lessThan(0.1));
    });

    test('light variant surface1 is high-luminance', () {
      final colors = InkColors.light();
      expect(colors.surface1.computeLuminance(), greaterThan(0.8));
    });

    test('highContrast uses pure black/white extremes', () {
      final colors = InkColors.highContrast();
      expect(colors.surface1, const Color(0xFF000000));
      expect(colors.fg1, const Color(0xFFFFFFFF));
    });

    test('every variant exposes all 15 semantic slots', () {
      for (final InkColors c in <InkColors>[
        InkColors.dark(),
        InkColors.light(),
        InkColors.highContrast(),
      ]) {
        expect(c.surface1, isA<Color>());
        expect(c.surface2, isA<Color>());
        expect(c.surface3, isA<Color>());
        expect(c.fg1, isA<Color>());
        expect(c.fg2, isA<Color>());
        expect(c.fg3, isA<Color>());
        expect(c.accent, isA<Color>());
        expect(c.brand, isA<Color>());
        expect(c.danger, isA<Color>());
        expect(c.warning, isA<Color>());
        expect(c.success, isA<Color>());
        expect(c.border, isA<Color>());
        expect(c.focusRing, isA<Color>());
        expect(c.overlay, isA<Color>());
        expect(c.scrim, isA<Color>());
      }
    });
  });

  group('InkSpacing / InkRadius', () {
    test('spacing follows 8-based scale', () {
      expect(InkSpacing.xs, 4);
      expect(InkSpacing.sm, 8);
      expect(InkSpacing.md, 16);
      expect(InkSpacing.lg, 24);
      expect(InkSpacing.xl, 32);
      expect(InkSpacing.xxl, 48);
    });

    test('radius tokens cover common UI needs', () {
      expect(InkRadius.sm, 4);
      expect(InkRadius.md, 8);
      expect(InkRadius.lg, 12);
      expect(InkRadius.xl, 16);
      expect(InkRadius.pill, 999);
    });
  });

  group('InkTypography scaling', () {
    test('defaults produce body fontSize 14', () {
      final t = InkTypography.defaults();
      expect(t.body.fontSize, 14);
    });

    test('scaled(1.25) multiplies every size', () {
      final t = InkTypography.defaults().scaled(1.25);
      expect(t.body.fontSize, 14 * 1.25);
      expect(t.title.fontSize, 18 * 1.25);
      expect(t.display.fontSize, 28 * 1.25);
    });
  });

  group('buildAppTheme', () {
    testWidgets('context.inkColors returns the dark palette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            variant: InkThemeVariant.dark,
            textScale: 1,
          ),
          home: Builder(
            builder: (ctx) {
              final c = ctx.inkColors;
              // 断言语义槽位 = dark 工厂值
              expect(c.surface1, InkColors.dark().surface1);
              expect(c.fg1, InkColors.dark().fg1);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('highContrast variant flips context.inkColors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            variant: InkThemeVariant.highContrast,
            textScale: 1,
          ),
          home: Builder(
            builder: (ctx) {
              expect(ctx.inkColors.fg1, const Color(0xFFFFFFFF));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    test('AppThemeExtension.lerp picks terminal state past halfway', () {
      final a = AppThemeExtension(
        colors: InkColors.dark(),
        typography: InkTypography.defaults(),
      );
      final b = AppThemeExtension(
        colors: InkColors.light(),
        typography: InkTypography.defaults(),
      );
      expect(a.lerp(b, 0.3).colors.surface1, a.colors.surface1);
      expect(a.lerp(b, 0.7).colors.surface1, b.colors.surface1);
    });
  });
}
