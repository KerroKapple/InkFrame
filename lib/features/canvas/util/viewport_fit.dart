// 适应视口（适应全部 Shift+1 / 适应选中 Shift+2）——纯函数，可脱离 widget 单测。
//
// InteractiveViewer 的矩阵把舞台坐标映射到视口坐标：screen = scale · stage + t。适应 = 求一组 (scale, t)，
// 让一块舞台矩形完整落进「视口扣掉留白」的那一块里并居中：
//   - 缩放 = 刚好放得下的那一档，夹在 [kCanvasMinScale, min(1, kCanvasMaxScale)]——**只缩小、不放大**：
//     卡片在 100% 下本来就看得清，把两张卡放大到占满屏只会让人找不着北；
//   - 平移 = 矩形中心对准可用区域中心。
// 留白由调用方给：顶部让出浮动工具条那一条（InkToolbarSize.stageTopInset），底部让出缩放条那一截。
//
// 【泳道里的卡片】分道位移随缩放变（lane_pin_geometry.dart：泳道里的内容以本道起始边为锚缩放），
// 所以一组卡片的包围盒是缩放的函数——拿 100% 时的包围盒去算缩放，缩完泳道里的卡会挪出视口。
// [transformFittingScaledRect] 收的是「某个缩放下的包围盒」，在缩放上二分找放得下的最大一档；
// 卡片矩形一律走 nodeStageRect（与卡片 Positioned 同源），不在这里另推一遍分道位移。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/canvas_node.dart';
import 'canvas_zoom.dart';
import 'lane_geometry.dart';
import 'viewport_focus.dart';

/// 适应视口时的缩放上限：只缩小、不放大（见头注）。
const double kCanvasFitMaxScale = 1.0;

/// 二分缩放的轮数：缩放区间最宽 0.9，30 轮后误差 < 1e-9，远小于一个像素。
const int _kFitIterations = 30;

/// 「放得下」的浮点容差（视口像素）：刚好贴边的那一档不能因为舍入误差被判成放不下。
const double _kFitTolerance = 1e-6;

/// 视口扣掉 [insets] 之后放内容的那一块（视口坐标）。视口还没量出来、或扣完没有面积 ⇒ null。
Rect? fitArea(Size viewportSize, EdgeInsets insets) {
  if (viewportSize.isEmpty) return null;
  final Rect area = insets.deflateRect(Offset.zero & viewportSize);
  return area.width > 0 && area.height > 0 ? area : null;
}

/// 刚好把 [rect]（舞台坐标）放进 [area] 的缩放，夹在 [kCanvasMinScale, min(1, kCanvasMaxScale)]。
double fitScaleFor(Rect rect, Rect area) {
  final double cap = math.min(kCanvasFitMaxScale, kCanvasMaxScale);
  if (rect.width <= 0 || rect.height <= 0) return cap;
  final double s = math.min(area.width / rect.width, area.height / rect.height);
  return s.clamp(kCanvasMinScale, cap).toDouble();
}

/// 缩放 [scale] 下让 [rect]（舞台坐标）的中心对准 [area]（视口坐标）的中心。
Matrix4 transformCenteringRectIn({
  required Rect rect,
  required double scale,
  required Rect area,
}) {
  final double tx = area.center.dx - scale * rect.center.dx;
  final double ty = area.center.dy - scale * rect.center.dy;
  return Matrix4.identity()
    ..translateByDouble(tx, ty, 0.0, 1.0)
    ..scaleByDouble(scale, scale, 1.0, 1.0);
}

/// 把 [stageRect] 完整框进视口（扣掉 [insets]）并居中的相机。视口还没量出来 / 扣完没地方了 ⇒ null
/// （调用方不动相机）。矩形比最小缩放下的可用区域还大时用最小缩放，居中、两边各超出一截。
Matrix4? transformFittingRect({
  required Rect stageRect,
  required Size viewportSize,
  required EdgeInsets insets,
}) {
  final Rect? area = fitArea(viewportSize, insets);
  if (area == null) return null;
  return transformCenteringRectIn(
    rect: stageRect,
    scale: fitScaleFor(stageRect, area),
    area: area,
  );
}

/// 包围盒随缩放变时的版本：[rectAt] 给出缩放 s 下的舞台包围盒（泳道里的卡片有分道位移）。
///
/// 先看上限那一档放不放得下（放得下就不缩）；放不下就拿上限那一档的包围盒估一个缩放（包围盒不随缩放变时
/// 这就是精确解），再在缩放上二分出放得下的最大一档。最小缩放也放不下 ⇒ 用最小缩放，居中。
Matrix4? transformFittingScaledRect({
  required Rect Function(double scale) rectAt,
  required Size viewportSize,
  required EdgeInsets insets,
}) {
  final Rect? area = fitArea(viewportSize, insets);
  if (area == null) return null;
  final double cap = math.min(kCanvasFitMaxScale, kCanvasMaxScale);
  bool fits(double s) {
    final Rect r = rectAt(s);
    return r.width * s <= area.width + _kFitTolerance &&
        r.height * s <= area.height + _kFitTolerance;
  }

  double scale = cap;
  if (!fits(cap)) {
    final double guess = fitScaleFor(rectAt(cap), area);
    double lo;
    double hi;
    if (fits(guess)) {
      lo = guess;
      hi = cap;
    } else {
      lo = kCanvasMinScale;
      hi = guess;
    }
    if (!fits(lo)) {
      scale = kCanvasMinScale;
    } else {
      for (int i = 0; i < _kFitIterations; i++) {
        final double mid = (lo + hi) / 2;
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      scale = lo;
    }
  }
  return transformCenteringRectIn(rect: rectAt(scale), scale: scale, area: area);
}

/// 一组节点卡片在缩放 [scale] 下的舞台包围盒；没有节点 ⇒ null。
///
/// 每张卡的矩形走 nodeStageRect（世界 + kStageOrigin + 分道位移，与卡片 Positioned 同源）。[lanes] 是
/// **有效厚度**切片（折叠的道已按 kCollapsedLaneSize 折算，见 collapseLaneSlices）。分道位移只看缩放，
/// 所以这里拿一个纯缩放矩阵去问。
Rect? nodesStageBounds({
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required double scale,
}) {
  final Matrix4 camera = Matrix4.diagonal3Values(scale, scale, 1.0);
  Rect? bounds;
  for (final CanvasNode node in nodes) {
    final Rect r = nodeStageRect(
      node: node,
      lanes: lanes,
      direction: direction,
      transform: camera,
    );
    final Rect? b = bounds;
    bounds = b == null ? r : b.expandToInclude(r);
  }
  return bounds;
}

/// 把 [nodes] 全部框进视口（扣掉 [insets]）的相机。没有节点 / 视口还没量出来 ⇒ null。
Matrix4? transformFittingNodes({
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Size viewportSize,
  required EdgeInsets insets,
}) {
  if (nodes.isEmpty) return null;
  return transformFittingScaledRect(
    rectAt: (double scale) => nodesStageBounds(
      nodes: nodes,
      lanes: lanes,
      direction: direction,
      scale: scale,
    )!,
    viewportSize: viewportSize,
    insets: insets,
  );
}
