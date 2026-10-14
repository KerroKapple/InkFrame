// 图标集 v1 的数据自检：每个图标都有笔画，每一笔都能解析、非空、落在 20×20 网格里。
//
// 路径数据与设计稿逐字相同（见 ink_glyph.dart 头注）。这里不比对稿，只守住
// 「抄过来的数据画得出来、且不出格」——改稿后整条替换时抄错一个字母，先在这里红。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/icons/svg_path_data.dart';
import 'package:inkframe/theme/tokens.dart';

/// 允许的范围：网格本身外扩半个描边宽——路径贴着网格边时，描边会画出去这么多。
const double _halfStroke = InkIconSize.gridStroke / 2;
const Rect _allowed = Rect.fromLTRB(
  -_halfStroke,
  -_halfStroke,
  InkIconSize.grid + _halfStroke,
  InkIconSize.grid + _halfStroke,
);

void main() {
  test('网格常量：20 网格、1.5 描边（路径数据就是按这个画的）', () {
    expect(InkIconSize.grid, 20);
    expect(InkIconSize.gridStroke, 1.5);
  });

  for (final InkGlyph glyph in InkGlyph.values) {
    test('${glyph.name}：有笔画，每一笔都能解析、非空、落在网格内', () {
      expect(glyph.parts, isNotEmpty, reason: '${glyph.name} 一笔都没有');
      for (int i = 0; i < glyph.parts.length; i++) {
        final InkGlyphPart part = glyph.parts[i];
        final String where = '${glyph.name} 第 ${i + 1} 笔';
        final Path path;
        try {
          path = parseSvgPathData(part.data);
        } on FormatException catch (e) {
          fail('$where 解析失败：$e');
        }
        final Rect b = path.getBounds();
        expect(b.width > 0 || b.height > 0, isTrue, reason: '$where 是空路径');
        expect(b.left, greaterThanOrEqualTo(_allowed.left), reason: '$where 左侧出格：$b');
        expect(b.top, greaterThanOrEqualTo(_allowed.top), reason: '$where 上方出格：$b');
        expect(b.right, lessThanOrEqualTo(_allowed.right), reason: '$where 右侧出格：$b');
        expect(b.bottom, lessThanOrEqualTo(_allowed.bottom), reason: '$where 下方出格：$b');
      }
    });
  }

  test('没有两个图标的笔画完全相同（防整条替换时复制粘贴串了行）', () {
    final Map<String, InkGlyph> seen = <String, InkGlyph>{};
    for (final InkGlyph glyph in InkGlyph.values) {
      final String signature = glyph.parts
          .map((InkGlyphPart p) => '${p.filled ? 'fill' : 'stroke'}:${p.data}')
          .join('|');
      final InkGlyph? clash = seen[signature];
      expect(clash, isNull, reason: '${glyph.name} 与 ${clash?.name} 的笔画完全相同');
      seen[signature] = glyph;
    }
  });
}
