// 泳道动作：要 BuildContext（撤销卡、确认框）的两件事，标题栏解散键与泳道右键菜单共用同一个函数。
//
//   - 解散泳道（节点留下，dissolveLaneWithUndo）：不确认。道没了，道里的卡屏幕上原地不动、变成道外节点
//     （位置换算见 lane_dissolve.dart 的 dissolvedPositions）；折叠中的道按展开厚度算，解散后从折叠集合里
//     拿掉；右下角出 8 秒撤销卡。
//   - 删除泳道和内容（deleteLaneWithContentsWithUndo）：道 + 道内节点 + 它们的边一个事务软删，撤销卡。
//     唯一要确认的情形：道内有生成中的任务——取消任务撤不回来，先问；确认后先取消任务、再删。
//
// 【await 之后不碰 context / ref】解散的是最后一条道时，舞台骨架只在有泳道时挂着泳道层，道一消失
// 标题栏连同它的 context / WidgetRef 一起被拆掉。所以通知服务、文案、控制器在第一个 await 之前一次取齐，
// 出卡一律走 showUndoToast(toasts, …) / toasts.show(…)，不用按 context 现取的 showCanvasUndoSnack。
//
// 两项都**不**登记撤销栈（canvasHistoryControllerProvider），只出带回调的撤销卡。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/job_queue.dart';
import '../../../core/di/logger.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/job_queue_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../core/logging/logger_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/lane_collapse_controller.dart';
import '../providers/selected_edge_controller.dart';
import 'canvas_snackbars.dart';
import 'canvas_zoom.dart';
import 'lane_dissolve.dart';
import 'lane_geometry.dart';

const String _logModule = 'canvas.lanes';

/// 解散泳道（节点留下）：不弹任何对话框，解散后出撤销卡「已解散泳道「名」」，点撤销 ⇒ 道回到原下标、
/// 卡片回到道里原处。失败 ⇒ 错误卡「解散泳道失败」；撤销失败 ⇒「撤销失败」。
Future<void> dissolveLaneWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required StyleLane lane,
}) async {
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
  final List<StyleLane> lanes =
      ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ?? const <StyleLane>[];
  final Map<String, Offset> positions = dissolvedPositions(
    laneNodes: nodes,
    laneId: lane.id,
    lanes: lanes,
    collapsed: ref.read(laneCollapseProvider(canvasId)),
    direction:
        ref.read(canvasLaneDirectionProvider(canvasId)).valueOrNull ?? LaneDirection.horizontal,
    scale: scaleOf(ref.read(canvasTransformControllerProvider(canvasId)).value),
  );
  // 第一个 await 之前取齐（见文件头）。
  final ToastService toasts = ref.read(toastServiceProvider);
  final AppLocalizations l = context.l10n;
  final CanvasLanesController controller =
      ref.read(canvasLanesControllerProvider(canvasId).notifier);
  final LaneCollapseController collapse = ref.read(laneCollapseProvider(canvasId).notifier);

  final LaneDissolution? token = await _orFailToast(
    () => controller.dissolveLane(lane.id, positions: positions),
    toasts,
    l.laneDissolveFailed,
  );
  if (token == null) return;
  if (collapse.isCollapsed(lane.id)) collapse.toggle(lane.id);
  showUndoToast(
    toasts,
    message: l.laneDissolved(_laneName(l, token.lane)),
    undoLabel: l.commonUndo,
    onUndo: () => _runUndo(() => controller.restoreDissolved(token), toasts, l.undoFailed),
  );
}

/// 删除泳道和内容：道内没有生成中的任务 ⇒ 直接删 + 撤销卡；有 ⇒ 先确认（写出任务数），取消 ⇒ 什么都不动，
/// 确认 ⇒ 逐个取消任务（单个取消失败记日志、继续）再删。删完把被删节点从选中集里去掉，选中的边被删了就清。
/// 失败 ⇒ 错误卡「删除泳道失败」；撤销失败 ⇒「撤销失败」。被取消的任务不随撤销复原。
Future<void> deleteLaneWithContentsWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required StyleLane lane,
}) async {
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
  // 生成中的任务按内存里的道内节点判（主 Agent 决定 3）。
  final List<JobState> active = activeJobsInLane(
    canvasId: canvasId,
    laneNodeIds: <String>{
      for (final CanvasNode n in nodes)
        if (n.laneId == lane.id) n.id,
    },
    jobs: ref.read(jobsRegistryProvider),
  );
  // 第一个 await（确认框）之前取齐（见文件头）。
  final ToastService toasts = ref.read(toastServiceProvider);
  final AppLocalizations l = context.l10n;
  final CanvasLanesController controller =
      ref.read(canvasLanesControllerProvider(canvasId).notifier);
  final CanvasSelectionController selection =
      ref.read(canvasSelectionControllerProvider(canvasId).notifier);
  final SelectedEdgeController edgeSelection =
      ref.read(selectedEdgeControllerProvider(canvasId).notifier);
  final String? selectedEdge = ref.read(selectedEdgeControllerProvider(canvasId));
  final LoggerService logger = ref.read(loggerProvider);
  final Future<JobQueueService>? queueFuture =
      active.isEmpty ? null : ref.read(jobQueueServiceProvider.future);
  final String name = _laneName(l, lane);

  if (queueFuture != null) {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.laneDeleteRunningTitle(name)),
        content: Text(l.laneDeleteRunningBody(active.length)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.laneDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.laneDeleteRunningConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final JobQueueService queue = await queueFuture;
    for (final JobState job in active) {
      try {
        await queue.cancel(job.jobId);
      } on InkError catch (e) {
        logger.warn(
          _logModule,
          'cancel job before lane delete failed',
          extra: <String, Object?>{'job_id': job.jobId, 'code': e.code.wire},
        );
      }
    }
  }

  final LaneContentsDeletion? token = await _orFailToast(
    () => controller.deleteLaneWithContents(lane.id),
    toasts,
    l.laneDeleteFailed,
  );
  if (token == null) return;
  selection.removeAll(token.nodeIds);
  if (selectedEdge != null && token.edgeIds.contains(selectedEdge)) edgeSelection.clear();
  showUndoToast(
    toasts,
    message: l.laneDeletedWithContents(token.nodeIds.length, _laneName(l, token.lane)),
    undoLabel: l.commonUndo,
    onUndo: () => _runUndo(() => controller.restoreLaneContents(token), toasts, l.undoFailed),
  );
}

String _laneName(AppLocalizations l, StyleLane lane) =>
    lane.label.isEmpty ? l.laneUntitled : lane.label;

/// 跑 [op]；抛 InkError ⇒ 出错误卡 [failed]、返回 null（与「什么都没做」同一出口）。
Future<T?> _orFailToast<T>(
  Future<T?> Function() op,
  ToastService toasts,
  String failed,
) async {
  try {
    return await op();
  } on InkError catch (_) {
    toasts.show(failed, kind: ToastKind.error);
    return null;
  }
}

/// 撤销卡的回调：后台跑 [undo]，抛 InkError ⇒ 出错误卡 [undoFailed]。
void _runUndo(Future<void> Function() undo, ToastService toasts, String undoFailed) {
  unawaited(() async {
    try {
      await undo();
    } on InkError catch (_) {
      toasts.show(undoFailed, kind: ToastKind.error);
    }
  }());
}
