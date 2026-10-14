// 落点换算（纯函数）：拖卡片落点与新建菜单落点共用的泳道归属判定，外加「舞台上这一点落在哪张卡上」。
//
// 泳道钉死模型（lane_pin_geometry.dart）：泳道里的卡片以本道起始边为锚缩放，同一个世界坐标在不同的道里
// 画在不同的屏幕位置。所以「落在哪条道」要先把卡片中心换到泳道栈坐标（屏幕坐标 − 泳道栈偏移）里判，
// 再按新道的锚定逆映射回世界坐标——换道前后卡片在屏幕上不动。这一段原来写在 canvas_view 的拖卡片落点
// 里；新建菜单的落点要同一套判定（派工单：复用，不另写），所以抽到这里，两边都调 [resolveLaneDrop]。
import 'package:flutter/widgets.dart';

import '../models/canvas_node.dart';
import 'canvas_extent.dart';
import 'canvas_zoom.dart';
import 'lane_geometry.dart';
import 'lane_pin_geometry.dart';

/// 新建节点的落点：左上角的世界坐标 + 归属泳道（null = 不在任何道里）。
typedef NodePlacement = ({Offset world, String? laneId});

/// 卡片落点的泳道归属。
///
/// [centerCrossWorld]：卡片中心的世界横截坐标（横向泳道 = y，竖向 = x），按 [fromLaneId] 的锚定
/// （null 或道已不存在 = 全局变换）。返回中心落进了哪条道，以及按那条道锚定后的中心横截坐标。
/// 泳道栈坐标里锚定没有平移项（泳道栈随平移整体走），所以只用到缩放 [scale]。
({String? laneId, double crossWorld}) resolveLaneDrop({
  required double centerCrossWorld,
  required String? fromLaneId,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
  required double scale,
}) {
  final bool horizontal = direction == LaneDirection.horizontal;
  final double crossScreen = crossToScreen(
    laneStart: laneStartOf(fromLaneId, laneSlices),
    world: centerCrossWorld,
    scale: scale,
    crossTranslation: 0,
  );
  final String? laneId = laneIdAtPoint(
    point: horizontal ? Offset(0, crossScreen) : Offset(crossScreen, 0),
    lanes: laneSlices,
    direction: direction,
  );
  final double crossWorld = crossToWorld(
    laneStart: laneStartOf(laneId, laneSlices),
    screen: crossScreen,
    scale: scale,
    crossTranslation: 0,
  );
  return (laneId: laneId, crossWorld: crossWorld);
}

/// 视口里的一点 → 世界坐标，按不在任何道里的卡片算（全局变换的逆，再减舞台原点）。
Offset viewportToWorld(Offset viewportPoint, Matrix4 transform) => stageToWorld(
      MatrixUtils.transformPoint(Matrix4.inverted(transform), viewportPoint),
    );

/// 新建菜单的落点：新卡片的左上角画在视口里的 [viewportPoint] 上。
///
/// 先当它是一张不在道里的卡（左上角 = 这一点的世界坐标），再按拖卡片落点那一套判它的中心落进哪条道、
/// 换到那条道的锚定下——落进道里的卡片画出来，左上角仍在这一点上。世界坐标收进可达范围（±kWorldReach）。
NodePlacement createNodePlacement({
  required Offset viewportPoint,
  required Matrix4 transform,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
}) {
  final Offset topLeft = viewportToWorld(viewportPoint, transform);
  final bool horizontal = direction == LaneDirection.horizontal;
  final double half =
      horizontal ? kNodeCardSize.height / 2 : kNodeCardSize.width / 2;
  final ({String? laneId, double crossWorld}) drop = resolveLaneDrop(
    centerCrossWorld: (horizontal ? topLeft.dy : topLeft.dx) + half,
    fromLaneId: null,
    laneSlices: laneSlices,
    direction: direction,
    scale: scaleOf(transform),
  );
  final Offset world = horizontal
      ? Offset(topLeft.dx, drop.crossWorld - half)
      : Offset(drop.crossWorld - half, topLeft.dy);
  return (world: clampIntoWorldReach(world), laneId: drop.laneId);
}

/// 舞台坐标里 [point] 落在哪张卡片上。
///
/// [drawn]：按绘制顺序排好、坐标已换成渲染位置（舞台坐标 + 分道位移，见 displacedNodes）的节点。
/// 后画的压在上面，所以从后往前找。卡片的命中区就是 kNodeCardSize（与卡片的 SizedBox 同一个盒）。
String? topmostNodeAt({required Offset point, required List<CanvasNode> drawn}) {
  for (int i = drawn.length - 1; i >= 0; i--) {
    if ((drawn[i].position & kNodeCardSize).contains(point)) return drawn[i].id;
  }
  return null;
}
