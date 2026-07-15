// 泳道钉死模型（NLE 轨道式）的坐标数学——纯函数。
//
// 泳道带钉在视口层（屏幕坐标、不随缩放平移）；泳道内的内容以**自己泳道的
// 起始边**为锚点缩放，保证缩放/平移时不穿出泳道：
//   有道（laneStart != null）：screen = laneStart + scale * (world - laneStart)
//   无道：                     screen = scale * world + translation（全局变换）
//
// 渲染侧不逐点换算，而是给每条泳道一个世界坐标系的整体位移 d（分道位移组），
// 让全局变换作用后恰好等于锚定公式：
//   scale * (world + d) + translation ≡ laneStart + scale * (world - laneStart)
//   ⇒ d = (laneStart * (1 - scale) - translation) / scale
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

import '../models/canvas_node.dart';
import 'canvas_extent.dart';
import 'canvas_zoom.dart';
import 'lane_geometry.dart';

/// 世界横截轴平移分量：变换矩阵映射的是舞台坐标（screen = s·stage + t），
/// 世界与舞台差一个 kStageHalf（居中定舞台），故 worldT = t + s·kStageHalf。
/// 泳道锚定/落道换算全部以世界坐标表述，统一经此取平移。
double worldCrossTranslation(Matrix4 m, LaneDirection direction) {
  final t = direction == LaneDirection.horizontal
      ? m.storage[13]
      : m.storage[12];
  return t + scaleOf(m) * kStageHalf;
}

/// 泳道起始边（屏幕坐标 = 各道 size 顺序累计）；laneId 不存在返回 null。
double? laneStartOf(
  String? laneId,
  List<({String id, double size})> lanes,
) {
  if (laneId == null) return null;
  var offset = 0.0;
  for (final lane in lanes) {
    if (lane.id == laneId) return offset;
    offset += lane.size;
  }
  return null;
}

/// 分道位移：加在世界坐标上、经全局变换后实现"以泳道起始边为锚缩放"。
double lanePinDisplacement({
  required double laneStart,
  required double scale,
  required double crossTranslation,
}) =>
    (laneStart * (1 - scale) - crossTranslation) / scale;

/// 世界横截坐标 → 屏幕横截坐标（有道按泳道锚定，无道走全局变换）。
double crossToScreen({
  required double? laneStart,
  required double world,
  required double scale,
  required double crossTranslation,
}) =>
    laneStart == null
        ? scale * world + crossTranslation
        : laneStart + scale * (world - laneStart);

/// 屏幕横截坐标 → 世界横截坐标（crossToScreen 的逆）。
double crossToWorld({
  required double? laneStart,
  required double screen,
  required double scale,
  required double crossTranslation,
}) =>
    laneStart == null
        ? (screen - crossTranslation) / scale
        : laneStart + (screen - laneStart) / scale;

/// 节点的分道位移向量（**世界坐标系**的补偿量）：横截轴上按所属泳道补偿，
/// 主轴恒 0；无道 / 道不存在 → Offset.zero（全局变换）。
Offset nodeLaneDisplacement({
  required CanvasNode node,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
}) {
  final laneStart = laneStartOf(node.laneId, lanes);
  if (laneStart == null) return Offset.zero;
  final horizontal = direction == LaneDirection.horizontal;
  final d = lanePinDisplacement(
    laneStart: laneStart,
    scale: scaleOf(transform),
    crossTranslation: worldCrossTranslation(transform, direction),
  );
  return horizontal ? Offset(0, d) : Offset(d, 0);
}

/// 连线/命中用：把节点列表映射为"渲染位置"（**舞台坐标** + 分道位移）副本，
/// 与卡片 Positioned 的坐标系一致（世界 + kStageOrigin + 分道位移）。
List<CanvasNode> displacedNodes({
  required List<CanvasNode> nodes,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required Matrix4 transform,
}) =>
    [
      for (final n in nodes)
        n.copyWith(
          position: worldToStage(n.position) +
              nodeLaneDisplacement(
                node: n,
                lanes: lanes,
                direction: direction,
                transform: transform,
              ),
        ),
    ];
