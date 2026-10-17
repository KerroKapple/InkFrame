// 选区几何（框选命中 / 选区包围盒）——纯函数，可脱离 widget 单测。
//
// 框选、浮动工具条、对齐分布、粘贴落点、Ctrl G 包成泳道共用这一套判据，不各写一份几何。
//
// 卡片矩形一律走 nodeStageRect（世界 + kStageOrigin + 分道位移，与卡片 Positioned 同源）：泳道里的卡
// 在缩放 ≠ 1 时画在分道位移之后的位置，框按屏幕上看得见的卡判，不按世界坐标判。
// 折叠道里的卡看不见，不参与命中，也不计入包围盒（Selection 稿没写包围盒的口径，按「看不见的卡不参与几何」定）。
//
// 与 viewport_fit.dart 的 nodesStageBounds 口径不同：那边按「纯缩放矩阵」问、不跳过折叠道，给适应视口用；
// 这里按当前相机问、跳过折叠道，给浮动条 / 对齐用。
import 'package:flutter/widgets.dart';

import '../models/canvas_node.dart';
import 'lane_geometry.dart';
import 'viewport_focus.dart';

/// 拖框时的选择方式：不按键替换；Shift 加选；Ctrl（mac 用 ⌘）反选。修饰键 → 模式的映射归舞台侧。
enum MarqueeMode { replace, add, invert }

/// 「框碰到卡」的唯一判据（Selection Q1 → A：碰到就算，与 tldraw / Figma 一致）。
///
/// 闭区间相交：只碰到一角、只贴着一条边（交集面积为 0）都算；宽或高为 0 的框照样按闭区间判。
/// 日后改成「整张框住才算」或「过中心才算」只换这一处。
bool _touches(Rect a, Rect b) =>
    a.left <= b.right &&
    b.left <= a.right &&
    a.top <= b.bottom &&
    b.top <= a.bottom;

/// 舞台坐标的框 [stageRect] 碰到哪些卡（按 [nodes] 的 id）。
///
/// [lanes] 是**有效厚度**切片（折叠的道已按 kCollapsedLaneSize 折算，见 collapseLaneSlices），
/// [transform] 是当前相机——分道位移取决于它的缩放。laneId 在 [collapsedLaneIds] 里的卡跳过；
/// laneId 指向已不存在的道的卡按无道卡算（nodeStageRect 的现成行为）。节点类型不参与判断。
Set<String> marqueeHits({
  required Rect stageRect,
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
  Set<String> collapsedLaneIds = const <String>{},
}) {
  final Set<String> hits = <String>{};
  for (final CanvasNode node in nodes) {
    if (_inCollapsedLane(node, collapsedLaneIds)) continue;
    final Rect r = nodeStageRect(
      node: node,
      lanes: lanes,
      direction: direction,
      transform: transform,
    );
    if (_touches(stageRect, r)) hits.add(node.id);
  }
  return hits;
}

/// 框选结果：replace = hits；add = before ∪ hits；invert = before △ hits（对称差）。
///
/// 不改入参集合，总是返回新集合。
Set<String> applyMarquee(
  Set<String> before,
  Set<String> hits,
  MarqueeMode mode,
) {
  switch (mode) {
    case MarqueeMode.replace:
      return Set<String>.of(hits);
    case MarqueeMode.add:
      return before.union(hits);
    case MarqueeMode.invert:
      return before.difference(hits)..addAll(hits.difference(before));
  }
}

/// [ids] 里的卡在舞台坐标下的包围盒（按当前相机 [transform]，含分道位移）。
///
/// 不在 [nodes] 里的 id 与折叠道里的卡跳过；一张都没有 ⇒ null。
Rect? selectionBounds({
  required Set<String> ids,
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
  Set<String> collapsedLaneIds = const <String>{},
}) {
  Rect? bounds;
  for (final CanvasNode node in nodes) {
    if (!ids.contains(node.id)) continue;
    if (_inCollapsedLane(node, collapsedLaneIds)) continue;
    final Rect r = nodeStageRect(
      node: node,
      lanes: lanes,
      direction: direction,
      transform: transform,
    );
    final Rect? b = bounds;
    bounds = b == null ? r : b.expandToInclude(r);
  }
  return bounds;
}

bool _inCollapsedLane(CanvasNode node, Set<String> collapsedLaneIds) {
  final String? laneId = node.laneId;
  return laneId != null && collapsedLaneIds.contains(laneId);
}
