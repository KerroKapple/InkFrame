// CanvasView：画布主视图 — InteractiveViewer 视口 + Stack 节点渲染。
//
// 职责切分（HI-18）：
//   - _CanvasBody：状态装配 + 节点 tap 语义 + 连线事件 → snackbar 副作用（ref.listen）
//   - _CanvasStage：舞台骨架——watch 选中边 / 边 / 泳道 / 方向 / 折叠 / 相机，整层算一次切片、可见集、产出线、
//     端口占用，组装下面各层；卡片的 Positioned 与测试锚点 Key（node-card-<id> / lane-group-<id>）在这里
//   - 舞台各层在 stage/ 下各占一个文件（只搬家，行为不变）：
//       stage_pointer_layer.dart：平移闸 StagePanGate（平移工具 H / 按住空格，canvas_tool_mode.dart——舞台内容与
//         泳道标题栏层不收指针、拖哪儿都是拖画布）+ 手形光标 StagePanCursor + 舞台坐标锚 StageSpace +
//         空白处双击 / 右键 BlankPointerDetector + 右键单击 SecondaryClickDetector（空白处与卡片上都是抬起时开、
//         按下到抬起没挪出点击容差才开，锚点用按下点：按住右键拖动是拖画布，不开菜单）
//       node_card_slot.dart：NodeCardSlot（各卡自己 watch 选中 / 链接 / 拖线态；拖卡松手换道 + 撤销卡；
//         出端口拖线；卡片上的右键单击）
//       stage_edge_layer.dart：连线绘制 StageEdgeLayer、选中边删除钮 StageEdgeDeleteOverlay、
//         拖线实时虚线 PendingWireLayer、边 / 泳道加载失败横幅 EdgeLaneErrorSlot
//       stage_lane_layer.dart：泳道皮层平移 StageLaneShift、底色带 StageLaneBackgroundLayer、
//         标题栏 + 分界线 StageLaneLayer
//       stage_overlays.dart：挂起定位落地 PendingFocusApplier、计数 chip、连线提示条、加载失败整屏
//   - 可播放性 IO 判定在 playableVideoPathProvider；连线编排在 LinkActionController
//   - 新建菜单（create_node_menu.dart）：从卡片出端口拖线（NodeCardSlot 报拖线、PendingWireLayer 画
//     实时虚线、舞台层判落点——落在卡上 = linkTo，落在空白 = 带上下文开菜单）、空白处双击 / 右键
//     （BlankPointerDetector）都开它；菜单宿主 CanvasMenuHost 包在 _CanvasBody 最外层。拖线途中源卡没了
//     （被删）由 _CanvasBody 看着节点集取消拖线——卡片插槽已经卸载，它自己收不了
//   - 节点右键菜单（PR-8b，同一个宿主）：卡片插槽收右键单击，舞台层先处理选中（没选中的先单选它，已在
//     多选里的保持多选）再在按下点开菜单

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_id.dart';
import '../providers/link_action_controller.dart';
import '../providers/link_mode_controller.dart';
import '../providers/playable_video_path.dart';
import '../providers/selected_edge_controller.dart';
import '../util/canvas_extent.dart';
import '../util/canvas_node_delete.dart';
import '../util/canvas_snackbars.dart';
import '../util/canvas_tool_actions.dart';
import '../util/canvas_zoom.dart';
import '../util/drop_placement.dart';
import '../util/edge_hit_test.dart';
import '../util/lineage_edges.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../util/lane_geometry.dart';
import '../util/lane_pin_geometry.dart';
import '../../shell/widgets/shell_empty_state.dart';
import 'canvas_empty_state.dart';
import 'canvas_grid_painter.dart';
import 'create_node_menu.dart';
import 'lane_title_bar.dart';
import 'lane_toolbar.dart';
import 'stage/node_card_slot.dart';
import 'stage/stage_edge_layer.dart';
import 'stage/stage_lane_layer.dart';
import 'stage/stage_overlays.dart';
import 'stage/stage_pointer_layer.dart';
import 'video_lightbox.dart';

// InteractiveViewer 平移越界余量（画布外延展空间，非视觉 token）
const double kCanvasBoundaryMargin = 2000;

class CanvasView extends ConsumerWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    final colors = context.inkColors;
    if (canvasId == null) {
      // 生产路径里到不了这里：外壳的 CanvasTab 在 canvasId == null 时就换上了
      // 同一个空态（还带「回到 Studio」CTA）。直接 mount CanvasView 的测试 /
      // 工具会走到这一支，所以渲染的是同一块共用空态，而不是另造一块。
      return ColoredBox(
        color: colors.surface1,
        child: ShellEmptyState(
          icon: Icons.account_tree_outlined,
          title: context.l10n.shellCanvasEmptyTitle,
          body: context.l10n.shellCanvasEmptyBody,
        ),
      );
    }

    final nodesAsync = ref.watch(canvasNodesControllerProvider(canvasId));
    return nodesAsync.when(
      loading: () => Container(
        color: colors.surface1,
        child: const Center(child: CircularProgressIndicator()),
      ),
      // raw toString 上屏收敛（GAP-3 审计;设置页安全存储探测行的诊断详情
      // 为有意例外）——走 l10n 映射。
      error: (err, _) => CanvasLoadError(message: l10nAsyncError(context, err)),
      data: (nodes) => PendingFocusApplier(
        canvasId: canvasId,
        nodes: nodes,
        child: _CanvasBody(canvasId: canvasId, nodes: nodes),
      ),
    );
  }
}

/// 状态装配层：连线事件 snackbar 副作用 + 节点 tap 语义 + 布局组合。
class _CanvasBody extends ConsumerWidget {
  const _CanvasBody({required this.canvasId, required this.nodes});

  final String canvasId;
  final List<CanvasNode> nodes;

  /// 连线结果事件 → 通知卡映射（ME-08：duplicate / failed 分流）。
  /// 连上了是 success；自连 / 已存在是没连成但什么也没坏，用户换个目标就行 → warning；
  /// 只有写库失败才是 error（错误卡不自动消失）。
  void _onLinkEvent(BuildContext context, LinkActionEvent? event) {
    if (event == null) return;
    final l10n = context.l10n;
    final (String text, ToastKind kind) = switch (event.result) {
      LinkActionResult.created => (l10n.linkCreated, ToastKind.success),
      LinkActionResult.selfLinkRejected =>
        (l10n.linkSelfNotAllowed, ToastKind.warning),
      LinkActionResult.duplicate => (l10n.linkAlreadyExists, ToastKind.warning),
      LinkActionResult.failed => (l10n.linkCreateFailed, ToastKind.error),
    };
    showCanvasSnack(context, text, kind: kind);
  }

  Future<void> _handleNodeTap(
    BuildContext context,
    WidgetRef ref,
    CanvasNode node,
  ) async {
    // link 模式：编排交给 LinkActionController，结果经 ref.listen 出 snackbar。
    if (ref.read(linkModeControllerProvider(canvasId)) != null) {
      await ref
          .read(linkActionControllerProvider(canvasId).notifier)
          .linkTo(node.id);
      return;
    }

    final selectionCtrl =
        ref.read(canvasSelectionControllerProvider(canvasId).notifier);

    // 可播放 video result → 打开 Lightbox，不走常规多选。
    final playablePath = ref.read(playableVideoPathProvider(node));
    if (playablePath != null) {
      selectionCtrl.select(node.id);
      await showVideoLightbox(context, videoPath: playablePath);
      return;
    }

    final keyboard = HardwareKeyboard.instance;
    final modifierHeld =
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed;
    selectionCtrl.select(node.id, toggle: modifierHeld);
  }

  /// 拖线途中源卡没了（Delete 键 / 撤销 / 别处删掉）：取消拖线（B5）。
  ///
  /// 源卡的插槽跟着卸载，拖线手势随之销毁、松手再也回调不到；插槽自己收不了——它卸载之后 ref 已不可用
  /// （原来 NodeCard.dispose 里补的那一手因此从没生效过）。拖线状态不收，实时虚线与其余卡片的「可连目标」
  /// 高亮就一直挂着。节点集在这一层是知道的，所以在这里看着：源不在当前节点集里了就取消。
  void _cancelOrphanedWire(WidgetRef ref, List<CanvasNode>? next) {
    if (next == null) return;
    final WireDrag? drag = ref.read(canvasWireDragProvider(canvasId));
    if (drag == null) return;
    for (final CanvasNode n in next) {
      if (n.id == drag.sourceNodeId) return;
    }
    ref.read(canvasWireDragProvider(canvasId).notifier).cancel();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LinkActionEvent?>(
      linkActionControllerProvider(canvasId),
      (_, next) => _onLinkEvent(context, next),
    );
    ref.listen<AsyncValue<List<CanvasNode>>>(
      canvasNodesControllerProvider(canvasId),
      (_, AsyncValue<List<CanvasNode>> next) => _cancelOrphanedWire(ref, next.valueOrNull),
    );

    // 本层不再 watch 选中/链接态——这两类高频变化下沉到各插槽各自 watch，
    // 避免改一次选中就整层（含全部节点卡片）重建。
    void onEmptyTap() {
      if (ref.read(linkModeControllerProvider(canvasId)) != null) {
        ref.read(linkModeControllerProvider(canvasId).notifier).cancel();
      }
      ref.read(canvasSelectionControllerProvider(canvasId).notifier).clear();
      ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
    }

    final Widget canvasArea;
    if (nodes.isEmpty) {
      canvasArea = CanvasEmptyState(
        canvasId: canvasId,
        onBackgroundTap: onEmptyTap,
      );
    } else {
      canvasArea = _CanvasStage(
        canvasId: canvasId,
        nodes: nodes,
        onNodeTap: (node) => _handleNodeTap(context, ref, node),
        onEmptyTap: onEmptyTap,
      );
    }

    // 顶部三条浮层从 stageTopInset 起：舞台顶部居中压着浮动工具条（canvas_screen 画在
    // 本层之上），从 md 起的话连线提示的后半句会被工具条盖住。
    final Widget leftArea = Stack(
      children: [
        Positioned.fill(child: canvasArea),
        // 边/泳道/泳道方向加载失败 → 非阻塞横幅（节点照常渲染），可忽略。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: EdgeLaneErrorSlot(canvasId: canvasId),
        ),
        // 链接提示条：仅随 linkMode 重建。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          left: InkSpacing.md,
          right: InkSpacing.md,
          child: LinkHintSlot(canvasId: canvasId),
        ),
        // 多选计数 chip：仅随选中数量重建。
        Positioned(
          top: InkToolbarSize.stageTopInset,
          right: InkSpacing.md,
          child: SelectionCountSlot(canvasId: canvasId),
        ),
        // 泳道工具栏：左下角，叠在缩放条（canvas_screen，left 12 / bottom 12）之上，
        // 左沿与它对齐。
        Positioned(
          bottom: InkToolbarSize.stageBottomInset,
          left: InkSpacing.s12,
          child: LaneToolbar(canvasId: canvasId),
        ),
      ],
    );

    // 节点 Inspector 已迁到右侧面板（canvas_inspector_panel.dart），本层只剩画布。
    // 新建菜单 / 空白处右键菜单的宿主包在画布区最外层：菜单浮在 Overlay 上，锚点坐标系就是这一块
    // （= 舞台视口；空态画布同样包着，Tab 在空画布上也开得出来）。
    return CanvasMenuHost(canvasId: canvasId, child: leftArea);
  }
}

/// 舞台层：InteractiveViewer + 连线层 + 节点卡片 + 选中边删除按钮。
class _CanvasStage extends ConsumerWidget {
  const _CanvasStage({
    required this.canvasId,
    required this.nodes,
    required this.onNodeTap,
    required this.onEmptyTap,
  });

  final String canvasId;
  final List<CanvasNode> nodes;
  final void Function(CanvasNode node) onNodeTap;
  final VoidCallback onEmptyTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    // 选中/链接态不在本层 watch——下沉到 NodeCardSlot 各自 watch，改选中
    // 只重建涉及的卡片，不再整层重建（丝滑核心）。
    final selectedEdgeId = ref.watch(selectedEdgeControllerProvider(canvasId));
    final edges =
        // 良性降级（GAP-3 审计 B 类）：错误横幅在 EdgeLaneErrorSlot
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    // 泳道数据。
    final lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
        const <StyleLane>[];
    final direction =
        ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
        LaneDirection.horizontal;
    // 折叠态（纯 UI，不持久化）。
    final collapsedIds = ref.watch(laneCollapseProvider(canvasId));
    // 拖拽落点 → 泳道归属用的切片，整层算一次复用给各卡片插槽。
    // 【有效厚度】：折叠的道按 kCollapsedLaneSize（Lanes 稿改动 4）——几何全家同吃这一份，
    // 折叠才真的省空间。
    final laneSlices = collapseLaneSlices(
      [for (final l in lanes) (id: l.id, size: l.size)],
      collapsedIds,
    );
    // 折叠道里的节点不画：连线 / 命中 / 选中边几何都只看这份可见集。
    final visibleNodes = [
      for (final n in nodes)
        if (n.laneId == null || !collapsedIds.contains(n.laneId)) n,
    ];
    // 产出线：由 source_node_id 推导（不落库、点不中、删不掉——命中仍只看存量边），
    // 只在可见节点之间推：折叠道里的端点不画，线也不画。整层算一次，连线层与端口共用。
    final lineage = deriveLineageEdges(nodes: visibleNodes, edges: edges);
    // 端口按需显示：哪一侧真挂着画出来的线（存量边 + 产出线）就常驻那一侧。
    final ports = connectedPortSides(
      nodes: visibleNodes,
      edges: edges,
      lineage: lineage,
    );

    // PL-2：绑定快捷键缩放共用的变换控制器（按 canvasId 分族；gesture 平移/缩放照常）。
    final transformController = ref.watch(
      canvasTransformControllerProvider(canvasId),
    );

    // 舞台坐标这一点压着哪条连线。命中用渲染位置（含分道位移），与 EdgePainter 同源。
    String? edgeAt(Offset stagePoint) => hitTestEdge(
          point: stagePoint,
          edges: edges,
          nodes: displacedNodes(
            nodes: visibleNodes,
            lanes: laneSlices,
            direction: direction,
            transform: transformController.value,
          ),
          direction: direction,
        );

    void onEdgeLayerTap(TapDownDetails d) {
      final hitId = edgeAt(d.localPosition);
      if (hitId != null) {
        ref.read(selectedEdgeControllerProvider(canvasId).notifier).select(hitId);
        return;
      }
      onEmptyTap();
    }

    // 空白处双击 → 在双击点开新建菜单；空白处右键单击 → 在按下的那一点开空白处右键菜单（create_node_menu.dart）。
    // 压着连线不算空白：连线自己的右键菜单不归这一版。菜单锚点是视口坐标（舞台坐标过一遍相机）。
    void onBlankDoubleDown(Offset stagePoint) {
      if (edgeAt(stagePoint) != null) return;
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openCreate(
            MatrixUtils.transformPoint(transformController.value, stagePoint),
          );
    }

    void onBlankSecondaryClick(Offset stagePoint) {
      if (edgeAt(stagePoint) != null) return;
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openBlank(
            MatrixUtils.transformPoint(transformController.value, stagePoint),
          );
    }

    // 卡片上右键单击 → 节点右键菜单开在按下的那一点。右键一张没被选中的卡：先把选中换成它；右键一张已在
    // 选中集里的卡（多选）：保持多选——菜单作用在整个选中集上（node_menu_model.nodeMenuTargets）。
    void onNodeSecondaryClick(CanvasNode node, Offset stagePoint) {
      if (!ref.read(canvasSelectionControllerProvider(canvasId)).contains(node.id)) {
        ref.read(canvasSelectionControllerProvider(canvasId).notifier).select(node.id);
      }
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openNode(
            MatrixUtils.transformPoint(transformController.value, stagePoint),
            node.id,
          );
    }

    final selectedGeometry = selectedEdgeGeometry(
      selectedEdgeId: selectedEdgeId,
      edges: edges,
      nodes: visibleNodes,
    );

    // 全向无限画布：居中定舞台（100k×100k，世界原点在正中央）。
    // Positioned/painter 使用舞台坐标 = 世界坐标 + kStageOrigin。
    const stage = kStageSize;

    // 各泳道起始边（屏幕坐标 = 有效厚度顺序累计），分道位移组用。
    final laneStarts = <String, double>{};
    {
      var offset = 0.0;
      for (final l in laneSlices) {
        laneStarts[l.id] = offset;
        offset += l.size;
      }
    }
    // 无道（或道已不存在）的节点走全局变换。
    final freeNodes = [
      for (final n in nodes)
        if (n.laneId == null || !laneStarts.containsKey(n.laneId)) n,
    ];

    // 卡片的绘制顺序：无道的先画，再逐条道画道里的（折叠的道不画）。拖线落点找「最上面那张卡」
    // 按它倒着找，与肉眼看到的叠放一致。
    final List<CanvasNode> paintOrder = <CanvasNode>[
      ...freeNodes,
      for (final StyleLane lane in lanes)
        if (!collapsedIds.contains(lane.id))
          for (final CanvasNode n in nodes)
            if (n.laneId == lane.id) n,
    ];

    // 从出端口拖线后松手：落在另一张卡上 = 连线（走连线模式那一条 linkTo：智能默认角色、23505 去重、
    // 结果提示都是它的）；落在空白处 = 在松手点开新建菜单，带「从哪张卡拖出来」的上下文；
    // 落回源卡片自己 = 什么都不做。
    void onWireDrop(WireDrag drag) {
      final Matrix4 m = transformController.value;
      final String? target = topmostNodeAt(
        point: drag.pointer,
        drawn: displacedNodes(
          nodes: paintOrder,
          lanes: laneSlices,
          direction: direction,
          transform: m,
        ),
      );
      if (target == drag.sourceNodeId) return;
      if (target != null) {
        linkByPortDrop(
          ref,
          canvasId: canvasId,
          sourceNodeId: drag.sourceNodeId,
          targetNodeId: target,
        );
        return;
      }
      ref.read(canvasMenuRequestProvider(canvasId).notifier).openCreate(
            MatrixUtils.transformPoint(m, drag.pointer),
            sourceNodeId: drag.sourceNodeId,
          );
    }

    return Container(
      color: colors.surface1,
      // 视口尺寸上报给缩放层（围绕视口中心缩放需要）。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(canvasViewportSizeProvider(canvasId).notifier).setSize(size);
            }
          });
          // 泳道模型（终版）：泳道栈锚在世界原点——拖画布时整体跟着世界走，
          // 缩放时道厚不变、只有道内内容以本道起始边为锚缩放。
          // 皮分两组同偏移平移（StageLaneShift）：底色带在世界内容之下，标题栏/拖拽条之上。
          final lanesTotal = laneSlices.fold(0.0, (sum, l) => sum + l.size);
          // 皮层盒子比泳道栈多留一个标题栏的余量（BOARD P2-3）：竖向窄道的标题栏按下限宽
          // 溢出到栈外时仍在盒内——RenderBox.hitTest 先按盒界筛，盒外的按钮看得见点不到。
          final skinExtent = lanesTotal + LaneTitleBar.minWidth;
          Widget laneShifted(Widget child) => StageLaneShift(
                transform: transformController,
                direction: direction,
                viewport: size,
                skinExtent: skinExtent,
                child: child,
              );
          return Stack(
            children: [
              // 稿：24px 网格底（屏幕空间，不随缩放）。
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: CanvasGridPainter(colors.canvasGrid)),
                ),
              ),
              if (lanes.isNotEmpty)
                Positioned.fill(
                  child: laneShifted(
                    StageLaneBackgroundLayer(
                      lanes: lanes,
                      nodes: nodes,
                      laneSlices: laneSlices,
                      direction: direction,
                      collapsedIds: collapsedIds,
                      transform: transformController,
                      viewport: size,
                    ),
                  ),
                ),
              Positioned.fill(
                child: StagePanCursor(
                  canvasId: canvasId,
                  child: InteractiveViewer(
            transformationController: transformController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(kCanvasBoundaryMargin),
            minScale: kCanvasMinScale,
            maxScale: kCanvasMaxScale,
            // 平移生效：舞台内容（连线命中层 / 卡片 / 边删除钮）整层不收指针，命中落到
            // InteractiveViewer 自己的 opaque 手势层上——拖到卡片上也是拖画布。
            child: StagePanGate(
              canvasId: canvasId,
              // 舞台坐标系的锚：拖线时卡片插槽往上找它，把指针的全局坐标换成舞台坐标。
              child: StageSpace(
              child: SizedBox(
              width: stage.width,
              height: stage.height,
              child: Stack(
                // 分道位移组会把泳道内容平移出舞台矩形，不裁。
                clipBehavior: Clip.none,
                children: [
                  // 连线层（含点击命中）。translucent 让空白处也冒泡。卡片盖着的地方点不到这一层，
                  // 所以这里收到的双击 / 右键就是「空白处」的（BlankPointerDetector）。
                  Positioned.fill(
                    child: BlankPointerDetector(
                      onDoubleDown: onBlankDoubleDown,
                      onSecondaryClick: onBlankSecondaryClick,
                      child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: onEdgeLayerTap,
                      // HI-15：连线层独立 layer，节点局部动画不连带边层重绘。
                      // 拖拽位移/自定义连线色在此窄域 watch——每帧只重绘本层。
                      child: StageEdgeLayer(
                        canvasId: canvasId,
                        edges: edges,
                        lineage: lineage,
                        visibleNodes: visibleNodes,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                        selectedEdgeId: selectedEdgeId,
                      ),
                    ),
                    ),
                  ),
                  // 无道节点：全局变换直出。
                  // HI-13/HI-15：拖拽位移在 NodeCard 内部局部累积，落点一次性
                  // 提交 moveNode；选中/链接态下沉到 NodeCardSlot 各自 watch，
                  // RepaintBoundary 把拖拽/重绘隔离在本卡片 layer。
                  for (final node in freeNodes)
                    Positioned(
                      key: ValueKey('node-card-${node.id}'),
                      left: node.position.dx + kStageOrigin.dx,
                      top: node.position.dy + kStageOrigin.dy,
                      child: NodeCardSlot(
                        node: node,
                        canvasId: canvasId,
                        lanes: lanes,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                        hasInEdge: ports.inbound.contains(node.id),
                        hasOutEdge: ports.outbound.contains(node.id),
                        onTap: () => onNodeTap(node),
                        onSecondaryClick: (Offset p) => onNodeSecondaryClick(node, p),
                        onWireDrop: onWireDrop,
                        onDelete: () => deleteNodeWithUndo(
                          context,
                          ref,
                          canvasId: canvasId,
                          nodeId: node.id,
                        ),
                      ),
                    ),
                  // 分道位移组：每条泳道一个 Transform.translate——以泳道起始边
                  // 为锚缩放，保证泳道内的卡片缩放/平移时不穿出泳道带。
                  // VLB 的 child 只建一次，缩放帧只更新 Transform（不重建卡片）。
                  // 折叠的道不建卡片（稿：折叠收成 36 轨，道内内容隐藏）。
                  for (final lane in lanes)
                    if (!collapsedIds.contains(lane.id))
                    Positioned.fill(
                      key: ValueKey('lane-group-${lane.id}'),
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: transformController,
                        builder: (context, m, child) {
                          final horizontal =
                              direction == LaneDirection.horizontal;
                          // lane-stack 空间锚定：无平移项（泳道栈随平移整体走）。
                          final d = lanePinDisplacement(
                            laneStart: laneStarts[lane.id]!,
                            scale: scaleOf(m),
                            crossTranslation: 0,
                          );
                          return Transform.translate(
                            offset:
                                horizontal ? Offset(0, d) : Offset(d, 0),
                            child: child,
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final node in nodes)
                              if (node.laneId == lane.id)
                                Positioned(
                                  key: ValueKey('node-card-${node.id}'),
                                  left: node.position.dx + kStageOrigin.dx,
                                  top: node.position.dy + kStageOrigin.dy,
                                  child: NodeCardSlot(
                                    node: node,
                                    lane: lane,
                                    canvasId: canvasId,
                                    lanes: lanes,
                                    laneSlices: laneSlices,
                                    direction: direction,
                                    transform: transformController,
                                    hasInEdge: ports.inbound.contains(node.id),
                                    hasOutEdge:
                                        ports.outbound.contains(node.id),
                                    onTap: () => onNodeTap(node),
                                    onSecondaryClick: (Offset p) =>
                                        onNodeSecondaryClick(node, p),
                                    onWireDrop: onWireDrop,
                                    onDelete: () => deleteNodeWithUndo(
                                      context,
                                      ref,
                                      canvasId: canvasId,
                                      nodeId: node.id,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  if (selectedGeometry != null)
                    // 删除按钮锚在连线中点：中点取渲染位置（含分道位移），
                    // 缩放/平移实时跟随。
                    Positioned.fill(
                      child: StageEdgeDeleteOverlay(
                        canvasId: canvasId,
                        geometry: selectedGeometry,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                      ),
                    ),
                  // 拖线中的实时虚线：画在卡片之上（拖过别的卡片时线不被压住），不收指针。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: PendingWireLayer(
                        canvasId: canvasId,
                        nodes: visibleNodes,
                        laneSlices: laneSlices,
                        direction: direction,
                        transform: transformController,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            ),
                  ),
                ),
              ),
              // 泳道标题栏 + 分界线拖拽条：视口层、随泳道栈同偏移平移。
              // 感应条必须压在标题栏之上——标题栏横跨整条泳道顶部，若反过来
              // 会盖住感应条下半段，边界拖拽十有八九落在标题栏上（宽度调不动）。
              // 平移生效时这一层同样不收指针：拖到标题栏 / 感应条上也是拖画布。
              if (lanes.isNotEmpty)
                Positioned.fill(
                  child: StagePanGate(
                    canvasId: canvasId,
                    child: laneShifted(
                    StageLaneLayer(
                      canvasId: canvasId,
                      lanes: lanes,
                      laneSlices: laneSlices,
                      nodes: nodes,
                      direction: direction,
                      collapsedIds: collapsedIds,
                      viewport: size,
                    ),
                  ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
