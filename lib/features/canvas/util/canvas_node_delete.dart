// 节点删除防误伤（PL-4a 语义，单一删除路径）：节点卡片删除按钮与 Delete 快捷键共用。
//
// 单选：走单节点「Node deleted · Undo」，与 PL-4a 完全一致，不回归。
// 多选：逐个删除并弹一条「N nodes deleted · Undo」；Undo 一次性复原全部
//       （每个删除的撤销令牌都逐节点保留，不丢弃撤销入口）。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import 'canvas_snackbars.dart';

/// 删除单个节点并弹出「Node deleted · Undo」。
Future<void> deleteNodeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String nodeId,
}) async {
  ref.read(canvasSelectionControllerProvider.notifier).removed(nodeId);
  final nodesCtrl = ref.read(canvasNodesControllerProvider(canvasId).notifier);
  try {
    final deletion = await nodesCtrl.removeNode(nodeId);
    if (!context.mounted) return;
    if (deletion == null) {
      showCanvasSnack(context, context.l10n.nodeDeleted);
      return;
    }
    showCanvasUndoSnack(
      context,
      message: context.l10n.nodeDeleted,
      onUndo: () => _restore(context, nodesCtrl, <NodeDeletion>[deletion]),
    );
  } on InkError catch (_) {
    if (context.mounted) {
      showCanvasSnack(context, context.l10n.nodeDeleteFailed);
    }
  }
}

/// 删除当前选中的一个或多个节点。单选下沉到 [deleteNodeWithUndo]（PL-4a 不回归）；
/// 多选逐个删除后弹一条批量撤销 snackbar。
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
  final selectionCtrl = ref.read(canvasSelectionControllerProvider.notifier);
  final nodesCtrl = ref.read(canvasNodesControllerProvider(canvasId).notifier);
  final deletions = <NodeDeletion>[];
  try {
    for (final id in nodeIds) {
      selectionCtrl.removed(id);
      final deletion = await nodesCtrl.removeNode(id);
      if (deletion != null) deletions.add(deletion);
    }
  } on InkError catch (_) {
    // 中途某个失败：已删的仍逐个可撤销，落到下方批量 snackbar；另提示失败。
    if (context.mounted) {
      showCanvasSnack(context, context.l10n.nodeDeleteFailed);
    }
  }
  if (!context.mounted || deletions.isEmpty) return;
  showCanvasUndoSnack(
    context,
    message: context.l10n.nodesDeleted(deletions.length),
    onUndo: () => _restore(context, nodesCtrl, deletions),
  );
}

/// 逐个复原撤销令牌；任一步失败 → undoFailed 兜底提示。
Future<void> _restore(
  BuildContext context,
  CanvasNodesController ctrl,
  List<NodeDeletion> deletions,
) async {
  try {
    for (final deletion in deletions) {
      await ctrl.restore(deletion);
    }
  } on InkError catch (_) {
    if (context.mounted) showCanvasSnack(context, context.l10n.undoFailed);
  }
}
