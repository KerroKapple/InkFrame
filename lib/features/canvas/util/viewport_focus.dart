// 把某个节点移到视口中心（左栏大纲 / 素材「定位」用）——纯函数，可脱离 widget 单测。
//
// InteractiveViewer 的矩阵把舞台坐标映射到视口坐标：screen = scale · stage + t。
// 保持缩放不变，只解平移：让节点渲染矩形的中心落在视口几何中心，
//   t = viewportCenter − scale · rectCenter。
//
// 「渲染矩形」要和卡片真正画出来的位置同源：世界坐标 + kStageOrigin + 分道位移
// （泳道里的卡片以本道起始边为锚缩放，见 lane_pin_geometry.dart），尺寸恒为 kNodeCardSize。
// 分道位移只随缩放变，而这里不改缩放——平移前后同一个位移，所以居中是精确的。
import 'package:flutter/widgets.dart';

import '../models/canvas_node.dart';
import 'canvas_zoom.dart';
import 'lane_geometry.dart';
import 'lane_pin_geometry.dart';

/// 节点卡在舞台坐标系里的渲染矩形（与 canvas_view 的 Positioned 同源）。
///
/// [lanes] 是**有效厚度**切片（折叠的道已按 kCollapsedLaneSize 折算，见 collapseLaneSlices），
/// [transform] 是当前相机——分道位移取决于它的缩放。
Rect nodeStageRect({
  required CanvasNode node,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
}) {
  final CanvasNode drawn = displacedNodes(
    nodes: <CanvasNode>[node],
    lanes: lanes,
    direction: direction,
    transform: transform,
  ).single;
  return drawn.position & kNodeCardSize;
}

/// 保持 [current] 的缩放，平移到让 [stageRect] 的中心落在视口中心。
///
/// 视口还没上报尺寸（[viewportSize] 为空：首帧前 / 约束坍缩帧）时不知道中心在哪，原样返回。
Matrix4 transformCenteringRect({
  required Matrix4 current,
  required Size viewportSize,
  required Rect stageRect,
}) {
  if (viewportSize.isEmpty) return current.clone();
  final double s = scaleOf(current);
  final Offset center = stageRect.center;
  final double tx = viewportSize.width / 2 - s * center.dx;
  final double ty = viewportSize.height / 2 - s * center.dy;
  return Matrix4.identity()
    ..translateByDouble(tx, ty, 0.0, 1.0)
    ..scaleByDouble(s, s, 1.0, 1.0);
}
