// 连线几何单一真相源（CineFlow 式端口曲线）：
//   锚点随泳道方向：横向 = 源右边中点出 / 靶左边中点入；
//                竖向 = 源下边中点出 / 靶上边中点入；
//   路径 = 主轴控制柄三次贝塞尔（node-editor 经典 S 曲线）；
//   距离 = PathMetrics 均匀采样近似。
// EdgePainter（绘制）与 hitTestEdge（命中）共同消费，防几何漂移。
import 'dart:math' as math;
import 'dart:ui';

import '../models/canvas_node.dart';
import 'lane_geometry.dart';

/// 端口圆点半径（绘制用；命中阈值独立于此）。
const double kEdgePortRadius = 4.0;

/// 源节点出点：横向 = 右边中点；竖向 = 下边中点。
Offset edgeSourceAnchor(
  CanvasNode n, {
  LaneDirection direction = LaneDirection.horizontal,
}) =>
    direction == LaneDirection.horizontal
        ? Offset(
            n.position.dx + n.size.width,
            n.position.dy + n.size.height / 2,
          )
        : Offset(
            n.position.dx + n.size.width / 2,
            n.position.dy + n.size.height,
          );

/// 靶节点入点：横向 = 左边中点；竖向 = 上边中点。
Offset edgeTargetAnchor(
  CanvasNode n, {
  LaneDirection direction = LaneDirection.horizontal,
}) =>
    direction == LaneDirection.horizontal
        ? Offset(n.position.dx, n.position.dy + n.size.height / 2)
        : Offset(n.position.dx + n.size.width / 2, n.position.dy);

/// 主轴控制柄长度：随主轴距离增长，夹在 [40, 160] 保持弧度稳定。
double _handleLength(Offset a, Offset b, LaneDirection direction) {
  final d = direction == LaneDirection.horizontal
      ? (b.dx - a.dx).abs()
      : (b.dy - a.dy).abs();
  return (d / 2).clamp(40.0, 160.0);
}

/// 出/入沿主轴的三次贝塞尔路径。
Path edgePath(
  Offset a,
  Offset b, {
  LaneDirection direction = LaneDirection.horizontal,
}) {
  final h = _handleLength(a, b, direction);
  return direction == LaneDirection.horizontal
      ? (Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + h, a.dy, b.dx - h, b.dy, b.dx, b.dy))
      : (Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + h, b.dx, b.dy - h, b.dx, b.dy));
}

/// 曲线中点（弧长 t=0.5）——UI 放删除按钮等锚定用。
Offset edgePathMidpoint(
  Offset a,
  Offset b, {
  LaneDirection direction = LaneDirection.horizontal,
}) {
  final metrics =
      edgePath(a, b, direction: direction).computeMetrics().toList();
  if (metrics.isEmpty) return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final m = metrics.first;
  return m.getTangentForOffset(m.length / 2)?.position ??
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

/// O(1) 包围盒预筛：贝塞尔曲线含于控制点凸包，控制柄只在主轴方向外扩
/// （≤ 手柄上限）。点距外扩 [threshold] 后的包围盒之外 → 不可能命中，
/// 调用方可跳过昂贵的采样距离（大画布最坏路径守卫依赖此筛）。
bool edgeBoundsMayHit(
  Offset p,
  Offset a,
  Offset b,
  double threshold, {
  LaneDirection direction = LaneDirection.horizontal,
}) {
  final h = _handleLength(a, b, direction);
  final hx = direction == LaneDirection.horizontal ? h : 0.0;
  final hy = direction == LaneDirection.horizontal ? 0.0 : h;
  return p.dx >= math.min(a.dx, b.dx) - hx - threshold &&
      p.dx <= math.max(a.dx, b.dx) + hx + threshold &&
      p.dy >= math.min(a.dy, b.dy) - hy - threshold &&
      p.dy <= math.max(a.dy, b.dy) + hy + threshold;
}

/// 点 [p] 到连线路径的最短距离（弧长均匀采样近似）。
///
/// 采样段数随弧长自适应（步长 ≤8px，上限 512 段）：固定段数在长连线上会让
/// 采样间距超过命中阈值，点在线上也判不中。8px 步长下最近采样点距真实
/// 最近点 ≤4px（弧向），对 10px 命中阈值足够。
double distanceToEdgePath(
  Offset p,
  Offset a,
  Offset b, {
  LaneDirection direction = LaneDirection.horizontal,
}) {
  var best = (p - a).distance;
  for (final m in edgePath(a, b, direction: direction).computeMetrics()) {
    final samples = (m.length / 8).ceil().clamp(16, 512);
    for (var i = 0; i <= samples; i++) {
      final pos = m.getTangentForOffset(m.length * i / samples)?.position;
      if (pos == null) continue;
      final d = (p - pos).distance;
      if (d < best) best = d;
    }
  }
  return best;
}
