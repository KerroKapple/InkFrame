// 舞台的泳道层（从 canvas_view.dart 原样搬出）。泳道钉在视口层、不进 InteractiveViewer：
//   - StageLaneShift：泳道栈锚在世界原点——拖画布时整体跟着世界走，缩放时道厚不变（laneStackOffset）
//   - StageLaneBackgroundLayer：泳道底色带（世界内容之下），拖卡片途中高亮松手会换进的那条道
//   - StageLaneLayer：泳道标题栏（拖拽重排 + 折叠 + 编辑 / 删除）+ 分界线拖拽条（世界内容之上）
// 三层的 watch 位置与原来一致：泳道 / 方向 / 折叠 / 相机由舞台骨架 watch 后传进来，这里只在
// 底色层的 Consumer 里 .select 拖拽位移。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/ink_error.dart';
import '../../../../core/interfaces/toast_service.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.dart';
import '../../../notifications/providers/toast_service_provider.dart';
import '../../models/canvas_node.dart';
import '../../models/style_lane.dart';
import '../../providers/canvas_lanes_controller.dart';
import '../../providers/lane_collapse_controller.dart';
import '../../providers/node_drag_delta.dart';
import '../../util/canvas_snackbars.dart';
import '../../util/canvas_zoom.dart';
import '../../util/drop_placement.dart';
import '../../util/lane_geometry.dart';
import '../../util/lane_pin_geometry.dart';
import '../lane_background.dart';
import '../lane_edit_dialog.dart';
import '../lane_title_bar.dart';

/// 泳道皮层的平移：随泳道栈同偏移平移 [child]（底色带、标题栏 / 拖拽条两组共用）。
///
/// 偏移必须用 Positioned（每帧重建）而非 Transform.translate：
/// RenderBox.hitTest 先按未变换的盒子边界筛，Transform 只移画面
/// 不移命中区——平移后泳道边界"看得见摸不着"（宽度拖拽锁死）。
class StageLaneShift extends StatelessWidget {
  const StageLaneShift({
    super.key,
    required this.transform,
    required this.direction,
    required this.viewport,
    required this.skinExtent,
    required this.child,
  });

  final TransformationController transform;
  final LaneDirection direction;

  /// 舞台视口尺寸（横向道的皮层宽 / 竖向道的皮层高）。
  final Size viewport;

  /// 皮层盒子沿泳道栈方向的厚度：泳道栈总厚 + 一个标题栏的余量（BOARD P2-3）。
  final double skinExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final horizontal = direction == LaneDirection.horizontal;
    final size = viewport;
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transform,
      builder: (context, m, c) {
        final off = laneStackOffset(m, direction);
        return Stack(
          children: [
            Positioned(
              left: horizontal ? 0 : off,
              top: horizontal ? off : 0,
              width: horizontal ? size.width : skinExtent,
              height: horizontal ? skinExtent : size.height,
              child: c!,
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// 泳道底色带：不收指针。拖卡片途中高亮松手会换进的那条道——.select 掉每帧的位移，只在目标道翻转时
/// 重建这一层。
class StageLaneBackgroundLayer extends StatelessWidget {
  const StageLaneBackgroundLayer({
    super.key,
    required this.lanes,
    required this.nodes,
    required this.laneSlices,
    required this.direction,
    required this.collapsedIds,
    required this.transform,
    required this.viewport,
  });

  final List<StyleLane> lanes;
  final List<CanvasNode> nodes;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final Set<String> collapsedIds;

  /// 相机：判目标道时按此刻的缩放算（在 select 回调里读 value，不在构造时取一次）。
  final TransformationController transform;
  final Size viewport;

  // 拖卡片途中松手会换进哪条道（泳道背景层据此高亮）：与松手时 NodeCardSlot 的 resolveCardDrop
  // 同一个判定。拖的不是本画布的卡（广播是全局的）= null。
  String? _dropTargetLaneOf(NodeDragDelta? drag) {
    if (drag == null) return null;
    for (final CanvasNode n in nodes) {
      if (n.id != drag.nodeId) continue;
      return cardDropTargetLane(
        node: n,
        dragDelta: drag.delta,
        laneSlices: laneSlices,
        direction: direction,
        scale: scaleOf(transform.value),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final horizontal = direction == LaneDirection.horizontal;
    final size = viewport;
    return IgnorePointer(
      // 拖卡片途中高亮松手会换进的那条道：.select 掉每帧的位移，只在目标道翻转时重建这一层。
      child: Consumer(
        builder: (context, ref, _) => LaneBackground(
          lanes: lanes,
          direction: direction,
          canvasExtent:
              horizontal ? size.width : size.height,
          dividerColor: colors.borderSubtle,
          railFallbackColor: colors.control,
          collapsedIds: collapsedIds,
          dropTargetLaneId: ref.watch(
            nodeDragDeltaProvider.select(_dropTargetLaneOf),
          ),
          dropTargetColor: colors.accent,
        ),
      ),
    );
  }
}

/// 泳道标题栏 + 分界线拖拽条：视口层、随泳道栈同偏移平移（外面的 StageLaneShift 与平移闸
/// StagePanGate 留在舞台骨架里包它）。
/// 感应条必须压在标题栏之上——标题栏横跨整条泳道顶部，若反过来
/// 会盖住感应条下半段，边界拖拽十有八九落在标题栏上（宽度调不动）。
class StageLaneLayer extends ConsumerWidget {
  const StageLaneLayer({
    super.key,
    required this.canvasId,
    required this.lanes,
    required this.laneSlices,
    required this.nodes,
    required this.direction,
    required this.collapsedIds,
    required this.viewport,
  });

  final String canvasId;
  final List<StyleLane> lanes;
  final List<({String id, double size})> laneSlices;
  final List<CanvasNode> nodes;
  final LaneDirection direction;
  final Set<String> collapsedIds;
  final Size viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = viewport;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._buildLaneTitleBars(
          context,
          ref,
          lanes,
          laneSlices,
          nodes,
          direction,
          collapsedIds,
          size,
        ),
        if (lanes.length >= 2)
          ..._buildResizeDividers(
            context, ref, lanes, laneSlices, direction, collapsedIds, size,
          ),
      ],
    );
  }

  /// 为每条泳道生成标题栏 Positioned widget 列表（含拖拽重排 + 折叠）。
  ///
  /// lane-stack 空间（外层已随泳道栈偏移平移）：坐标/尺寸为屏幕像素，
  /// 道 i 起始边恒为 laneStart_i，不随缩放变化。
  List<Widget> _buildLaneTitleBars(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    List<({String id, double size})> laneSlices,
    List<CanvasNode> nodes,
    LaneDirection direction,
    Set<String> collapsedIds,
    Size viewport,
  ) {
    // 稿：标题栏 26px；横向固定 268 宽、左 14 / 道顶 +14；竖向 left = 道左 + 12、top 14、
    // 宽 min(道宽 − 24, 240)（下限 LaneTitleBar.minWidth，窄道时溢出但可命中——BOARD P2-3）。
    // 折叠道（36 轨）里标题栏垂直居中。
    const double kTitleBarHeight = LaneTitleBar.height;
    const double kTitleBarInsetH = 14.0;
    const double kTitleBarInsetV = 12.0;
    const double kTitleBarTop = 14.0;
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: direction == LaneDirection.horizontal
          ? viewport.width
          : viewport.height,
    );
    final counts = <String, int>{};
    for (final n in nodes) {
      if (n.laneId != null) counts[n.laneId!] = (counts[n.laneId!] ?? 0) + 1;
    }
    final result = <Widget>[];
    for (var i = 0; i < lanes.length; i++) {
      final lane = lanes[i];
      final rect = rects[i];
      final bool collapsed = collapsedIds.contains(lane.id);
      final double crossInset = collapsed ? (kCollapsedLaneSize - kTitleBarHeight) / 2 : kTitleBarTop;
      final double left;
      final double top;
      final double? width;
      if (direction == LaneDirection.horizontal) {
        left = kTitleBarInsetH;
        top = rect.top + crossInset;
        width = LaneTitleBar.horizontalWidth;
      } else {
        left = rect.left + kTitleBarInsetV;
        // 竖向道的标题栏钉在视口顶：同样让出浮动工具条那一条，否则居中的工具条一直盖着
        // 中间几条道的标题栏（横向道随泳道栈走，默认相机已让出）。
        top = InkToolbarSize.stageTopInset + crossInset;
        width = (rect.width - kTitleBarInsetV * 2)
            .clamp(LaneTitleBar.minWidth, LaneTitleBar.verticalMaxWidth);
      }
      // 拖拽重排：记录拖拽偏移，pan end 时计算目标 lane 并 reorderLanes。
      var dragOffset = Offset.zero;
      result.add(
        Positioned(
          left: left,
          top: top,
          width: width,
          height: kTitleBarHeight,
          child: GestureDetector(
            onPanUpdate: (d) => dragOffset += d.delta,
            onPanEnd: (_) {
              final moved = dragOffset;
              dragOffset = Offset.zero;
              if (moved.distance < 12) return; // 阈值：避免误触重排
              final dropPoint = direction == LaneDirection.horizontal
                  ? Offset(0, rect.top + kTitleBarHeight / 2 + moved.dy)
                  : Offset(rect.left + rect.width / 2 + moved.dx, 0);
              final targetId = laneIdAtPoint(
                point: dropPoint,
                lanes: laneSlices,
                direction: direction,
              );
              final ids = reorderedLaneIds(
                [for (final l in lanes) l.id],
                lane.id,
                targetId,
              );
              ref
                  .read(canvasLanesControllerProvider(canvasId).notifier)
                  .reorderLanes(ids);
            },
            child: LaneTitleBar(
              lane: lane,
              nodeCount: counts[lane.id] ?? 0,
              collapsed: collapsed,
              onToggleCollapse: () => ref
                  .read(laneCollapseProvider(canvasId).notifier)
                  .toggle(lane.id),
              onEdit: () => _onEditLane(context, ref, lane),
              onDelete: () => _onDeleteLane(context, ref, lane),
            ),
          ),
        ),
      );
    }
    return result;
  }

  // 拖拽分界线调整相邻泳道大小（~10px 透明感应条，仅命中不绘制）。
  // 视口层：厚度恒为屏幕像素；位置随泳道栈平移（laneStackOffset），缩放不改道厚。
  List<Widget> _buildResizeDividers(
    BuildContext context,
    WidgetRef ref,
    List<StyleLane> lanes,
    List<({String id, double size})> laneSlices,
    LaneDirection direction,
    Set<String> collapsedIds,
    Size viewport,
  ) {
    const double kStripThick = 10.0;
    final rects = laneRects(
      lanes: laneSlices,
      direction: direction,
      canvasExtent: direction == LaneDirection.horizontal
          ? viewport.width
          : viewport.height,
    );
    final horizontal = direction == LaneDirection.horizontal;
    final result = <Widget>[];
    // 相邻泳道之间各一条感应条，以 upper lane id 为键。
    for (var i = 1; i < lanes.length; i++) {
      final upperLane = lanes[i - 1];
      // 折叠的道厚度是定值，不给拖。
      if (collapsedIds.contains(upperLane.id)) continue;
      final dividerPos = horizontal ? rects[i].top : rects[i].left;
      final upperLaneId = upperLane.id;
      final double currentSize = upperLane.size;
      double delta = 0;

      // 手势回调内 fire-and-forget：控制器失败时已回滚内存态，这里补用户提示。
      Future<void> commit() async {
        final newSize = clampLaneSize(currentSize, delta);
        delta = 0;
        try {
          await ref
              .read(canvasLanesControllerProvider(canvasId).notifier)
              .updateLane(upperLaneId, size: newSize);
        } on InkError catch (_) {
          if (context.mounted) {
            showCanvasSnack(context, context.l10n.laneUpdateFailed);
          }
        }
      }

      result.add(
        Positioned(
          left: horizontal ? 0 : dividerPos - kStripThick / 2,
          top: horizontal ? dividerPos - kStripThick / 2 : 0,
          width: horizontal ? viewport.width : kStripThick,
          height: horizontal ? kStripThick : viewport.height,
          child: MouseRegion(
            cursor: horizontal
                ? SystemMouseCursors.resizeRow
                : SystemMouseCursors.resizeColumn,
            // translucent：感应条自身收 pan（层序在标题栏之上，#184），
            // 同时不吞掉带下内容的命中——10px 带内连线/卡片仍可点选。
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => delta += horizontal ? d.delta.dy : d.delta.dx,
              onPanEnd: (_) => commit(),
            ),
          ),
        ),
      );
    }
    return result;
  }

  Future<void> _onEditLane(
    BuildContext context,
    WidgetRef ref,
    StyleLane lane,
  ) async {
    final r = await showLaneEditDialog(context, existing: lane);
    if (r == null) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(canvasLanesControllerProvider(canvasId).notifier)
          .updateLane(
            lane.id,
            label: r.label,
            stylePrompt: r.stylePrompt,
            tintColor: r.tintColor,
            clearTint: r.tintColor == null,
          );
    } on InkError catch (_) {
      if (context.mounted) {
        showCanvasSnack(context, context.l10n.laneUpdateFailed);
      }
    }
  }

  Future<void> _onDeleteLane(
    BuildContext context,
    WidgetRef ref,
    StyleLane lane,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.laneDeleteConfirmTitle),
          content: Text(l10n.laneDeleteConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.laneDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.laneDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    // 失败提示要用的东西（通知服务、文案）在 await 之前取齐：删的是最后一条道时，乐观移除让舞台骨架把
    // 本层整个拆掉（它只在有泳道时挂着），写库失败回滚时本层的 context 早已失效——原来挂在舞台层上时
    // 没有这个问题，搬出来之后得自己兜住，同 NodeCardSlot._commitDrag。
    final ToastService toasts = ref.read(toastServiceProvider);
    final String deleteFailed = context.l10n.laneDeleteFailed;
    try {
      await ref
          .read(canvasLanesControllerProvider(canvasId).notifier)
          .deleteLane(lane.id);
    } on InkError catch (_) {
      toasts.show(deleteFailed, kind: ToastKind.error);
    }
  }
}
