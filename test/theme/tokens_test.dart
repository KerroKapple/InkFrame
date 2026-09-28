import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';
import 'package:inkframe/theme/typography.dart';

import 'wcag.dart';

/// 三变体统一遍历：任何"只测 dark"的断言都会让 light / hc 写反照绿。
const List<(String, InkColors Function())> _variants =
    <(String, InkColors Function())>[
  ('dark', InkColors.dark),
  ('light', InkColors.light),
  ('highContrast', InkColors.highContrast),
];

void main() {
  group('InkColors 中性灰三变体', () {
    test('dark：surface2 是不透明的深灰', () {
      final c = InkColors.dark();
      expect(c.surface2.a, 1.0);
      expect(c.surface2.computeLuminance(), lessThan(0.1));
    });

    test('light：surface2 高亮度', () {
      expect(InkColors.light().surface2.computeLuminance(), greaterThan(0.8));
    });

    test('highContrast：纯黑底 + 纯白字', () {
      final c = InkColors.highContrast();
      expect(c.surface0, const Color(0xFF000000));
      expect(c.surface1, const Color(0xFF000000));
      expect(c.surface2, const Color(0xFF000000));
      expect(c.fg1, const Color(0xFFFFFFFF));
    });

    test('dark 变体精确取值（README §Design Tokens）', () {
      final c = InkColors.dark();
      expect(c.surface0, const Color(0xFF141414));
      expect(c.surface1, const Color(0xFF1A1A1A));
      expect(c.surface2, const Color(0xFF1D1D1D));
      expect(c.surface3, const Color(0xFF232323));
      expect(c.surface4, const Color(0xFF262626));
      expect(c.surface5, const Color(0xFF2E2E2E));
      expect(c.borderStrong, const Color(0xFF0F0F0F));
      expect(c.borderSubtle, const Color(0xFF1F1F1F));
      expect(c.outline, const Color(0xFF2C2C2C));
      expect(c.control, const Color(0xFF3A3A3A));
      expect(c.controlStrong, const Color(0xFF3F3F3F));
      expect(c.overlayBorder, const Color(0xFF4A4A4A));
      expect(c.fg1, const Color(0xFFE8E8E8));
      expect(c.fg2, const Color(0xFFD6D6D6));
      expect(c.fg3, const Color(0xFFC8C8C8));
      expect(c.fg4, const Color(0xFF9E9E9E));
      expect(c.fg5, const Color(0xFF8A8A8A));
      expect(c.fg6, const Color(0xFF6B6B6B));
      expect(c.accent, const Color(0xFFC9A85B));
      expect(c.accentHover, const Color(0xFFD8B96C));
      expect(c.onAccent, const Color(0xFF1D1D1D));
      expect(c.accentWash, const Color(0xFF2A2318));
      expect(c.accentWashBorder, const Color(0xFF6B5A38));
      expect(c.success, const Color(0xFF7FB069));
      expect(c.danger, const Color(0xFFD25A4A)); // 用户改口：README 值对比不足
      expect(c.audioFill, const Color(0xFF22301F));
      expect(c.audioBorder, const Color(0xFF3A5334));
      expect(c.audioFg, const Color(0xFF8FB07E));
    });

    test('light 变体精确取值', () {
      final c = InkColors.light();
      expect(c.surface0, const Color(0xFFE4E4E4));
      expect(c.surface1, const Color(0xFFF4F4F4));
      expect(c.surface2, const Color(0xFFF8F8F8));
      expect(c.surface3, const Color(0xFFEFEFEF));
      expect(c.surface4, const Color(0xFFFFFFFF));
      expect(c.surface5, const Color(0xFFE2E2E2));
      expect(c.fg1, const Color(0xFF1A1A1A));
      expect(c.fg6, const Color(0xFF8E8E8E));
      expect(c.accent, const Color(0xFF8C6A30));
      expect(c.onAccent, const Color(0xFFFFFFFF));
      expect(c.accentWash, const Color(0xFFF3ECDC));
    });

    test('highContrast 变体精确取值', () {
      final c = InkColors.highContrast();
      expect(c.surface3, const Color(0xFF0A0A0A));
      expect(c.surface4, const Color(0xFF0A0A0A));
      expect(c.surface5, const Color(0xFF2A2A2A));
      expect(c.fg4, const Color(0xFFD0D0D0));
      expect(c.accent, const Color(0xFFFFD060));
      expect(c.onAccent, const Color(0xFF000000));
    });

    // HC 下分隔线不可能比纯白更强——六个描边槽同值是刻意的。
    test('highContrast：六个描边槽全部纯白', () {
      final c = InkColors.highContrast();
      for (final Color b in <Color>[
        c.borderStrong,
        c.borderSubtle,
        c.outline,
        c.control,
        c.controlStrong,
        c.overlayBorder,
      ]) {
        expect(b, const Color(0xFFFFFFFF));
      }
    });

    test('scrim 三变体都是半透明遮罩（README rgba(10,10,10,0.55)）', () {
      for (final (name, make) in _variants) {
        final c = make();
        expect(c.scrim.a, lessThan(1.0), reason: '$name scrim 必须半透明');
      }
      expect(InkColors.dark().scrim, const Color(0x8C0A0A0A));
    });

    // 方向性：dark / hc 的选中态靠提亮，light 的选中态靠压暗。
    test('surface5 方向：dark/hc 亮于 surface4，light 暗于 surface3', () {
      for (final c in <InkColors>[InkColors.dark(), InkColors.highContrast()]) {
        expect(
          c.surface5.computeLuminance(),
          greaterThan(c.surface4.computeLuminance()),
        );
      }
      final l = InkColors.light();
      expect(
        l.surface5.computeLuminance(),
        lessThan(l.surface3.computeLuminance()),
      );
    });

    // 防复制：图省事把相邻槽位复制成同值，选中态 / 标题与正文视觉不可区分，
    // 而所有功能测试照绿。
    test('防复制：surface5 ≠ surface4（三变体），fg1 ≠ fg2（dark / light）', () {
      for (final (name, make) in _variants) {
        expect(make().surface5, isNot(make().surface4), reason: name);
      }
      // highContrast 的 fg1–fg3 按任务书刻意全取纯白（层级靠字重与位置），
      // 故 fg1 ≠ fg2 只对 dark / light 成立。
      for (final c in <InkColors>[InkColors.dark(), InkColors.light()]) {
        expect(c.fg1, isNot(c.fg2));
      }
    });

    test('对比：fg2 × surface3 与 onAccent × accent 均 ≥ 4.5', () {
      for (final (name, make) in _variants) {
        final c = make();
        expect(
          wcagContrast(c.fg2, c.surface3),
          greaterThanOrEqualTo(4.5),
          reason: '$name fg2 × surface3',
        );
        expect(
          wcagContrast(c.onAccent, c.accent),
          greaterThanOrEqualTo(4.5),
          reason: '$name onAccent × accent',
        );
      }
    });

    test('每个变体暴露全部 32 个槽位（README 表 28 + scrim + 画布专用 3）', () {
      for (final (_, make) in _variants) {
        final c = make();
        final List<Color> all = <Color>[
          c.surface0,
          c.surface1,
          c.surface2,
          c.surface3,
          c.surface4,
          c.surface5,
          c.borderStrong,
          c.borderSubtle,
          c.outline,
          c.control,
          c.controlStrong,
          c.overlayBorder,
          c.fg1,
          c.fg2,
          c.fg3,
          c.fg4,
          c.fg5,
          c.fg6,
          c.accent,
          c.accentHover,
          c.onAccent,
          c.accentWash,
          c.accentWashBorder,
          c.success,
          c.danger,
          c.audioFill,
          c.audioBorder,
          c.audioFg,
          c.scrim,
          c.canvasGrid,
          c.laneDivider,
          c.thumbFill,
        ];
        expect(all.length, 32);
      }
    });
  });

  group('InkPalette 启动常量与主题工厂一致', () {
    test('surface0Dark == InkColors.dark().surface0', () {
      expect(InkPalette.surface0Dark, InkColors.dark().surface0);
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

    test('半阶间距档位（ME-17：消除 token 算术）', () {
      expect(InkSpacing.s10, 10);
      expect(InkSpacing.s12, 12);
      expect(InkSpacing.s14, 14);
      expect(InkSpacing.s18, 18);
      expect(InkSpacing.s28, 28);
    });

    test('radius 覆盖 README 四档 2 / 3 / 4 / 6', () {
      expect(InkRadius.xs, 2);
      expect(InkRadius.s3, 3);
      expect(InkRadius.sm, 4);
      expect(InkRadius.bentoBtn, 6);
    });
  });

  group('InkShadow', () {
    test('浮层阴影取 README 值 0 24px 64px rgba(0,0,0,0.6)', () {
      final BoxShadow s = InkShadow.overlay.single;
      expect(s.offset, const Offset(0, 24));
      expect(s.blurRadius, 64);
      expect(s.color, const Color(0x99000000));
    });
  });

  group('InkTypography scaling', () {
    test('defaults produce body fontSize 12', () {
      expect(InkTypography.defaults().body.fontSize, 12);
    });

    test('scaled(1.25) multiplies every size', () {
      final t = InkTypography.defaults().scaled(1.25);
      expect(t.body.fontSize, 12 * 1.25);
      expect(t.sectionTitle.fontSize, 15 * 1.25);
      expect(t.dialogTitle.fontSize, 17 * 1.25);
      expect(t.micro.fontSize, 10 * 1.25);
    });
  });

  group('buildAppTheme', () {
    testWidgets('context.inkColors returns the dark palette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: Builder(
            builder: (ctx) {
              final c = ctx.inkColors;
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
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: Builder(
            builder: (ctx) {
              expect(
                Theme.of(ctx).colorScheme.primary,
                const Color(0xFFC9A85B),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('scaffoldBackgroundColor 取 surface2（应用主体默认底）',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: Builder(
            builder: (ctx) {
              expect(
                Theme.of(ctx).scaffoldBackgroundColor,
                InkColors.dark().surface2,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    // 彩底前景锁 AA：primary / secondary 都是琥珀，onPrimary 走 onAccent。
    for (final variant in InkThemeVariant.values) {
      test('$variant: ColorScheme primary/secondary on-color 对比率 ≥4.5', () {
        final scheme =
            buildAppTheme(variant: variant, textScale: 1).colorScheme;
        expect(
          wcagContrast(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '$variant primary/onPrimary',
        );
        expect(
          wcagContrast(scheme.secondary, scheme.onSecondary),
          greaterThanOrEqualTo(4.5),
          reason: '$variant secondary/onSecondary',
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
