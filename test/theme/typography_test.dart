import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/typography.dart';

void main() {
  group('InkTypography Amber Noir', () {
    test('display uses CormorantGaramond Light 48pt', () {
      final t = InkTypography.defaults();
      expect(t.display.fontFamily, 'CormorantGaramond');
      expect(t.display.fontWeight, FontWeight.w300);
      expect(t.display.fontSize, 48);
    });

    test('headline uses CormorantGaramond Regular 22pt', () {
      final t = InkTypography.defaults();
      expect(t.headline.fontFamily, 'CormorantGaramond');
      expect(t.headline.fontWeight, FontWeight.w400);
      expect(t.headline.fontSize, 22);
    });

    test('caption uses JetBrainsMono 11pt', () {
      final t = InkTypography.defaults();
      expect(t.caption.fontFamily, 'JetBrainsMono');
      expect(t.caption.fontSize, 11);
    });

    test('scaled(1.5) applies to headline too', () {
      final t = InkTypography.defaults().scaled(1.5);
      expect(t.headline.fontSize, 22 * 1.5);
    });

    test('display has CJK fallback', () {
      final t = InkTypography.defaults();
      expect(t.display.fontFamilyFallback, contains('PingFang SC'));
    });

    test('headline has CJK fallback', () {
      final t = InkTypography.defaults();
      expect(t.headline.fontFamilyFallback, contains('PingFang SC'));
    });

    test('caption has mono and CJK fallback', () {
      final t = InkTypography.defaults();
      expect(t.caption.fontFamilyFallback, contains('Menlo'));
      expect(t.caption.fontFamilyFallback, contains('PingFang SC'));
    });

    test('scaled() preserves fontFamilyFallback on display', () {
      final t = InkTypography.defaults().scaled(1.5);
      expect(t.display.fontFamilyFallback, contains('PingFang SC'));
    });
  });

  group('InkTypography 扩展档位（HI-24 / HI-25）', () {
    test('headlineSm / headlineXs 为 Cormorant 18/16', () {
      final t = InkTypography.defaults();
      expect(t.headlineSm.fontFamily, 'CormorantGaramond');
      expect(t.headlineSm.fontSize, 18);
      expect(t.headlineXs.fontFamily, 'CormorantGaramond');
      expect(t.headlineXs.fontSize, 16);
    });

    test('monoNano / monoMicro / overline 为 JetBrainsMono 档位', () {
      final t = InkTypography.defaults();
      expect(t.monoNano.fontFamily, 'JetBrainsMono');
      expect(t.monoNano.fontSize, 9);
      expect(t.monoNano.letterSpacing, 1.8);
      expect(t.monoMicro.fontFamily, 'JetBrainsMono');
      expect(t.monoMicro.fontSize, 10);
      expect(t.overline.fontFamily, 'JetBrainsMono');
      expect(t.overline.fontSize, 11);
      expect(t.overline.letterSpacing, 1.8);
    });

    test('mono 档位带等宽 + CJK fallback', () {
      final t = InkTypography.defaults();
      for (final s in [t.monoNano, t.monoMicro, t.overline]) {
        expect(s.fontFamilyFallback, contains('Menlo'));
        expect(s.fontFamilyFallback, contains('PingFang SC'));
      }
    });

    test('scaled(1.5) 覆盖全部新档位（a11y 缩放不丢失）', () {
      final t = InkTypography.defaults().scaled(1.5);
      expect(t.headlineSm.fontSize, 18 * 1.5);
      expect(t.headlineXs.fontSize, 16 * 1.5);
      expect(t.monoNano.fontSize, 9 * 1.5);
      expect(t.monoMicro.fontSize, 10 * 1.5);
      expect(t.overline.fontSize, 11 * 1.5);
    });

    test('defaults(scale:) 同样作用于新档位', () {
      final t = InkTypography.defaults(scale: 1.25);
      expect(t.headlineSm.fontSize, 18 * 1.25);
      expect(t.overline.fontSize, 11 * 1.25);
    });
  });
}
