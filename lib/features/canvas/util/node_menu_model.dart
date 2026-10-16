// 节点右键菜单（画布重设计稿 › 画布交互「右键菜单 · 节点」）的判据——纯函数，不碰 widget / provider。
//
// 菜单作用在谁身上（[nodeMenuTargets]）：右键的那张卡在选中集里 ⇒ 整个选中集；不在 ⇒ 只有它。画布在开菜单
// 之前已经把选中换成了右键的那张（右键一张没被选中的卡），所以菜单开着时「目标」就是选中集。
// 各项的作用范围：
//   - 生成 / 存为角色：单张动作——目标恰好一张才可点（与画布 Ctrl+↵「恰好选中一张」同一个口径）；
//   - 复制一份 / 加入泳道 / 删除：整批——多选时对目标里的每一张；
//   - 在序列中定位：目标里链序最靠前的那一镜（判据在 sequence/util/shot_index.dart，与标签栏共用）。
// 不可用的项置灰、不隐藏（菜单行的 enabled），判据全在这里。
//
// 【加入泳道要挪位置】见 [laneMoveDelta]：位置决定泳道归属是整个画布的规则，只改 lane_id 卡片会画在带外。
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import 'lane_geometry.dart';
import 'lane_pin_geometry.dart';

/// 节点菜单里的一项。
enum NodeMenuAction {
  /// 生成（Ctrl+↵ / ⌘↵）：与提示词条「生成」同一条 submit。
  generate,

  /// 复制一份（Ctrl+D / ⌘D）。
  duplicate,

  /// 存为角色（带图的产物节点）。
  saveAsCharacter,

  /// 「加入泳道 ›」那一行本身：只开子菜单，不执行。
  laneSubmenu,

  /// 子菜单里的一条泳道：整批移进去。
  moveToLane,

  /// 子菜单最后一项：移出泳道。
  removeFromLane,

  /// 在序列中定位。
  locateInSequence,

  /// 删除（Del）：走带撤销卡的删除。
  delete,
}

/// 菜单交回来的一次选择：动作 + （加入泳道时）目标泳道。值相等即同一项——菜单行的 ValueKey 靠它。
@immutable
class NodeMenuPick {
  const NodeMenuPick(this.action) : laneId = null;

  /// 子菜单里的一条泳道。
  const NodeMenuPick.moveToLane(String this.laneId)
      : action = NodeMenuAction.moveToLane;

  final NodeMenuAction action;

  /// [NodeMenuAction.moveToLane] 的目标泳道；其余为 null。
  final String? laneId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeMenuPick && other.action == action && other.laneId == laneId;

  @override
  int get hashCode => Object.hash(action, laneId);

  @override
  String toString() => 'NodeMenuPick($action, laneId: $laneId)';
}

/// 菜单作用在哪些节点上：[nodeId]（右键的那张）在选中集里 ⇒ 整个选中集；不在 ⇒ 只有它。
Set<String> nodeMenuTargets(Set<String> selection, String nodeId) =>
    selection.contains(nodeId) ? selection : <String>{nodeId};

/// 能生成的节点：image / video 的配置节点，且提示词去首尾空白后不空——提示词条「生成」可点的同一个判据。
bool isGenerableNode(CanvasNode node) =>
    node.role == NodeRole.config &&
    (node.type == CanvasNodeType.image || node.type == CanvasNodeType.video) &&
    (node.promptText?.trim().isNotEmpty ?? false);

/// 「生成」作用在谁身上：[targets] 恰好一张且能生成 ⇒ 那一张；否则 null。
/// 画布的 Ctrl+↵ / ⌘↵（目标 = 选中集）与节点菜单的「生成」共用；在不在忙另看提交状态。
CanvasNode? generationTarget(List<CanvasNode> targets) =>
    targets.length == 1 && isGenerableNode(targets.single) ? targets.single : null;

/// 「复制一份」要复制的节点：[targets] 里的配置节点（产物不复制），顺序照旧。空 ⇒ 这一项置灰。
List<CanvasNode> duplicateSources(List<CanvasNode> targets) => <CanvasNode>[
      for (final CanvasNode n in targets)
        if (n.role == NodeRole.config) n,
    ];

/// 「存为角色」的源：[targets] 恰好一张、是带图的产物节点 ⇒ 那一张；否则 null（视频产物没有 image_url）。
CanvasNode? characterSource(List<CanvasNode> targets) {
  if (targets.length != 1) return null;
  final CanvasNode node = targets.single;
  return node.role == NodeRole.result && node.imageUrl != null ? node : null;
}

/// 「加入泳道 ›」子菜单里的一条泳道。
@immutable
class LaneMenuOption {
  const LaneMenuOption({required this.lane, required this.current});

  final StyleLane lane;

  /// 目标全在这条道里：打勾、不可点。
  final bool current;
}

/// 子菜单的泳道行，按画布上的泳道顺序。[targets] 全在某条道里 ⇒ 那一条是「当前」。
List<LaneMenuOption> laneMenuOptions({
  required List<StyleLane> lanes,
  required List<CanvasNode> targets,
}) =>
    <LaneMenuOption>[
      for (final StyleLane lane in lanes)
        LaneMenuOption(
          lane: lane,
          current: targets.isNotEmpty &&
              targets.every((CanvasNode n) => n.laneId == lane.id),
        ),
    ];

/// 「移出泳道」可点：目标里至少一张在（还存在的）泳道里。
bool canRemoveFromLane({
  required List<StyleLane> lanes,
  required List<CanvasNode> targets,
}) {
  final Set<String> ids = <String>{for (final StyleLane l in lanes) l.id};
  return targets.any((CanvasNode n) => n.laneId != null && ids.contains(n.laneId));
}

/// 加入 / 移出泳道真要挪的节点：已经在目标道里的不动（移出 = 目标 null，本来就不在道里的不动）。
List<CanvasNode> laneMoveCandidates(List<CanvasNode> targets, String? toLaneId) =>
    <CanvasNode>[
      for (final CanvasNode n in targets)
        if (n.laneId != toLaneId) n,
    ];

/// 加入 / 移出泳道时节点在世界坐标里要挪的量（只动横截轴，主轴不动）。
///
/// 【为什么不是 Offset.zero】位置决定泳道归属是整个画布的规则：拖卡片落点、新建菜单落点都按「卡片中心落在
/// 哪条道的带里」判道（drop_placement.dart）。只改 lane_id、不动位置，卡片按新道的锚定画出来常常在带外——
/// 看着没进道，下次一拖又按位置被判回去。所以：
///   - 加入泳道：先算卡片中心此刻画在哪（按原道的锚定）。已经在目标道的带里 ⇒ 屏幕上不动，只按新道的锚定
///     换算世界坐标；不在 ⇒ 收进带里（收到离得近的那条边内侧，整张卡留在带内；带比卡片还窄时取带的中线）。
///   - 移出泳道（[toLaneId] 为 null）：屏幕上不动，按不在道里的卡换算世界坐标。
/// 坐标在「泳道栈坐标」（屏幕坐标 − 泳道栈偏移）里换算，与 resolveLaneDrop 同一套锚定公式；[laneSlices] 是
/// **有效厚度**切片（折叠的道按 kCollapsedLaneSize），[scale] 是此刻的相机缩放。
Offset laneMoveDelta({
  required CanvasNode node,
  required String? toLaneId,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
  required double scale,
}) {
  final bool horizontal = direction == LaneDirection.horizontal;
  final double half =
      horizontal ? kNodeCardSize.height / 2 : kNodeCardSize.width / 2;
  final double centerWorld =
      (horizontal ? node.position.dy : node.position.dx) + half;
  final double screen = crossToScreen(
    laneStart: laneStartOf(node.laneId, laneSlices),
    world: centerWorld,
    scale: scale,
    crossTranslation: 0,
  );
  final double? start = laneStartOf(toLaneId, laneSlices);
  double target = screen;
  if (start != null) {
    double size = 0;
    for (final ({String id, double size}) slice in laneSlices) {
      if (slice.id == toLaneId) size = slice.size;
    }
    final double inset = half * scale;
    final double lo = start + inset;
    final double hi = start + size - inset;
    target = lo <= hi ? screen.clamp(lo, hi).toDouble() : start + size / 2;
  }
  final double movedWorld = crossToWorld(
    laneStart: start,
    screen: target,
    scale: scale,
    crossTranslation: 0,
  );
  final double d = movedWorld - centerWorld;
  return horizontal ? Offset(0, d) : Offset(d, 0);
}
