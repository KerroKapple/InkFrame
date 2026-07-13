// EdgePainter：在画布垫底层绘制连线（CineFlow 式端口曲线）。
//
// 几何与 hitTestEdge 同源（util/edge_geometry.dart）：沿泳道主轴出入
// （横向右出左入 / 竖向下出上入），三次贝塞尔；两端画端口圆点，
// 靶端沿切线画箭头。
// 交互（点击选中 / 悬停高亮）留给后续 PR——当前 IgnorePointer 挂在父层。

import 'package:flutter/material.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../util/edge_geometry.dart';
import '../util/lane_geometry.dart';

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.dataColor,
    required this.narrativeColor,
    required this.generationSourceColor,
    required this.selectedColor,
    this.direction = LaneDirection.horizontal,
    this.selectedEdgeId,
    this.dragNodeId,
    this.dragDelta = Offset.zero,
  });

  final List<CanvasEdge> edges;
  final List<CanvasNode> nodes;
  final Color dataColor;
  final Color narrativeColor;
  final Color generationSourceColor;
  final Color selectedColor;

  /// 泳道主轴——决定出/入锚点方位与曲线走向。
  final LaneDirection direction;
  final String? selectedEdgeId;

  /// 拖拽中节点及其实时位移——连线跟手（拖拽位移未提交 controller 前先补到锚点上）。
  final String? dragNodeId;
  final Offset dragDelta;

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
      var p1 = edgeSourceAnchor(src, direction: direction);
      var p2 = edgeTargetAnchor(dst, direction: direction);
      if (src.id == dragNodeId) p1 += dragDelta;
      if (dst.id == dragNodeId) p2 += dragDelta;
      final isSelected = edge.id == selectedEdgeId;

      final paint = Paint()
        ..color = isSelected ? selectedColor : _colorFor(edge.edgeType)
        ..strokeWidth = isSelected
            ? 3.0
            : edge.edgeType == EdgeType.data
                ? 2.0
                : 1.0
        ..style = PaintingStyle.stroke;

      final path = edgePath(p1, p2, direction: direction);
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

  /// 靶端箭头：末端切线恒沿主轴正向（横向 +x / 竖向 +y），箭头指向入端口。
  void _drawArrowHead(Canvas canvas, Offset tip, Paint paint) {
    const arrowSize = 8.0;
    final Path path;
    if (direction == LaneDirection.horizontal) {
      final base = tip - const Offset(arrowSize + kEdgePortRadius, 0);
      path = Path()
        ..moveTo(tip.dx - kEdgePortRadius, tip.dy)
        ..lineTo(base.dx, base.dy + arrowSize * 0.5)
        ..lineTo(base.dx, base.dy - arrowSize * 0.5)
        ..close();
    } else {
      final base = tip - const Offset(0, arrowSize + kEdgePortRadius);
      path = Path()
        ..moveTo(tip.dx, tip.dy - kEdgePortRadius)
        ..lineTo(base.dx + arrowSize * 0.5, base.dy)
        ..lineTo(base.dx - arrowSize * 0.5, base.dy)
        ..close();
    }
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
        oldDelegate.direction != direction ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.dragNodeId != dragNodeId ||
        oldDelegate.dragDelta != dragDelta;
  }
}
