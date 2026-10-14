// 左栏的「定位」动作：在画布上单选一个节点，并把它移到视口中心（保持缩放）。
// 大纲的镜头行 / 产物子行、素材格（产物就在当前画布时）共用这一条路径。
//
// 坐标数学全在 util/viewport_focus.dart（纯函数，有单测）；这里只负责从 provider 取现值：
// 相机、视口尺寸、泳道切片（有效厚度）与方向——泳道里的卡片画在「世界 + 分道位移」处，
// 居中要对准卡片真正画出来的位置。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/canvas_node.dart';
import '../../models/style_lane.dart';
import '../../providers/canvas_lanes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/canvas_transform_controller.dart';
import '../../providers/lane_collapse_controller.dart';
import '../../util/lane_geometry.dart';
import '../../util/viewport_focus.dart';

/// 单选 [node]，并把它的卡片移到 [canvasId] 视口的正中（缩放不变）。
void focusNodeOnCanvas(
  WidgetRef ref, {
  required String canvasId,
  required CanvasNode node,
}) {
  ref.read(canvasSelectionControllerProvider(canvasId).notifier).select(node.id);

  final TransformationController transform =
      ref.read(canvasTransformControllerProvider(canvasId));
  final List<StyleLane> lanes =
      ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
          const <StyleLane>[];
  // 不在（现存）泳道里的节点没有分道位移，也就不必去读泳道方向。
  final bool laned =
      node.laneId != null && lanes.any((StyleLane l) => l.id == node.laneId);
  final LaneDirection direction = laned
      ? (ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
          LaneDirection.horizontal)
      : LaneDirection.horizontal;
  final List<({String id, double size})> slices = laned
      ? collapseLaneSlices(
          <({String id, double size})>[
            for (final StyleLane l in lanes) (id: l.id, size: l.size),
          ],
          ref.read(laneCollapseProvider(canvasId)),
        )
      : const <({String id, double size})>[];

  transform.value = transformCenteringRect(
    current: transform.value,
    viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
    stageRect: nodeStageRect(
      node: node,
      lanes: slices,
      direction: direction,
      transform: transform.value,
    ),
  );
}
