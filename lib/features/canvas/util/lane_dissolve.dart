// 泳道解散 / 连内容一起删的纯函数与撤销令牌——不碰 widget / provider。
//
// 两件事分开（ContextMenus 稿 › 泳道 · 标题栏右键）：
//   - 解散（节点留下）：道没了，道里的卡片**屏幕上原地不动**，变成道外节点（lane_id = null）。
//     道内的卡按本道起始边锚定缩放、道外的卡走全局变换，同一张卡换了归属、世界坐标就得跟着换算——
//     换算走 node_menu_model.laneMoveDelta(toLaneId: null)，与「移出泳道」同一条公式。
//   - 删除泳道和内容：道 + 道内节点 + 这些节点的入 / 出边一个事务软删；道内有生成中的任务先确认。
// 写库在 providers/canvas_lanes_controller.dart，带 BuildContext 的动作在 util/canvas_lane_actions.dart。
import 'dart:ui';

import '../../generation/models/job_state.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import 'lane_geometry.dart';
import 'node_menu_model.dart';

/// 解散前一张卡的世界坐标（撤销时写回去，lane_id 写回令牌里那条道）。
typedef LaneNodeSnapshot = ({String nodeId, Offset position});

/// 解散泳道的撤销令牌：被解散的道 + 解散前道内每张卡的世界坐标（按库里读到的行）。
class LaneDissolution {
  const LaneDissolution({required this.lane, required this.nodes});

  final StyleLane lane;

  /// 解散前的世界坐标；这些节点解散前的 lane_id 都是 [lane] 的 id。
  final List<LaneNodeSnapshot> nodes;
}

/// 删除泳道和内容的撤销令牌：道 + 一并软删的节点 id + 一并软删的边 id（已去重）。
class LaneContentsDeletion {
  const LaneContentsDeletion({
    required this.lane,
    required this.nodeIds,
    required this.edgeIds,
  });

  final StyleLane lane;
  final List<String> nodeIds;
  final List<String> edgeIds;
}

/// 解散 [laneId] 后道内每张卡的新世界坐标：屏幕上不动。
///
/// [laneNodes] 里只有 lane_id == [laneId] 的卡参与（别的道 / 道外的卡不在结果里）。
/// [lanes] 按 sort_order 排好；[collapsed] 是此刻折叠着的道。
/// 被解散的道按**展开厚度**算（它折叠时卡片不画，「屏幕位置」以展开时为准——等于先展开再解散），
/// 其余道按 collapseLaneSlices 的有效厚度。缩放 [scale] 是此刻的相机缩放。
Map<String, Offset> dissolvedPositions({
  required List<CanvasNode> laneNodes,
  required String laneId,
  required List<StyleLane> lanes,
  required Set<String> collapsed,
  required LaneDirection direction,
  required double scale,
}) {
  final List<({String id, double size})> slices = collapseLaneSlices(
    <({String id, double size})>[
      for (final StyleLane l in lanes) (id: l.id, size: l.size),
    ],
    <String>{
      for (final String id in collapsed)
        if (id != laneId) id,
    },
  );
  return <String, Offset>{
    for (final CanvasNode n in laneNodes)
      if (n.laneId == laneId)
        n.id: n.position +
            laneMoveDelta(
              node: n,
              toLaneId: null,
              laneSlices: slices,
              direction: direction,
              scale: scale,
            ),
  };
}

/// 道内还没到终态的任务：同一画布（[canvasId]），且 sourceNodeId 或 resultNodeId 落在 [laneNodeIds] 里。
///
/// 删除泳道和内容前据此决定要不要先确认（取消任务撤不回来）。终态任务、别的画布的任务不算。
List<JobState> activeJobsInLane({
  required String canvasId,
  required Set<String> laneNodeIds,
  required List<JobState> jobs,
}) =>
    <JobState>[
      for (final JobState j in jobs)
        if (!j.isTerminal &&
            j.canvasId == canvasId &&
            (laneNodeIds.contains(j.sourceNodeId) ||
                laneNodeIds.contains(j.resultNodeId)))
          j,
    ];
