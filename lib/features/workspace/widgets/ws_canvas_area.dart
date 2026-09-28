// 画布区：28px 画布头 + 网格底（24px，canvasGrid 线）+ 泳道 + 连线 + 节点 + 缩放条 + 提示词条 + FAB。
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import 'ws_node_card.dart';
import '../../../theme/components/ws_primitives.dart';
import 'ws_tone.dart';

class WsCanvasArea extends StatelessWidget {
  const WsCanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return ColoredBox(
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 29, // content 28 + border-bottom 1
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(bottom: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                Text(WorkspaceFixture.canvasTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Container(width: 1, height: 12, color: c.control),
                const SizedBox(width: InkSpacing.s12),
                Text.rich(
                  TextSpan(
                    style: t.body.copyWith(color: c.fg5),
                    children: <InlineSpan>[
                      const TextSpan(text: WorkspaceFixture.lanesPrefix),
                      TextSpan(text: WorkspaceFixture.laneNames[0], style: TextStyle(color: c.fg3)),
                      const TextSpan(text: ' · '),
                      TextSpan(text: WorkspaceFixture.laneNames[1], style: TextStyle(color: c.fg3)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(WorkspaceFixture.zoom, style: t.mono.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s12),
                Text(WorkspaceFixture.autosave, style: t.body.copyWith(color: c.fg5)),
              ],
            ),
          ),
          const Expanded(child: _CanvasViewport()),
        ],
      ),
    );
  }
}

class _CanvasViewport extends StatelessWidget {
  const _CanvasViewport();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _GridPainter(c.canvasGrid))),
          // 泳道 A：top 20，高 380，上下 1px laneDivider
          Positioned(
            left: 0,
            right: 0,
            top: 20,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.laneDivider),
                  bottom: BorderSide(color: c.laneDivider),
                ),
              ),
            ),
          ),
          Positioned(left: 12, top: 26, child: Text(WorkspaceFixture.laneLabels[0], style: t.meta.copyWith(color: c.fg6))),
          Positioned(left: 12, top: 410, child: Text(WorkspaceFixture.laneLabels[1], style: t.meta.copyWith(color: c.fg6))),
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgePainter(edges: WorkspaceFixture.edges, neutral: c.fg6, accent: c.accent, arrowNeutral: c.fg5),
            ),
          ),
          for (final WsEdgeLabel l in WorkspaceFixture.edgeLabels)
            Positioned(left: l.x, top: l.y, child: Text(l.text, style: t.micro.copyWith(color: l.tone.fg(c)))),
          for (final WsNode n in WorkspaceFixture.nodes)
            Positioned(left: n.x, top: n.y, child: WsNodeCard(node: n)),
          const Positioned(right: 12, bottom: 56, child: _ZoomBar()),
          const Positioned(left: 0, right: 0, bottom: 16, child: Center(child: _PromptBar())),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(InkRadius.s3)),
              child: CustomPaint(size: const Size(12, 12), painter: _PlusGlyph(c.onAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

/// 连线：1.5px 三次贝塞尔 + 8×8 箭头 marker（refX=7，沿切线朝向），弱关联 4/3 虚线。
class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.edges, required this.neutral, required this.accent, required this.arrowNeutral});
  final List<WsEdge> edges;
  final Color neutral;
  final Color accent;
  final Color arrowNeutral;

  @override
  void paint(Canvas canvas, Size size) {
    for (final WsEdge e in edges) {
      final bool isAccent = e.tone == WsTone.accent;
      final Paint line = Paint()
        ..color = isAccent ? accent : neutral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final Path path = Path()
        ..moveTo(e.from.dx, e.from.dy)
        ..cubicTo(e.c1.dx, e.c1.dy, e.c2.dx, e.c2.dy, e.to.dx, e.to.dy);
      canvas.drawPath(e.dashed ? _dash(path, 4, 3) : path, line);

      // 箭头：marker 坐标系 x 轴沿终点切线；refX=7 ⇒ 尖端落在终点。
      final Offset dir = (e.to - e.c2).distance == 0 ? const Offset(1, 0) : (e.to - e.c2) / (e.to - e.c2).distance;
      final Offset nrm = Offset(-dir.dy, dir.dx);
      Offset m(double x, double y) => e.to + dir * (x - 7) + nrm * (y - 4);
      final Paint arrow = Paint()
        ..color = isAccent ? accent : arrowNeutral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      final Path head = Path()
        ..moveTo(m(0, 0.5).dx, m(0, 0.5).dy)
        ..lineTo(m(7, 4).dx, m(7, 4).dy)
        ..lineTo(m(0, 7.5).dx, m(0, 7.5).dy);
      canvas.drawPath(head, arrow);
    }
  }

  static Path _dash(Path src, double on, double off) {
    final Path out = Path();
    for (final ui.PathMetric metric in src.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double end = (d + on).clamp(0, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges || old.neutral != neutral || old.accent != accent;
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TextStyle glyph = t.body.copyWith(color: c.fg3);
    return Container(
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 27, // content 26 + border-right 1
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: c.control))),
            child: Text('−', style: glyph),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            child: Text(WorkspaceFixture.zoom, style: t.mono.copyWith(color: c.fg3)),
          ),
          Container(
            width: 27, // content 26 + border-left 1
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(left: BorderSide(color: c.control))),
            child: Text('+', style: glyph),
          ),
          Container(
            width: 41, // content 40 + border-left 1
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(left: BorderSide(color: c.control))),
            child: Text(WorkspaceFixture.fit, style: t.meta.copyWith(color: c.fg3)),
          ),
        ],
      ),
    );
  }
}

/// 底部提示词条 640px：rgba(38,38,38,0.96) 底 + control 边 + 6px 圆角 + 0 10 30 阴影，两行。
class _PromptBar extends StatelessWidget {
  const _PromptBar();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: 668, // content 640 + padding 14+12 + border 2
      padding: const EdgeInsets.fromLTRB(InkSpacing.s14, InkSpacing.s10, InkSpacing.s12, InkSpacing.s10),
      decoration: BoxDecoration(
        color: c.surface4.withValues(alpha: 0.96),
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              WsSquareDot(size: 6, color: c.accent),
              const SizedBox(width: InkSpacing.sm),
              Text(WorkspaceFixture.promptTarget, style: t.meta.copyWith(color: c.fg2)),
              const SizedBox(width: InkSpacing.sm),
              Text('·', style: t.meta.copyWith(color: c.fg5)),
              const SizedBox(width: InkSpacing.sm),
              Text(WorkspaceFixture.promptModel, style: t.meta.copyWith(color: c.fg5)),
              const Spacer(),
              Text(WorkspaceFixture.promptStyle, style: t.meta.copyWith(color: c.fg5)),
              const SizedBox(width: InkSpacing.sm),
              Text(WorkspaceFixture.promptAttached, style: t.meta.copyWith(color: c.accent)),
            ],
          ),
          const SizedBox(height: InkSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Text.rich(
                    TextSpan(
                      text: WorkspaceFixture.promptText,
                      style: t.body.copyWith(color: c.fg1, height: 1.5),
                      children: <InlineSpan>[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Container(width: 1, height: 14, color: c.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: InkSpacing.s10),
              // 稿：右侧一组 align-items:center，整组再贴文本框底部。
              Row(
                children: <Widget>[
                  Text(WorkspaceFixture.promptCount, style: t.monoSmall.copyWith(color: c.fg6)),
                  const SizedBox(width: InkSpacing.sm),
                  Text(WorkspaceFixture.promptCost, style: t.mono.copyWith(color: c.fg5)),
                  const SizedBox(width: InkSpacing.sm),
                  WsPrimaryButton(
                    WorkspaceFixture.generate,
                    height: 28,
                    horizontalPadding: InkSpacing.s14,
                    bordered: false,
                    trailing: Opacity(
                      opacity: 0.7,
                      child: Text(WorkspaceFixture.generateShortcut, style: t.monoSmall.copyWith(color: c.onAccent)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FAB 的「+」：稿上是 20px 字形，这里画 12×12 十字，1.5 描边。
class _PlusGlyph extends CustomPainter {
  const _PlusGlyph(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
  }

  @override
  bool shouldRepaint(_PlusGlyph old) => old.color != color;
}
