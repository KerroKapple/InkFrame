// EX-1′：导出对话框的默认排序 = narrative 链序。
//
// 旧行为是按 position.x 升序（"分镜从左到右"）。那在用户规规矩矩横排时对，
// 一旦画布纵向分支或重排就错——而叙事顺序早就用 narrative 边显式表达了。
//
// 为什么不能把 video result 节点直接丢给 orderByNarrativeChain：result 节点挂
// 在 config/shot 节点下（sourceNodeId），**自己不在 narrative 链上**。按 result
// 集合建链一条边都找不到，排序会静默退化成 position.x——看起来"能跑"，实际
// 这张卡等于没做。正确路径是先按链排 config/shot 节点，再经 artifacts util
// 映射到各自最新产物。

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/narrative_order.dart';
import '../../canvas/util/node_artifacts.dart';

/// 顶栏入口 / 命令面板 / 对话框共用的过滤：role==result、type==video、
/// videoUrl 非空、canvasId 非空——与 `ExportController.export` 的输入条件一致，
/// 消除「列表可见但导出时静默丢弃」的错位。
List<CanvasNode> exportableVideoNodes(List<CanvasNode> nodes) => <CanvasNode>[
      for (final n in nodes)
        if (n.role == NodeRole.result &&
            n.type == CanvasNodeType.video &&
            n.videoUrl != null &&
            n.canvasId != null)
          n,
    ];

/// 按 narrative 链序给可导出的 video result 节点排序。
///
/// - 链上每个节点吐出它名下**全部** video 产物，新→旧成组
/// - 链外的产物（源节点不在链上、或源节点已删）按 position.x 追加在后面
/// - 画布没有任何 narrative 边时，结果等价于旧的 position.x 升序
///
/// **只改顺序，不改候选集**：同一镜重跑多次产生的旧 take 照样列出（默认全选
/// 因此仍会重复导出该镜——这是本卡之前就有的行为）。把默认选中收窄为「每镜
/// 只选最新 take」是产品行为变更，超出本卡「默认序」范围，另记 BOARD 债。
List<CanvasNode> orderVideoNodesForExport({
  required List<CanvasNode> allNodes,
  required List<CanvasEdge> edges,
}) {
  final exportable = exportableVideoNodes(allNodes);
  if (exportable.isEmpty) return const <CanvasNode>[];

  final chain = orderByNarrativeChain(nodes: allNodes, edges: edges);

  final ordered = <CanvasNode>[];
  final taken = <String>{};
  for (final node in chain) {
    for (final artifact in resultsFor(sourceNodeId: node.id, nodes: exportable)) {
      if (!taken.add(artifact.id)) continue;
      ordered.add(artifact);
    }
  }

  // 够不到的产物不能丢——少一条就是导出少一镜。按 position.x 追加。
  final rest = [
    for (final n in exportable)
      if (!taken.contains(n.id)) n,
  ]..sort((a, b) {
      final byX = a.position.dx.compareTo(b.position.dx);
      return byX != 0 ? byX : a.id.compareTo(b.id);
    });

  return ordered..addAll(rest);
}
