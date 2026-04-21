// EdgePainter：在画布垫底层绘制连线。
//
// 简化策略：直线段 + 箭头（source 节点中心 → target 节点中心），不走贝塞尔。
// 交互（点击选中 / 悬停高亮）留给后续 PR——当前 IgnorePointer 挂在父层。

import 'package:flutter/material.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.dataColor,
    required this.narrativeColor,
    required this.generationSourceColor,
  });

  final List<CanvasEdge> edges;
  final List<CanvasNode> nodes;
  final Color dataColor;
  final Color narrativeColor;
  final Color generationSourceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (edges.isEmpty || nodes.isEmpty) return;
    final nodeById = <String, CanvasNode>{
      for (final n in nodes) n.id: n,
    };

    for (final edge in edges) {
      final src = nodeById[edge.sourceNodeId];
      final dst = nodeById[edge.targetNodeId];
      if (src == null || dst == null) continue;
      final p1 = _centerOf(src);
      final p2 = _centerOf(dst);

      final paint = Paint()
        ..color = _colorFor(edge.edgeType)
        ..strokeWidth = edge.edgeType == EdgeType.data ? 2.0 : 1.0
        ..style = PaintingStyle.stroke;

      if (edge.edgeType == EdgeType.narrative) {
        _drawDashedLine(canvas, p1, p2, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
      }

      _drawArrowHead(canvas, p1, p2, paint);
    }
  }

  Color _colorFor(EdgeType t) => switch (t) {
        EdgeType.data => dataColor,
        EdgeType.narrative => narrativeColor,
        EdgeType.generationSource => generationSourceColor,
      };

  Offset _centerOf(CanvasNode n) => Offset(
        n.position.dx + n.size.width / 2,
        n.position.dy + n.size.height / 2,
      );

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = (drawn + dashLen).clamp(0.0, total).toDouble();
      canvas.drawLine(a + dir * drawn, a + dir * segEnd, paint);
      drawn = segEnd + gapLen;
    }
  }

  void _drawArrowHead(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dir = b - a;
    final length = dir.distance;
    if (length < 1) return;
    final unit = dir / length;
    const arrowSize = 8.0;
    final perp = Offset(-unit.dy, unit.dx);
    final tip = b;
    final base1 = tip - unit * arrowSize + perp * (arrowSize * 0.5);
    final base2 = tip - unit * arrowSize - perp * (arrowSize * 0.5);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base1.dx, base1.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();
    final fill = Paint()..color = paint.color;
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.nodes != nodes ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.narrativeColor != narrativeColor ||
        oldDelegate.generationSourceColor != generationSourceColor;
  }
}
