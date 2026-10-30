// 节点卡片插槽（从 canvas_view.dart 原样搬出）：每张卡各自 watch 自己的选中 / 链接 / 拖线态，改选中只重建
// 涉及的卡片；拖卡片松手判落点与换道撤销卡（_commitDrag）、出端口拖线（_portDrag）、卡片上的右键单击都在这里。
// 卡片的 Positioned 与测试锚点 Key（node-card-<id>）留在 canvas_view.dart 的舞台骨架里。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/ink_error.dart';
import '../../../../core/interfaces/toast_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../notifications/providers/toast_service_provider.dart';
import '../../models/canvas_node.dart';
import '../../models/commands/move_nodes_command.dart';
import '../../models/style_lane.dart';
import '../../providers/canvas_history_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/canvas_tool_mode.dart';
import '../../providers/link_mode_controller.dart';
import '../../util/canvas_snackbars.dart';
import '../../util/canvas_zoom.dart';
import '../../util/drop_placement.dart';
import '../../util/lane_geometry.dart';
import '../create_node_menu.dart';
import '../node_card.dart';
import 'stage_pointer_layer.dart';

/// 单个节点卡片插槽：各自 watch 自己的选中/链接态——改选中只重建涉及的卡片，
/// 不连带整个舞台层（丝滑核心）。端口占用（[hasInEdge] / [hasOutEdge]）由舞台层
/// 按存量边 + 产出线整层算一次传进来。
///
/// 出端口拖线也从这里报：指针的全局坐标换成舞台坐标写进 canvasWireDragProvider，松手时把这条拖线
/// 交给舞台层（[onWireDrop]）判落点。卡片上的右键单击同样把按下点换成舞台坐标交给舞台层（[onSecondaryClick]）。
class NodeCardSlot extends ConsumerWidget {
  const NodeCardSlot({
    super.key,
    required this.node,
    this.lane,
    required this.canvasId,
    required this.lanes,
    required this.laneSlices,
    required this.direction,
    required this.transform,
    required this.hasInEdge,
    required this.hasOutEdge,
    required this.onTap,
    required this.onSecondaryClick,
    required this.onDelete,
    required this.onWireDrop,
  });

  final CanvasNode node;
  /// 所在泳道（稿：卡片底部「继承 X」行）；无道节点为 null。
  final StyleLane? lane;
  final String canvasId;

  /// 本画布的全部泳道：拖动换道后的提示卡要写出进了 / 出了哪条道的名字。
  final List<StyleLane> lanes;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;

  /// 画布世界→屏幕变换：泳道钉在视口层（屏幕坐标），落点归属须换算后判定。
  final TransformationController transform;

  /// 入口 / 出口这一侧真挂着画出来的线——端口常驻（见 NodeCard 头注）。
  final bool hasInEdge;
  final bool hasOutEdge;
  final VoidCallback onTap;

  /// 在本卡上右键单击（抬起时报，见 [SecondaryClickDetector]）：给的是**按下点**的舞台坐标（舞台层换成视口坐标
  /// 开节点右键菜单）。
  final ValueChanged<Offset> onSecondaryClick;
  final VoidCallback onDelete;

  /// 从本卡出端口拖线后松手：舞台层判落点（连线 / 开新建菜单 / 什么都不做）。
  final void Function(WireDrag drag) onWireDrop;

  /// 指针全局坐标 → 舞台坐标：沿渲染树往上找舞台坐标系的锚（[StageSpace]）。卡片可能在分道位移组
  /// 里，位移组在锚之下，所以换出来的是舞台坐标（与 displacedNodes 同一个坐标系），不是道内坐标。
  static Offset? _toStage(BuildContext context, Offset global) => context
      .findAncestorRenderObjectOfType<RenderStageSpace>()
      ?.globalToLocal(global);

  /// 泳道 [laneId] 在提示卡上的名字（没起名 = 「未命名泳道」，道已不在也按没起名写）。
  String _laneName(AppLocalizations l, String? laneId) {
    for (final StyleLane candidate in lanes) {
      if (candidate.id == laneId) {
        return candidate.label.isEmpty ? l.laneUntitled : candidate.label;
      }
    }
    return l.laneUntitled;
  }

  /// 泳道 [laneId] 的原始名字（没起名 = 空串；道不在 = null），进撤销栈的步名用它——显示时才落「未命名泳道」，
  /// 不能拿 [_laneName] 那个已本地化的显示名。
  String? _laneRawName(String? laneId) {
    for (final StyleLane candidate in lanes) {
      if (candidate.id == laneId) return candidate.label;
    }
    return null;
  }

  /// 拖卡片松手：落位置；归属泳道只在真拖过去了时才改（判定在 util/drop_placement.dart 的 resolveCardDrop，
  /// 误拖一两个像素不换道——演示 O2）。改了归属就进画布撤销栈（MoveNodesCommand「移入 / 移出泳道「X」」）并弹
  /// 一张撤销卡「已移入 / 移出泳道 X」：卡上「撤销」只撤这一步，卡收起后 Ctrl Z / ⌘Z 仍能把卡片挪回原位置、
  /// 原泳道。没换道的普通拖动不进栈。
  ///
  /// 提示要用的东西（文案、通知服务、容器）在 await 之前取齐：换了道，卡片会被挪进另一个分道位移组重新挂载，
  /// 这个插槽的 context / ref 当场失效，等写库回来再取就晚了。
  void _commitDrag(BuildContext context, WidgetRef ref, Offset totalDelta) {
    final CardDrop drop = resolveCardDrop(
      node: node,
      dragDelta: totalDelta,
      laneSlices: laneSlices,
      direction: direction,
      scale: scaleOf(transform.value),
    );
    final AppLocalizations l = context.l10n;
    final ToastService toasts = ref.read(toastServiceProvider);
    final ProviderContainer container =
        ProviderScope.containerOf(context, listen: false);
    final CanvasNodesController nodesCtrl =
        ref.read(canvasNodesControllerProvider(canvasId).notifier);
    final String nodeId = node.id;
    final Offset origin = node.position;
    final String? fromLaneId = node.laneId;
    final String moveFailed = l.nodeMoveFailed;
    // 没换道 = null（不弹卡、不进栈）。从 A 道拖进 B 道写「已移入 B」。
    final String? laneMessage = !drop.changed
        ? null
        : drop.laneId == null
            ? l.canvasNodeLeftLane(_laneName(l, fromLaneId))
            : l.canvasNodeJoinedLane(_laneName(l, drop.laneId));
    // 步名原料：进了哪条道 / 出了哪条道，泳道名取原始 label（await 之前取）。
    final MoveNodesLabel stepLabel = drop.laneId == null
        ? (kind: MoveNodesLabelKind.outOfLane, laneName: _laneRawName(fromLaneId))
        : (kind: MoveNodesLabelKind.intoLane, laneName: _laneRawName(drop.laneId));

    // 手势回调内 fire-and-forget：控制器失败时已回滚内存态，补用户提示（不进栈）。
    Future<void> move() async {
      try {
        await nodesCtrl.moveNode(nodeId, drop.delta, laneId: drop.laneId);
      } on InkError catch (_) {
        toasts.show(moveFailed, kind: ToastKind.error);
        return;
      }
      final String? message = laneMessage;
      if (message == null) return;
      // after = 写库之后它此刻的位置（moveNode 夹过 ±kWorldReach，不自己算）。
      CanvasNode? moved;
      for (final CanvasNode n
          in container.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
              const <CanvasNode>[]) {
        if (n.id == nodeId) moved = n;
      }
      if (moved == null) return;
      final String stepId = container
          .read(canvasHistoryControllerProvider(canvasId).notifier)
          .record(
            MoveNodesCommand(
              before: <String, NodePlacement>{
                nodeId: (world: origin, laneId: fromLaneId),
              },
              after: <String, NodePlacement>{
                nodeId: (world: moved.position, laneId: drop.laneId),
              },
              label: stepLabel,
            ),
          );
      showCanvasUndoSnackWith(
        container,
        l,
        message: message,
        canvasId: canvasId,
        stepId: stepId,
      );
    }

    unawaited(move());
  }

  PortDragCallbacks _portDrag(BuildContext context, WidgetRef ref) {
    WireDragController wire() =>
        ref.read(canvasWireDragProvider(canvasId).notifier);
    return PortDragCallbacks(
      onStart: (Offset global) {
        // 平移生效时舞台内容整层不收指针（StagePanGate），端口本来就按不到；这里再拦一道，
        // 「平移时端口不可拖」不只靠那一层闸。
        if (ref.read(canvasPanActiveProvider(canvasId))) return;
        final Offset? stage = _toStage(context, global);
        if (stage != null) wire().start(node.id, stage);
      },
      onUpdate: (Offset global) {
        final Offset? stage = _toStage(context, global);
        if (stage != null) wire().moveTo(node.id, stage);
      },
      onEnd: () {
        // 已被 Esc 取消（或根本没开始）的拖线，finish 交回 null：松手什么都不做。
        final WireDrag? drag = wire().finish(node.id);
        if (drag != null) onWireDrop(drag);
      },
      onCancel: () {
        wire().finish(node.id);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select：仅当本节点的"是否被选中"翻转时才重建本卡片。
    final selected = ref.watch(
      canvasSelectionControllerProvider(canvasId).select((s) => s.contains(node.id)),
    );
    final linkSourceId = ref.watch(linkModeControllerProvider(canvasId));
    // 拖线的源：.select 掉指针位置——只在拖线开始 / 结束那一下翻转，指针每动一下不重建卡片。
    final String? wireSourceId = ref.watch(
      canvasWireDragProvider(canvasId).select((WireDrag? d) => d?.sourceNodeId),
    );
    // 拖线期间的高亮与连线模式同一套样式：源卡片 = 起点，其余卡片 = 可连的目标。
    final String? activeSourceId = linkSourceId ?? wireSourceId;
    // 右键单击（与空白处的右键同一做法）：只听原始指针事件、不进手势竞技场——卡片的单击 / 拖动不受影响；
    // 按住右键拖动不算。平移生效时舞台内容整层不收指针（StagePanGate），这里也就收不到，平移时不开菜单。
    return SecondaryClickDetector(
      onSecondaryClick: (PointerDownEvent down) {
        final Offset? stage = _toStage(context, down.position);
        if (stage != null) onSecondaryClick(stage);
      },
      child: RepaintBoundary(
      child: NodeCard(
        node: node,
        lane: lane,
        selected: selected,
        onTap: onTap,
        // 泳道钉死模型：落点中心先经"原道锚定"映射到屏幕坐标判归属，再按"新道锚定"逆映射回世界坐标——
        // 保证换道落点视觉位置不变（resolveCardDrop 里调的 resolveLaneDrop，新建菜单的落点调的是同一个函数）。
        onDragEnd: (Offset totalDelta) => _commitDrag(context, ref, totalDelta),
        onStartLink: () =>
            ref.read(linkModeControllerProvider(canvasId).notifier).start(node.id),
        onDelete: onDelete,
        isLinkSource: activeSourceId == node.id,
        isLinkCandidate: activeSourceId != null && activeSourceId != node.id,
        hasInEdge: hasInEdge,
        hasOutEdge: hasOutEdge,
        portDrag: _portDrag(context, ref),
      ),
      ),
    );
  }
}
