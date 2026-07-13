// EdgePainter：在画布垫底层绘制连线（CineFlow 式端口曲线）。
//
// 几何与 hitTestEdge 同源（util/edge_geometry.dart）：源节点右边中点出、
// 靶节点左边中点入，三次贝塞尔；两端画端口圆点，靶端沿切线画箭头。
// 交互（点击选中 / 悬停高亮）留给后续 PR——当前 IgnorePointer 挂在父层。

import 'package:flutter/material.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../util/edge_geometry.dart';

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.dataColor,
    required this.narrativeColor,
    required this.generationSourceColor,
    required this.selectedColor,
    this.selectedEdgeId,
  });

  final List<CanvasEdge> edges;
  final List<CanvasNode> nodes;
  final Color dataColor;
  final Color narrativeColor;
  final Color generationSourceColor;
  final Color selectedColor;
  final String? selectedEdgeId;

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
      final p1 = edgeSourceAnchor(src);
      final p2 = edgeTargetAnchor(dst);
      final isSelected = edge.id == selectedEdgeId;

      final paint = Paint()
        ..color = isSelected ? selectedColor : _colorFor(edge.edgeType)
        ..strokeWidth = isSelected
            ? 3.0
            : edge.edgeType == EdgeType.data
                ? 2.0
                : 1.0
        ..style = PaintingStyle.stroke;

      final path = edgePath(p1, p2);
      if (edge.edgeType == EdgeType.narrative) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }

      _drawArrowHead(canvas, p2, paint);
      _drawPort(canvas, p1, paint.color);
      _drawPort(canvas, p2, paint.color);
    }
  }

  Color _colorFor(EdgeType t) => switch (t) {
        EdgeType.data => dataColor,
        EdgeType.narrative => narrativeColor,
        EdgeType.generationSource => generationSourceColor,
      };

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      var drawn = 0.0;
      while (drawn < metric.length) {
        final segEnd = (drawn + dashLen).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(drawn, segEnd), paint);
        drawn = segEnd + gapLen;
      }
    }
  }

  /// 端口圆点：进/出锚点上的实心圆（半覆盖在卡片边缘上，读作端口凸点）。
  void _drawPort(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, kEdgePortRadius, Paint()..color = color);
  }

  /// 靶端箭头：曲线入左端口，末端切线恒为 +x 方向——箭头水平指向端口。
  void _drawArrowHead(Canvas canvas, Offset tip, Paint paint) {
    const arrowSize = 8.0;
    final base = tip - const Offset(arrowSize + kEdgePortRadius, 0);
    final path = Path()
      ..moveTo(tip.dx - kEdgePortRadius, tip.dy)
      ..lineTo(base.dx, base.dy + arrowSize * 0.5)
      ..lineTo(base.dx, base.dy - arrowSize * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.nodes != nodes ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.narrativeColor != narrativeColor ||
        oldDelegate.generationSourceColor != generationSourceColor ||
        oldDelegate.selectedColor != selectedColor ||
        oldDelegate.selectedEdgeId != selectedEdgeId;
  }
}
