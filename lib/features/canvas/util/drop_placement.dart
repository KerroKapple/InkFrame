// 落点换算（纯函数）：拖卡片落点与新建菜单落点共用的泳道归属判定，外加「舞台上这一点落在哪张卡上」。
//
// 泳道钉死模型（lane_pin_geometry.dart）：泳道里的卡片以本道起始边为锚缩放，同一个世界坐标在不同的道里
// 画在不同的屏幕位置。所以「落在哪条道」要先把卡片中心换到泳道栈坐标（屏幕坐标 − 泳道栈偏移）里判，
// 再按新道的锚定逆映射回世界坐标——换道前后卡片在屏幕上不动。这一段原来写在 canvas_view 的拖卡片落点
// 里；新建菜单的落点要同一套判定（派工单：复用，不另写），所以抽到这里，两边都调 [resolveLaneDrop]。
//
// 拖卡片另多一道闸（[resolveCardDrop]）：归属泳道只在拖得够远、中心真跨过了道边界时才改——误拖一两个像素
// 不换道。拖动途中高亮目标道（[cardDropTargetLane]）与松手时的判定是同一个函数。
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

/// 拖卡片换道要求的最小拖动距离（屏幕像素）。
///
/// 卡片的拖动先吃掉平移阈值（鼠标 2px、触摸 kPanSlop）才开始累计位移，这里量的是阈值之后那一截：手一抖
/// 挪出两三个像素，拖动成立、位置照落，但归属泳道不动（演示 O2：2px 的误拖让卡片悄悄进了泳道、换了风格继承）。
/// 取触摸阈值 kTouchSlop 的值——真想把卡片拖进另一条道，拖的距离远不止这一点。
const double kLaneChangeMinDrag = 18;

/// 换道的迟滞（屏幕像素）：卡片中心要越过道的边界至少这么深，才算进了另一条道（或出了所有道）。
/// 中心压在分界线附近来回晃，归属不跟着翻。
const double kLaneChangeMargin = 12;

/// 拖卡片松手的落点：交给 moveNode 的位移（世界坐标，换道时横截分量已按新道的锚定换算）+ 归属泳道 +
/// 这一下是不是改了归属（[changed] = 要不要提示用户、拖动途中要不要高亮目标道）。
typedef CardDrop = ({Offset delta, String? laneId, bool changed});

/// 拖卡片松手：位置照落，归属泳道只在「真拖过去了」时才改。
///
/// [node]：拖动前的节点（位置 = 世界坐标，laneId = 原归属）；[dragDelta]：卡片累计的拖动位移（世界坐标）。
/// 判定用卡片**中心**（不是卡片边缘）在泳道栈坐标里落在哪条带，三条全满足才换道：
/// 1. 拖动距离（换成屏幕像素）超过 [kLaneChangeMinDrag]；
/// 2. 中心这一趟跨过了带的边界——拖动前与松手时中心所在的带不同（拖动前就压在别的道上、只是还没归进去的
///    卡片，在原地轻推不会被顺手收进去；道里的卡片画在本道带外时同理，轻推不会被顺手踢出去）；
/// 3. 中心进了新带至少 [kLaneChangeMargin]（迟滞）。
/// 任一条不满足：归属原样（[CardDrop.laneId] = node.laneId），位移原样。换道时位移的横截分量按
/// [resolveLaneDrop] 换算——换道前后卡片在屏幕上不动。
CardDrop resolveCardDrop({
  required CanvasNode node,
  required Offset dragDelta,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
  required double scale,
}) {
  final bool horizontal = direction == LaneDirection.horizontal;
  final CardDrop stay = (delta: dragDelta, laneId: node.laneId, changed: false);
  if (dragDelta.distance * scale <= kLaneChangeMinDrag) return stay;

  final double half =
      horizontal ? kNodeCardSize.height / 2 : kNodeCardSize.width / 2;
  final double startCross =
      (horizontal ? node.position.dy : node.position.dx) + half;
  final double endCross =
      startCross + (horizontal ? dragDelta.dy : dragDelta.dx);
  // 泳道栈坐标（屏幕坐标 − 泳道栈偏移）：按原道的锚定换算，无平移项（见 resolveLaneDrop）。
  final double? fromStart = laneStartOf(node.laneId, laneSlices);
  double toScreen(double world) => crossToScreen(
        laneStart: fromStart,
        world: world,
        scale: scale,
        crossTranslation: 0,
      );
  String? bandAt(double cross) => laneIdAtPoint(
        point: horizontal ? Offset(0, cross) : Offset(cross, 0),
        lanes: laneSlices,
        direction: direction,
      );

  final double endScreen = toScreen(endCross);
  final String? target = bandAt(endScreen);
  if (target == node.laneId) return stay;
  if (target == bandAt(toScreen(startCross))) return stay;
  if (bandAt(endScreen - kLaneChangeMargin) != target ||
      bandAt(endScreen + kLaneChangeMargin) != target) {
    return stay;
  }

  final ({String? laneId, double crossWorld}) drop = resolveLaneDrop(
    centerCrossWorld: endCross,
    fromLaneId: node.laneId,
    laneSlices: laneSlices,
    direction: direction,
    scale: scale,
  );
  final double crossDelta = drop.crossWorld - startCross;
  return (
    delta: horizontal
        ? Offset(dragDelta.dx, crossDelta)
        : Offset(crossDelta, dragDelta.dy),
    laneId: drop.laneId,
    changed: true,
  );
}

/// 拖动途中要高亮的目标道：这一下松手会换进哪条道。不换道、或换出所有道（没有目标道可亮）= null。
/// 与松手时的 [resolveCardDrop] 同一个判定——亮着的那条就是松手后进的那条。
String? cardDropTargetLane({
  required CanvasNode node,
  required Offset dragDelta,
  required List<({String id, double size})> laneSlices,
  required LaneDirection direction,
  required double scale,
}) {
  final CardDrop drop = resolveCardDrop(
    node: node,
    dragDelta: dragDelta,
    laneSlices: laneSlices,
    direction: direction,
    scale: scale,
  );
  return drop.changed ? drop.laneId : null;
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
