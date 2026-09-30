// 从外壳打开导出对话框的唯一路径：导出标签、序列标签的「导出 mp4」都走这里。
//
// EX-1′：默认序是 narrative 链序，需要全量节点 + 边（result 节点自己不在链上，挂在 config 节点下）。
// projectId 走外壳的项目上下文，不从 videoNodes.first.projectId 摸（spec §8.2 / BOARD 210）：
// 启用判据与 projectId 来源同源——外壳没有项目上下文就不弹。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/models/canvas_edge.dart';
import '../canvas/models/canvas_node.dart';
import '../canvas/providers/canvas_edges_controller.dart';
import '../canvas/providers/canvas_nodes_controller.dart';
import '../shell/providers/shell_controller.dart';
import 'util/export_order.dart';
import 'widgets/export_video_dialog.dart';

void openExportVideoDialogForCanvas(BuildContext context, WidgetRef ref, String canvasId) {
  final videoNodes = orderVideoNodesForExport(
    allNodes: ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[],
    edges: ref.read(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[],
  );
  if (videoNodes.isEmpty) return; // 按压瞬间节点已变化：静默不弹
  final projectId = ref.read(shellControllerProvider).project?.id;
  if (projectId == null) return; // 外壳尚无项目上下文：静默不弹
  showExportVideoDialog(context, projectId: projectId, videoNodes: videoNodes);
}
