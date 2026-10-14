// InkIcon：图标集 v1 的唯一绘制入口。
//
// 路径来自 theme/icons/ink_glyph.dart（与设计稿同一份数据），由 svg_path_data.dart 解析成 Path，
// 在这里按目标尺寸等比缩放后描边 / 填充。单色：颜色显式传入，否则跟随 IconTheme
// （和 Flutter 的 Icon 一样；稿上 SVG 用 currentColor 也是这个意思）。
//
// 没给 [InkIcon.semanticLabel] 时图标对读屏透明：按钮自己的 Semantics 负责说出名字，
// 图标再报一遍只会重复。
import 'package:flutter/widgets.dart';

import '../icons/ink_glyph.dart';
import '../icons/svg_path_data.dart';
import '../tokens.dart';

class InkIcon extends StatelessWidget {
  const InkIcon(
    this.glyph, {
    super.key,
    this.size = InkIconSize.md,
    this.color,
    this.semanticLabel,
  });

  final InkGlyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // IconTheme.of 在没有祖先时也会给出兜底色，所以这里不会是 null。
    final Color resolved = color ?? IconTheme.of(context).color!;
    final Widget painted = CustomPaint(
      size: Size.square(size),
      painter: _InkGlyphPainter(glyph: glyph, color: resolved),
    );
    final String? label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: painted);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: painted),
    );
  }
}

/// 解析好的一笔。
typedef _ParsedPart = ({Path path, bool filled});

/// 每个图标只解析一次：顶层 final 首次访问时求值，之后只读。
final Map<InkGlyph, List<_ParsedPart>> _parsedGlyphs =
    Map<InkGlyph, List<_ParsedPart>>.unmodifiable(<InkGlyph, List<_ParsedPart>>{
  for (final InkGlyph g in InkGlyph.values)
    g: List<_ParsedPart>.unmodifiable(<_ParsedPart>[
      for (final InkGlyphPart p in g.parts)
        (path: parseSvgPathData(p.data), filled: p.filled),
    ]),
});

class _InkGlyphPainter extends CustomPainter {
  const _InkGlyphPainter({required this.glyph, required this.color});

  final InkGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;
    final double scale = side / InkIconSize.grid;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = InkIconSize.gridStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(scale);
    for (final _ParsedPart part in _parsedGlyphs[glyph]!) {
      canvas.drawPath(part.path, part.filled ? fill : stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
