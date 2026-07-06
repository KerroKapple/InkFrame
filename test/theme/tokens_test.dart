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

    test('every variant exposes the 10 new design-token slots', () {
      for (final InkColors c in <InkColors>[
        InkColors.dark(),
        InkColors.light(),
        InkColors.highContrast(),
      ]) {
        expect(c.surfaceCanvas, isA<Color>());
        expect(c.surface4, isA<Color>());
        expect(c.borderSubtle, isA<Color>());
        expect(c.borderHover, isA<Color>());
        expect(c.fg4, isA<Color>());
        expect(c.accentHover, isA<Color>());
        expect(c.accentPressed, isA<Color>());
        expect(c.info, isA<Color>());
        expect(c.cta, isA<Color>());
        expect(c.ctaHover, isA<Color>());
      }
    });

    test('dark variant exact palette values (Amber Noir)', () {
      final c = InkColors.dark();
      expect(c.surfaceCanvas, const Color(0xFF0B0908));
      expect(c.surface1, const Color(0xFF100C0A));
      expect(c.surface2, const Color(0xFF15110E));
      expect(c.surface3, const Color(0xFF1C1814));
      expect(c.surface4, const Color(0xFF2A2520));
      expect(c.accent, const Color(0xFFC9A85B));
      expect(c.accentHover, const Color(0xFFD8B66B));
      expect(c.accentPressed, const Color(0xFFB89A4F));
      expect(c.cta, const Color(0xFFE3A648));
      expect(c.info, const Color(0xFF4B7A92));
      expect(c.fg1, const Color(0xFFE8DFD0));
      expect(c.fg2, const Color(0xFFB5A89A));
      expect(c.fg3, const Color(0xFF8A7E70));
      expect(c.fg4, const Color(0xFF5A5048));
    });

    test('light variant exact palette values (Paper Ivory)', () {
      final c = InkColors.light();
      expect(c.surfaceCanvas, const Color(0xFFF5EFE3));
      expect(c.surface1, const Color(0xFFFAF5EB));
      expect(c.accent, const Color(0xFFA88340));
      expect(c.cta, const Color(0xFFC68B2E));
      expect(c.fg1, const Color(0xFF2A2520));
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

    test('radius includes bento tokens', () {
      expect(InkRadius.bento, 10);
      expect(InkRadius.bentoBtn, 6);
    });

    test('半阶间距档位（ME-17：消除 token 算术）', () {
      expect(InkSpacing.s10, 10);
      expect(InkSpacing.s12, 12);
      expect(InkSpacing.s14, 14);
      expect(InkSpacing.s18, 18);
      expect(InkSpacing.s28, 28);
    });

    test('radius xs 档位（细进度条裁切）', () {
      expect(InkRadius.xs, 2);
    });
  });

  group('inputFill token（ME-18）', () {
    test('三变体均暴露半透明 inputFill', () {
      for (final InkColors c in <InkColors>[
        InkColors.dark(),
        InkColors.light(),
        InkColors.highContrast(),
      ]) {
        expect(c.inputFill, isA<Color>());
        expect(c.inputFill.a, lessThan(1.0)); // 必须半透明（与父面板层叠）
      }
    });

    test('暗色用白色提亮，浅色用深色压暗（不再固定白 overlay）', () {
      // 暗色：fill 比纯黑亮 → 基色是亮色
      final dark = InkColors.dark().inputFill;
      expect(dark.computeLuminance(), greaterThan(0.5));
      // 浅色：fill 基色是暗色
      final light = InkColors.light().inputFill;
      expect(light.computeLuminance(), lessThan(0.5));
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
      expect(t.display.fontSize, 48 * 1.25);
    });

    test('micro / nano 字号 10px / 9px', () {
      final t = InkTypography.defaults();
      expect(t.micro.fontSize, 10);
      expect(t.nano.fontSize, 9);
    });

    test('scaled(1.5) applies to micro / nano too', () {
      final t = InkTypography.defaults().scaled(1.5);
      expect(t.micro.fontSize, 10 * 1.5);
      expect(t.nano.fontSize, 9 * 1.5);
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

    testWidgets('ColorScheme.primary is Amber accent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            variant: InkThemeVariant.dark,
            textScale: 1,
          ),
          home: Builder(
            builder: (ctx) {
              final scheme = Theme.of(ctx).colorScheme;
              expect(scheme.primary, const Color(0xFFC9A85B));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    // 彩色底上的前景 = 画布最底色（对齐 InkAmberButton）——fg1 在暗色变体
    // 是浅米色，放琥珀/危险色上对比度不足（历史 bug）。三变体逐一锁定。
    for (final (variant, colors) in [
      (InkThemeVariant.dark, InkColors.dark()),
      (InkThemeVariant.light, InkColors.light()),
      (InkThemeVariant.highContrast, InkColors.highContrast()),
    ]) {
      testWidgets('$variant: on-color 前景取 surfaceCanvas 而非 fg1',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(variant: variant, textScale: 1),
            home: Builder(
              builder: (ctx) {
                final scheme = Theme.of(ctx).colorScheme;
                expect(scheme.onPrimary, colors.surfaceCanvas);
                expect(scheme.onSecondary, colors.surfaceCanvas);
                expect(scheme.onError, colors.surfaceCanvas);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });
    }

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
