// EdgePainter：在画布垫底层绘制连线（Workspace v2 稿）。
//
// 几何与 hitTestEdge 同源（util/edge_geometry.dart）。视觉：1.5px 三次贝塞尔，
// 默认 fg6；与选中节点相连的边 accent（「当前链路」）；narrative 与 reference
// 角色用 4/3 虚线（弱关联）；终点 8×8 开口箭头 marker（refX=7，尖端落在端口外缘）。
// 多入边的 video 节点在连线中段标注角色（起始帧 accent / 结束帧 fg5）。
// 端口圆点由 NodeCard 自己画，本层不画。
import 'package:flutter/material.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../util/edge_geometry.dart';
import '../util/lane_geometry.dart';

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.neutralColor,
    required this.arrowColor,
    required this.accentColor,
    required this.labelStyle,
    required this.firstFrameLabel,
    required this.lastFrameLabel,
    this.direction = LaneDirection.horizontal,
    this.selectedNodeIds = const <String>{},
    this.selectedEdgeId,
    this.dragNodeId,
    this.dragDelta = Offset.zero,
  });

  final List<CanvasEdge> edges;
  final List<CanvasNode> nodes;
  final Color neutralColor;
  final Color arrowColor;
  final Color accentColor;

  /// 角色标注字体（10px micro），颜色由本层按角色覆盖。
  final TextStyle labelStyle;
  final String firstFrameLabel;
  final String lastFrameLabel;

  /// 泳道主轴——决定出/入锚点方位与曲线走向。
  final LaneDirection direction;

  /// 与这些节点相连的边视为「当前链路」→ accent。
  final Set<String> selectedNodeIds;
  final String? selectedEdgeId;

  /// 拖拽中节点及其实时位移——连线跟手（拖拽位移未提交 controller 前先补到锚点上）。
  final String? dragNodeId;
  final Offset dragDelta;

  @override
  void paint(Canvas canvas, Size size) {
    if (edges.isEmpty || nodes.isEmpty) return;
    final nodeById = <String, CanvasNode>{for (final n in nodes) n.id: n};

    // 多入边（≥2 条 data 入边）的靶节点才标注角色。
    final inCount = <String, int>{};
    for (final e in edges) {
      if (e.edgeType == EdgeType.data) {
        inCount[e.targetNodeId] = (inCount[e.targetNodeId] ?? 0) + 1;
      }
    }

    for (final edge in edges) {
      final src = nodeById[edge.sourceNodeId];
      final dst = nodeById[edge.targetNodeId];
      if (src == null || dst == null) continue;
      var p1 = edgeSourceAnchor(src, direction: direction);
      var p2 = edgeTargetAnchor(dst, direction: direction);
      if (src.id == dragNodeId) p1 += dragDelta;
      if (dst.id == dragNodeId) p2 += dragDelta;

      final bool onChain = edge.id == selectedEdgeId ||
          selectedNodeIds.contains(src.id) ||
          selectedNodeIds.contains(dst.id);
      final bool weak = edge.edgeType == EdgeType.narrative ||
          (edge.edgeType == EdgeType.data && edge.role == EdgeRole.reference &&
              (inCount[dst.id] ?? 0) > 1);
      final Color lineColor = onChain ? accentColor : neutralColor;

      final line = Paint()
        ..color = lineColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = edgePath(p1, p2, direction: direction);
      canvas.drawPath(weak ? _dashed(path, 4, 3) : path, line);
      _drawArrowHead(canvas, p1, p2, onChain ? accentColor : arrowColor);

      if ((inCount[dst.id] ?? 0) > 1 && edge.edgeType == EdgeType.data) {
        final String? text = switch (edge.role) {
          EdgeRole.firstFrame => firstFrameLabel,
          EdgeRole.lastFrame => lastFrameLabel,
          EdgeRole.reference => null,
        };
        if (text != null) {
          final mid = edgePathMidpoint(p1, p2, direction: direction);
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: labelStyle.copyWith(
                color: edge.role == EdgeRole.firstFrame ? accentColor : arrowColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          // 稿：标注贴在曲线中段上方偏右。
          tp.paint(canvas, mid + Offset(-tp.width / 2, -tp.height - 2));
        }
      }
    }
  }

  static Path _dashed(Path src, double on, double off) {
    final out = Path();
    for (final metric in src.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + on).clamp(0.0, metric.length).toDouble();
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  /// 8×8 开口箭头：marker 坐标系 x 轴沿终点切线，refX=7 ⇒ 尖端落在终点。
  void _drawArrowHead(Canvas canvas, Offset from, Offset tip, Color color) {
    final Offset dir = direction == LaneDirection.horizontal
        ? const Offset(1, 0)
        : const Offset(0, 1);
    final Offset nrm = Offset(-dir.dy, dir.dx);
    Offset m(double x, double y) => tip + dir * (x - 7) + nrm * (y - 4);
    final head = Path()
      ..moveTo(m(0, 0.5).dx, m(0, 0.5).dy)
      ..lineTo(m(7, 4).dx, m(7, 4).dy)
      ..lineTo(m(0, 7.5).dx, m(0, 7.5).dy);
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant EdgePainter old) {
    return old.edges != edges ||
        old.nodes != nodes ||
        old.neutralColor != neutralColor ||
        old.arrowColor != arrowColor ||
        old.accentColor != accentColor ||
        old.direction != direction ||
        old.selectedNodeIds != selectedNodeIds ||
        old.selectedEdgeId != selectedEdgeId ||
        old.dragNodeId != dragNodeId ||
        old.dragDelta != dragDelta;
  }
}
