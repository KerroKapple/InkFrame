// 舞台的连线层（从 canvas_view.dart 原样搬出）：
//   - StageEdgeLayer：连线绘制（存量边 + 产出线，EdgePainter）；外面的空白处指针探测与点选命中留在舞台骨架里
//   - StageEdgeDeleteOverlay：选中边中点的删除钮 + 删边 / 撤销提示（「有没有选中边」的判断留在骨架）
//   - selectedEdgeGeometry：选中边及其两端节点
//   - EdgeLaneErrorSlot：边 / 泳道 / 泳道方向加载失败的非阻塞横幅
//   - PendingWireLayer：从出端口拖线途中的实时虚线

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/canvas_style.dart';
import '../../../../core/errors/ink_error.dart';
import '../../../../core/interfaces/toast_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_error_banner.dart';
import '../../../../theme/tokens.dart';
import '../../../notifications/providers/toast_service_provider.dart';
import '../../models/canvas_edge.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_edges_controller.dart';
import '../../providers/canvas_lanes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/node_drag_delta.dart';
import '../../providers/selected_edge_controller.dart';
import '../../util/canvas_snackbars.dart';
import '../../util/edge_hit_test.dart';
import '../../util/edge_style.dart';
import '../../util/lane_geometry.dart';
import '../../util/lane_pin_geometry.dart';
import '../../util/lineage_edges.dart';
import '../create_node_menu.dart';
import '../edge_painter.dart';

/// 连线绘制层：存量边 + 产出线。HI-15：独立 layer（RepaintBoundary），节点局部动画不连带边层重绘；
/// 拖拽位移 / 自定义连线色 / 选中集在本层的 Consumer 里窄域 watch——每帧只重绘本层。
/// 边、产出线、可见节点、选中边由舞台骨架 watch / 整层算一次后传进来。
class StageEdgeLayer extends StatelessWidget {
  const StageEdgeLayer({
    super.key,
    required this.canvasId,
    required this.edges,
    required this.lineage,
    required this.visibleNodes,
    required this.laneSlices,
    required this.direction,
    required this.transform,
    required this.selectedEdgeId,
  });

  final String canvasId;
  final List<CanvasEdge> edges;
  final List<LineageEdge> lineage;

  /// 可见节点（折叠道里的不在内）：连线只在它们之间画。
  final List<CanvasNode> visibleNodes;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final TransformationController transform;
  final String? selectedEdgeId;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final transformController = transform;
    return RepaintBoundary(
      child: Consumer(
        builder: (context, ref, _) {
          final drag = ref.watch(nodeDragDeltaProvider);
          final style =
              ref.watch(canvasStyleControllerProvider);
          final typo = context.inkTypography;
          final l = context.l10n;
          final selectedNodeIds = ref.watch(
            canvasSelectionControllerProvider(canvasId),
          );
          // 连线语义色（画布重设计稿）：叙事 fg4、产出 fg6、首帧 /
          // 尾帧 / 参考各一色；当前链路仍是用户自定义连线色，没设
          // 就是 accent。标签胶囊底 = 画布底色。
          final palette = EdgePalette(
            narrative: colors.fg4,
            lineage: colors.fg6,
            firstFrame: colors.edgeFirstFrame,
            lastFrame: colors.edgeLastFrame,
            reference: colors.edgeReference,
            accent: style.edgeColor ?? colors.accent,
            chipFill: colors.surface1,
          );
          // 锚点吃分道位移（与卡片渲染位置同源），缩放/平移
          // 实时跟随。
          return ValueListenableBuilder<Matrix4>(
            valueListenable: transformController,
            builder: (context, m, _) => CustomPaint(
              painter: EdgePainter(
                edges: edges,
                lineage: lineage,
                nodes: displacedNodes(
                  nodes: visibleNodes,
                  lanes: laneSlices,
                  direction: direction,
                  transform: m,
                ),
                palette: palette,
                labelStyle: typo.micro,
                firstFrameLabel: l.inspectorRoleFirstFrame,
                lastFrameLabel: l.inspectorRoleLastFrame,
                referenceLabel: l.canvasEdgeLabelReference,
                direction: direction,
                selectedNodeIds: selectedNodeIds,
                selectedEdgeId: selectedEdgeId,
                dragNodeId: drag?.nodeId,
                dragDelta: drag?.delta ?? Offset.zero,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 选中边的删除钮：锚在连线中点，中点取渲染位置（含分道位移），缩放/平移实时跟随。
class StageEdgeDeleteOverlay extends ConsumerWidget {
  const StageEdgeDeleteOverlay({
    super.key,
    required this.canvasId,
    required this.geometry,
    required this.laneSlices,
    required this.direction,
    required this.transform,
  });

  final String canvasId;
  final ({CanvasEdge edge, CanvasNode source, CanvasNode target}) geometry;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final TransformationController transform;

  /// 本层只在有选中边时挂着：下面第一步清选中（删边时连线也先从内存里拿掉），舞台骨架下一帧就把本层拆了，
  /// 写库往往比下一帧慢——等它回来，本层的 context / ref 早已失效。原来挂在舞台层上时没有这个问题，
  /// 搬出来之后提示要用的东西（文案、通知服务）在清选中之前取齐，同 NodeCardSlot._commitDrag。
  Future<void> _handleEdgeDelete(
    BuildContext context,
    WidgetRef ref,
    CanvasEdge edge,
  ) async {
    final AppLocalizations l = context.l10n;
    final ToastService toasts = ref.read(toastServiceProvider);
    ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
    final edgesCtrl = ref.read(
      canvasEdgesControllerProvider(canvasId).notifier,
    );
    try {
      final removed = await edgesCtrl.removeEdge(edge.id);
      if (removed == null) return;
      // 撤销卡，主按钮「撤销」复原；通知服务与文案都是 await 之前取好的。
      showUndoToast(
        toasts,
        message: l.edgeDeleted,
        undoLabel: l.commonUndo,
        onUndo: () => _restoreEdge(toasts, l, edgesCtrl, removed),
      );
    } on InkError catch (_) {
      // 删失败：EdgesController 已回滚内存，SelectedEdge 已清。回滚让连线**冒回来**，
      // 可那只是现象——不说一声，用户只看到「删掉的线又回来了」，不知道是没删成。
      // 删节点 / 删泳道失败都有提示，删连线原来是唯一不说的那个。
      toasts.show(l.edgeDeleteFailed, kind: ToastKind.error);
    }
  }

  Future<void> _restoreEdge(
    ToastService toasts,
    AppLocalizations l,
    CanvasEdgesController ctrl,
    CanvasEdge edge,
  ) async {
    try {
      await ctrl.restore(edge);
    } on InkError catch (_) {
      toasts.show(l.undoFailed, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGeometry = geometry;
    final transformController = transform;
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transformController,
      builder: (context, m, _) {
        final drawn = displacedNodes(
          nodes: [
            selectedGeometry.source,
            selectedGeometry.target,
          ],
          lanes: laneSlices,
          direction: direction,
          transform: m,
        );
        final mid = edgeMidpoint(
          source: drawn[0],
          target: drawn[1],
          direction: direction,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: mid.dx - 14,
              top: mid.dy - 14,
              child: _EdgeDeleteButton(
                onPressed: () => _handleEdgeDelete(
                  context,
                  ref,
                  selectedGeometry.edge,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgeDeleteButton extends StatelessWidget {
  const _EdgeDeleteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Material(
      color: colors.surface1,
      shape: CircleBorder(side: BorderSide(color: colors.danger, width: 1.5)),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.close, size: 16, color: colors.danger),
        ),
      ),
    );
  }
}

/// 在 [edges]/[nodes] 中定位选中边及其端点节点；任一缺失返回 null。
({CanvasEdge edge, CanvasNode source, CanvasNode target})?
selectedEdgeGeometry({
  required String? selectedEdgeId,
  required List<CanvasEdge> edges,
  required List<CanvasNode> nodes,
}) {
  if (selectedEdgeId == null) return null;
  CanvasEdge? edge;
  for (final e in edges) {
    if (e.id == selectedEdgeId) {
      edge = e;
      break;
    }
  }
  if (edge == null) return null;
  CanvasNode? source;
  CanvasNode? target;
  for (final n in nodes) {
    if (n.id == edge.sourceNodeId) source = n;
    if (n.id == edge.targetNodeId) target = n;
  }
  if (source == null || target == null) return null;
  return (edge: edge, source: source, target: target);
}

/// 画布元数据（边/泳道/泳道方向）加载失败横幅插槽：非阻塞——节点已在
/// _CanvasStage 用 valueOrNull 降级照常渲染，这里仅补一条可忽略的错误横幅
/// 解释失败原因（此前静默吞错）。GAP-3 余量：方向读失败此前完全无提示；
/// lane_toolbar 会基于错误基线 horizontal 翻转写库（二元域下写入值仍在
/// 存量/意图之内,无损毁,但错误期 toggle 永远到不了 horizontal——置灰记债）。
class EdgeLaneErrorSlot extends ConsumerStatefulWidget {
  const EdgeLaneErrorSlot({super.key, required this.canvasId});

  final String canvasId;

  @override
  ConsumerState<EdgeLaneErrorSlot> createState() => _EdgeLaneErrorSlotState();
}

class _EdgeLaneErrorSlotState extends ConsumerState<EdgeLaneErrorSlot> {
  /// 每个错误源各记一条「已被用户忽略的那个错误对象」，顺序同 [_errorsOf]。
  ///
  /// 【为什么不能是一个字段】三个源会同时有错。原来是单个 `_dismissed` 配上
  /// `edgesError ?? lanesError ?? directionError`：关掉 edges 的错之后，只要它
  /// 还没恢复，`??` 链就一直短路在它身上，而它恰好 `identical` 于 `_dismissed`
  /// ⇒ 这期间并发出现的 lanes / direction 错**永远上不了屏**。按源分别记账、
  /// 取第一个「有错且未被忽略」的，才是三个源各自独立的语义。
  ///
  /// 定长三格而不是不断增长的集合：忽略只对「当下这个错误对象」生效，源一恢复
  /// 旧对象就再也不会出现，留着只是攒垃圾。
  final List<Object?> _dismissed = <Object?>[null, null, null];

  List<Object?> _errorsOf(WidgetRef ref) => <Object?>[
        ref.watch(canvasEdgesControllerProvider(widget.canvasId)).error,
        ref.watch(canvasLanesControllerProvider(widget.canvasId)).error,
        ref.watch(canvasLaneDirectionProvider(widget.canvasId)).error,
      ];

  @override
  Widget build(BuildContext context) {
    final List<Object?> errors = _errorsOf(ref);
    int? at;
    for (var i = 0; i < errors.length; i++) {
      final Object? e = errors[i];
      if (e != null && !identical(e, _dismissed[i])) {
        at = i;
        break;
      }
    }
    if (at == null) return const SizedBox.shrink();
    final int source = at;
    final Object error = errors[source]!;
    final colors = context.inkColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkErrorBanner(message: l10nAsyncError(context, error)),
        ),
        const SizedBox(width: InkSpacing.xs),
        IconButton(
          tooltip: context.l10n.commonClose,
          icon: Icon(Icons.close, size: InkSpacing.md, color: colors.danger),
          onPressed: () => setState(() => _dismissed[source] = error),
        ),
      ],
    );
  }
}

/// 拖线中的实时虚线（从源卡片的出点到指针）：只随拖线状态与相机重建，不连带舞台；不在拖线时什么都不画。
class PendingWireLayer extends ConsumerWidget {
  const PendingWireLayer({
    super.key,
    required this.canvasId,
    required this.nodes,
    required this.laneSlices,
    required this.direction,
    required this.transform,
  });

  final String canvasId;

  /// 可见节点（折叠道里的不在内）：源卡片画在哪，线就从哪出。
  final List<CanvasNode> nodes;
  final List<({String id, double size})> laneSlices;
  final LaneDirection direction;
  final TransformationController transform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WireDrag? drag = ref.watch(canvasWireDragProvider(canvasId));
    if (drag == null) return const SizedBox.shrink();
    CanvasNode? source;
    for (final CanvasNode n in nodes) {
      if (n.id == drag.sourceNodeId) source = n;
    }
    final CanvasNode? from = source;
    if (from == null) return const SizedBox.shrink();
    final Color color = context.inkColors.accent;
    // 出点吃分道位移（与卡片渲染位置同源），缩放时跟着走。
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transform,
      builder: (BuildContext context, Matrix4 m, Widget? _) => CustomPaint(
        painter: PendingWirePainter(
          source: displacedNodes(
            nodes: <CanvasNode>[from],
            lanes: laneSlices,
            direction: direction,
            transform: m,
          ).single,
          to: drag.pointer,
          color: color,
          direction: direction,
        ),
      ),
    );
  }
}
