// 边点击命中测试——给定 canvas 坐标系下点击点 + 边列表 + 节点列表，
// 返回最接近且距离 ≤ [hitThreshold] 像素的边 id，或 null。
//
// 纯函数，方便单测。几何与 EdgePainter 同源（edge_geometry.dart）：
// 沿泳道主轴出入的三次贝塞尔曲线（横向右出左入 / 竖向下出上入）。

import 'dart:ui';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import 'edge_geometry.dart';
import 'lane_geometry.dart';

String? hitTestEdge({
  required Offset point,
  required List<CanvasEdge> edges,
  required List<CanvasNode> nodes,
  LaneDirection direction = LaneDirection.horizontal,
  double hitThreshold = 10.0,
}) {
  if (edges.isEmpty || nodes.isEmpty) return null;
  final nodeById = <String, CanvasNode>{
    for (final n in nodes) n.id: n,
  };

  String? best;
  double bestDist = double.infinity;

  for (final edge in edges) {
    final src = nodeById[edge.sourceNodeId];
    final dst = nodeById[edge.targetNodeId];
    if (src == null || dst == null) continue;
    final a = edgeSourceAnchor(src, direction: direction);
    final b = edgeTargetAnchor(dst, direction: direction);
    // O(1) 包围盒预筛——远离的边不进采样，保住 O(n+m) 最坏路径。
    if (!edgeBoundsMayHit(point, a, b, hitThreshold, direction: direction)) {
      continue;
    }
    final d = distanceToEdgePath(point, a, b, direction: direction);
    if (d <= hitThreshold && d < bestDist) {
      best = edge.id;
      bestDist = d;
    }
  }

  return best;
}

/// 连线曲线的中点——UI 放删除按钮用（与绘制路径同源）。
Offset edgeMidpoint({
  required CanvasNode source,
  required CanvasNode target,
  LaneDirection direction = LaneDirection.horizontal,
}) =>
    edgePathMidpoint(
      edgeSourceAnchor(source, direction: direction),
      edgeTargetAnchor(target, direction: direction),
      direction: direction,
    );
