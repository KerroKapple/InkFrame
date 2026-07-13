// 连线几何单一真相源（CineFlow 式端口曲线）：
//   锚点 = 源节点右边中点（出） / 靶节点左边中点（入）；
//   路径 = 水平控制柄三次贝塞尔（node-editor 经典 S 曲线）；
//   距离 = PathMetrics 均匀采样近似。
// EdgePainter（绘制）与 hitTestEdge（命中）共同消费，防几何漂移。
import 'dart:ui';

import '../models/canvas_node.dart';

/// 端口圆点半径（绘制用；命中阈值独立于此）。
const double kEdgePortRadius = 4.0;

/// 源节点出点：右边中点。
Offset edgeSourceAnchor(CanvasNode n) => Offset(
      n.position.dx + n.size.width,
      n.position.dy + n.size.height / 2,
    );

/// 靶节点入点：左边中点。
Offset edgeTargetAnchor(CanvasNode n) => Offset(
      n.position.dx,
      n.position.dy + n.size.height / 2,
    );

/// 水平控制柄长度：随水平距离增长，夹在 [40, 160] 保持弧度稳定。
double _handleLength(Offset a, Offset b) {
  final dx = (b.dx - a.dx).abs();
  return (dx / 2).clamp(40.0, 160.0);
}

/// 出右入左的三次贝塞尔路径。
Path edgePath(Offset a, Offset b) {
  final h = _handleLength(a, b);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(a.dx + h, a.dy, b.dx - h, b.dy, b.dx, b.dy);
}

/// 曲线中点（弧长 t=0.5）——UI 放删除按钮等锚定用。
Offset edgePathMidpoint(Offset a, Offset b) {
  final metrics = edgePath(a, b).computeMetrics().toList();
  if (metrics.isEmpty) return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final m = metrics.first;
  return m.getTangentForOffset(m.length / 2)?.position ??
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

/// 点 [p] 到连线路径的最短距离（均匀采样近似；[samples] 段足够命中判定精度）。
double distanceToEdgePath(Offset p, Offset a, Offset b, {int samples = 32}) {
  var best = (p - a).distance;
  for (final m in edgePath(a, b).computeMetrics()) {
    for (var i = 0; i <= samples; i++) {
      final pos = m.getTangentForOffset(m.length * i / samples)?.position;
      if (pos == null) continue;
      final d = (p - pos).distance;
      if (d < best) best = d;
    }
  }
  return best;
}
