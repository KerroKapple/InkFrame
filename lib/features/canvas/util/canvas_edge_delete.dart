// 删一条连线并进画布撤销栈：舞台上选中线的 ✕（widgets/stage/stage_edge_layer.dart）与检查器入边区的
// 「移除」（widgets/node_inputs_section.dart）共用这一条路。
//
// 成功 ⇒ record 一步「删除连线」（DeleteEdgeCommand，反向按两端找边）+ 撤销卡「Link deleted · 撤销」——
// 卡片只是提醒，收起后 Ctrl Z / ⌘Z 仍能撤，卡上「撤销」只撤这一步；removeEdge 返回 null（边不在内存）⇒
// 什么都不做；失败（InkError）⇒ 控制器已回滚内存、线冒回来，出「删除连线失败」——不说一声，用户只看到
// 「删掉的线又回来了」。
//
// 同步段（第一个 await 之前）取齐容器、文案、边控制器，await 之后**不再碰 context / ref**：两个调用点在写库
// 回来时都已卸载——舞台删除钮那层清选中后下一帧就拆，检查器入边行在边从列表里乐观拿掉时就拆。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/canvas_edge.dart';
import '../models/commands/delete_edge_command.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_history_controller.dart';
import '../providers/selected_edge_controller.dart';
import 'canvas_snackbars.dart';

/// 删除 [edgeId] 并进撤销栈（见头注）。选中的正是这条线 ⇒ 先清掉选中。
Future<void> deleteEdgeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String edgeId,
}) async {
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final AppLocalizations l = context.l10n;
  final CanvasEdgesController edgesCtrl =
      ref.read(canvasEdgesControllerProvider(canvasId).notifier);
  if (ref.read(selectedEdgeControllerProvider(canvasId)) == edgeId) {
    ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
  }
  try {
    final CanvasEdge? removed = await edgesCtrl.removeEdge(edgeId);
    if (removed == null) return;
    final String stepId = container
        .read(canvasHistoryControllerProvider(canvasId).notifier)
        .record(DeleteEdgeCommand(removed));
    showCanvasUndoSnackWith(
      container,
      l,
      message: l.edgeDeleted,
      canvasId: canvasId,
      stepId: stepId,
    );
  } on InkError catch (_) {
    container
        .read(toastServiceProvider)
        .show(l.edgeDeleteFailed, kind: ToastKind.error);
  }
}
