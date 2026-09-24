import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/typography.dart';

/// README §字体：界面通用 Noto Sans SC，回落 PingFang SC → Microsoft YaHei UI。
const List<String> _sansChain = <String>[
  'PingFang SC',
  'Microsoft YaHei UI',
  'Segoe UI Symbol',
];

void main() {
  group('InkTypography 无衬线样式集（README §字体）', () {
    final t = InkTypography.defaults();

    test('八个样式的字号 / 字重 / 行高', () {
      expect((t.body.fontSize, t.body.fontWeight, t.body.height),
          (12.0, FontWeight.w400, 1.45));
      expect((t.bodyStrong.fontSize, t.bodyStrong.fontWeight),
          (12.0, FontWeight.w500));
      expect((t.meta.fontSize, t.meta.height), (11.0, 1.45));
      expect((t.micro.fontSize, t.micro.height), (10.0, 1.3));
      expect((t.sectionTitle.fontSize, t.sectionTitle.fontWeight,
              t.sectionTitle.height),
          (15.0, FontWeight.w500, 1.3));
      expect((t.dialogTitle.fontSize, t.dialogTitle.fontWeight,
              t.dialogTitle.height),
          (17.0, FontWeight.w500, 1.3));
      expect((t.mono.fontSize, t.mono.height), (11.0, 1.0));
      expect((t.monoSmall.fontSize, t.monoSmall.height), (10.0, 1.0));
    });

    test('无衬线样式用 Noto Sans SC + 系统回落链', () {
      for (final s in <TextStyle>[
        t.body,
        t.bodyStrong,
        t.meta,
        t.micro,
        t.sectionTitle,
        t.dialogTitle,
      ]) {
        expect(s.fontFamily, 'Noto Sans SC');
        expect(s.fontFamilyFallback, _sansChain);
      }
    });

    test('等宽样式用 JetBrains Mono + Consolas / Menlo 回落', () {
      for (final s in <TextStyle>[t.mono, t.monoSmall]) {
        expect(s.fontFamily, 'JetBrainsMono');
        expect(s.fontFamilyFallback, contains('Consolas'));
        expect(s.fontFamilyFallback, contains('Menlo'));
      }
    });

    test('任何样式都不带 letterSpacing（旧 kicker 宽字距已废）', () {
      for (final s in t.all) {
        expect(s.letterSpacing, isNull, reason: s.toString());
      }
    });

    test('scaled(1.5) 覆盖全部八档且保留回落链', () {
      final s = InkTypography.defaults().scaled(1.5);
      expect(s.body.fontSize, 12 * 1.5);
      expect(s.bodyStrong.fontSize, 12 * 1.5);
      expect(s.meta.fontSize, 11 * 1.5);
      expect(s.micro.fontSize, 10 * 1.5);
      expect(s.sectionTitle.fontSize, 15 * 1.5);
      expect(s.dialogTitle.fontSize, 17 * 1.5);
      expect(s.mono.fontSize, 11 * 1.5);
      expect(s.monoSmall.fontSize, 10 * 1.5);
      expect(s.body.fontFamilyFallback, _sansChain);
    });

    test('defaults(scale:) 与 scaled() 等价', () {
      final a = InkTypography.defaults(scale: 1.25);
      final b = InkTypography.defaults().scaled(1.25);
      expect(a.dialogTitle.fontSize, b.dialogTitle.fontSize);
    });
  });
}
