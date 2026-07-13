// 画布舞台尺寸：内容驱动动态生长（"无限画布"语义）。
//
// 舞台不是固定 4000×4000——尺寸 = 内容右/下边界 + 生长余量（下限 kCanvasMinExtent）。
// 节点被拖近边缘时下一帧舞台自动变大，向右/向下无上限；
// 左/上边界固定为原点（moveNode 落点 clamp ≥0——Stack 负坐标区不参与命中，
// 是点击死区；全向无限需重写视口坐标系，见 BOARD 备注）。
import 'dart:math' as math;
import 'dart:ui';

import '../models/canvas_node.dart';

/// 舞台最小边长（空画布 / 内容很少时的默认漫游空间）。
const double kCanvasMinExtent = 4000;

/// 内容到舞台边缘的生长余量——保证边缘节点旁始终有可拖拽的空白。
const double kCanvasGrowMargin = 2000;

/// 由节点内容计算舞台尺寸。
Size canvasStageSize(List<CanvasNode> nodes) {
  var w = kCanvasMinExtent;
  var h = kCanvasMinExtent;
  for (final n in nodes) {
    w = math.max(w, n.position.dx + n.size.width + kCanvasGrowMargin);
    h = math.max(h, n.position.dy + n.size.height + kCanvasGrowMargin);
  }
  return Size(w, h);
}
