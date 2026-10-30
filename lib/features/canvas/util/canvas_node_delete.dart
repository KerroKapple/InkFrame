// 节点删除防误伤（PL-4a 语义，单一删除路径）：节点卡片删除按钮、Delete 快捷键、节点右键菜单、⌘K 共用。
//
// 删除做成之后进画布撤销栈（models/commands/delete_nodes_command.dart，「删除 N 个节点」，连带它们的线），
// 再弹一张撤销卡：卡片只是提醒、栈才是本体——卡 8 秒收起后 Ctrl Z / ⌘Z 照样撤，卡上「撤销」只撤卡上这一步。
// 撤销之后的选中 / 平移 / 胶囊 / 失败卡由执行口（canvas_history_actions.dart）统一出，与 Ctrl Z 同一套。
//
// 单选：removeNode ⇒ 记一步 + 「Node deleted · Undo」；没有令牌（节点不在内存）只出 info 卡、不进栈；
//       失败只出「删除节点失败」、不进栈。
// 多选：一次事务整批删除（removeNodes）——要么全删掉、记一步弹一张「N nodes deleted · Undo」，
//       要么一张都不删、只出「删除节点失败」、不进栈。
//
// 容器与文案在第一个 await 之前取齐，await 之后不碰 context / ref：删除钮、右键菜单这些调用点写库回来时
// 可能已卸载，而步已经做成了——以 context.mounted 为前提会连卡带步一起丢，成了撤不回的删除。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/commands/delete_nodes_command.dart';
import '../providers/canvas_history_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import 'canvas_snackbars.dart';

/// 删除单个节点，进撤销栈并弹出「Node deleted · Undo」。
Future<void> deleteNodeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String nodeId,
}) async {
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final AppLocalizations l = context.l10n;
  ref.read(canvasSelectionControllerProvider(canvasId).notifier).removed(nodeId);
  final nodesCtrl = ref.read(canvasNodesControllerProvider(canvasId).notifier);
  try {
    final deletion = await nodesCtrl.removeNode(nodeId);
    if (deletion == null) {
      // 没有撤销令牌（节点不在内存）：只是告知已删，不是失败，也没有可撤的步。
      container.read(toastServiceProvider).show(l.nodeDeleted, kind: ToastKind.info);
      return;
    }
    final String stepId = container
        .read(canvasHistoryControllerProvider(canvasId).notifier)
        .record(DeleteNodesCommand(<NodeDeletion>[deletion]));
    showCanvasUndoSnackWith(
      container,
      l,
      message: l.nodeDeleted,
      canvasId: canvasId,
      stepId: stepId,
    );
  } on InkError catch (_) {
    container.read(toastServiceProvider).show(l.nodeDeleteFailed, kind: ToastKind.error);
  }
}

/// 删除当前选中的一个或多个节点。单选下沉到 [deleteNodeWithUndo]（PL-4a 不回归）；
/// 多选一次事务整批删除后记一步、弹一张批量撤销卡；失败一张不删，只出失败卡、不进栈、没有撤销卡。
Future<void> deleteNodesWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required Set<String> nodeIds,
}) async {
  if (nodeIds.isEmpty) return;
  if (nodeIds.length == 1) {
    return deleteNodeWithUndo(
      context,
      ref,
      canvasId: canvasId,
      nodeId: nodeIds.first,
    );
  }
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final AppLocalizations l = context.l10n;
  final selectionCtrl = ref.read(canvasSelectionControllerProvider(canvasId).notifier);
  final nodesCtrl = ref.read(canvasNodesControllerProvider(canvasId).notifier);
  // 删前一次性移出选中；失败不恢复选中（维持现状）。
  selectionCtrl.removeAll(nodeIds);
  try {
    final deletions = await nodesCtrl.removeNodes(nodeIds);
    if (deletions.isEmpty) return;
    final String stepId = container
        .read(canvasHistoryControllerProvider(canvasId).notifier)
        .record(DeleteNodesCommand(deletions));
    showCanvasUndoSnackWith(
      container,
      l,
      message: l.nodesDeleted(deletions.length),
      canvasId: canvasId,
      stepId: stepId,
    );
  } on InkError catch (_) {
    // 整批回滚：一张都没删，只告知失败，不进栈、不出撤销卡。
    container.read(toastServiceProvider).show(l.nodeDeleteFailed, kind: ToastKind.error);
  }
}
