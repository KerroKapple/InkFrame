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
  });
}
