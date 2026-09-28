// 泳道几何：纯函数。canvasExtent = 视口沿泳道轴的边长（定舞台后泳道皮只需
// 铺满视口，见 canvas_extent.dart），泳道按传入顺序（调用方已按 sort_order 排）累计偏移。
import 'dart:ui';

enum LaneDirection { horizontal, vertical }

LaneDirection laneDirectionFromString(String s) =>
    s == 'vertical' ? LaneDirection.vertical : LaneDirection.horizontal;

String laneDirectionToString(LaneDirection d) =>
    d == LaneDirection.vertical ? 'vertical' : 'horizontal';

/// 横向：带沿 Y 堆叠、跨满宽；竖向：带沿 X 堆叠、跨满高。
List<Rect> laneRects({
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required double canvasExtent,
}) {
  final rects = <Rect>[];
  var offset = 0.0;
  for (final lane in lanes) {
    rects.add(direction == LaneDirection.horizontal
        ? Rect.fromLTWH(0, offset, canvasExtent, lane.size)
        : Rect.fromLTWH(offset, 0, lane.size, canvasExtent));
    offset += lane.size;
  }
  return rects;
}

/// 泳道尺寸下限（px）。
const double kMinLaneSize = 80;

/// 拖拽分界线后的新尺寸：当前 + delta，下限 [kMinLaneSize]。
double clampLaneSize(double current, double delta) =>
    (current + delta).clamp(kMinLaneSize, double.infinity);

/// 把 [movedId] 移动到 [targetId] 所在位置后的 id 顺序；
/// targetId 为 null / 等于 movedId / 任一不存在时返回原序（不变）。
List<String> reorderedLaneIds(
  List<String> ids,
  String movedId,
  String? targetId,
) {
  if (targetId == null || targetId == movedId) return ids;
  final from = ids.indexOf(movedId);
  final to = ids.indexOf(targetId);
  if (from < 0 || to < 0) return ids;
  final next = [...ids]..removeAt(from);
  next.insert(to, movedId);
  return next;
}

/// 点落在哪条泳道；越界 / 空返回 null。
String? laneIdAtPoint({
  required Offset point,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
}) {
  var offset = 0.0;
  final coord = direction == LaneDirection.horizontal ? point.dy : point.dx;
  for (final lane in lanes) {
    if (coord >= offset && coord < offset + lane.size) return lane.id;
    offset += lane.size;
  }
  return null;
}

/// 折叠态泳道的厚度（Lanes 稿改动 4）：整条道收成 36px 的轨，只留标题栏。
const double kCollapsedLaneSize = 36;

/// 把泳道切片换成【有效厚度】：折叠的道按 [kCollapsedLaneSize]，其余照原 size。
/// 几何全家（laneRects / laneStartOf / laneIdAtPoint / 分道位移）都要吃这份切片，
/// 折叠才是真的省空间——后面的道整体上移，而不是只把底色关掉。
List<({String id, double size})> collapseLaneSlices(
  List<({String id, double size})> lanes,
  Set<String> collapsedIds,
) =>
    [
      for (final l in lanes)
        (id: l.id, size: collapsedIds.contains(l.id) ? kCollapsedLaneSize : l.size),
    ];
