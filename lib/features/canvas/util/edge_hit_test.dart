// 边段点击命中测试——给定 canvas 坐标系下点击点 + 边列表 + 节点列表，
// 返回最接近且距离 ≤ [hitThreshold] 像素的边 id，或 null。
//
// 纯函数，方便单测。坐标系：节点 position 为左上角，连线画中心→中心。

import 'dart:ui';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';

String? hitTestEdge({
  required Offset point,
  required List<CanvasEdge> edges,
  required List<CanvasNode> nodes,
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
    final a = Offset(
      src.position.dx + src.size.width / 2,
      src.position.dy + src.size.height / 2,
    );
    final b = Offset(
      dst.position.dx + dst.size.width / 2,
      dst.position.dy + dst.size.height / 2,
    );
    final d = _distancePointToSegment(point, a, b);
    if (d <= hitThreshold && d < bestDist) {
      best = edge.id;
      bestDist = d;
    }
  }

  return best;
}

/// 点 [p] 到线段 [a]-[b] 的最短距离。
double _distancePointToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  final clamped = t.clamp(0.0, 1.0).toDouble();
  final closest = Offset(a.dx + clamped * ab.dx, a.dy + clamped * ab.dy);
  return (p - closest).distance;
}

/// 两节点中心连线的中点——UI 放删除按钮用。
Offset edgeMidpoint({
  required CanvasNode source,
  required CanvasNode target,
}) {
  final a = Offset(
    source.position.dx + source.size.width / 2,
    source.position.dy + source.size.height / 2,
  );
  final b = Offset(
    target.position.dx + target.size.width / 2,
    target.position.dy + target.size.height / 2,
  );
  return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

