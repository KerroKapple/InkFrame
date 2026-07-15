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

/// 泳道栈在屏幕上的横截偏移 = 世界横截原点的屏幕位置（t + s·kStageHalf）。
///
/// 泳道模型（终版语义）：泳道栈锚在世界原点、随画布**平移**一起动，
/// 但**缩放**不改变道厚——道内内容以本道起始边为锚缩放。
/// 泳道皮（底色带/标题栏/拖拽条）在视口层整体按此偏移平移；
/// "泳道栈坐标系"（下称 lane-stack 空间）= 屏幕坐标 − 此偏移，
/// 道 i 起始边在 lane-stack 空间恒为 laneStart_i，与缩放/平移无关。
double laneStackOffset(Matrix4 m, LaneDirection direction) {
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
  // lane-stack 空间的锚定无平移项（crossTranslation=0）：泳道栈随平移
  // 整体走，道内内容只需相对本道起始边锚定缩放。
  final d = lanePinDisplacement(
    laneStart: laneStart,
    scale: scaleOf(transform),
    crossTranslation: 0,
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
