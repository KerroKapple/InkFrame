// SB-5：narrative 链排序——E1 序列预览（SB-6）与 E4 导出（EX-1′）的公共地基。
//
// 画布是自由布局的有向图，但「叙事」是线性的：用户用 narrative 边表达
// 「这一镜之后是那一镜」。序列预览要按这个顺序播，导出要按这个顺序拼接，
// 两处必须得到**同一个**顺序——所以排序逻辑收在这一个纯函数里，不许各写一份。
//
// 输入是任意图（可能有分叉、汇合、环、悬空边、完全孤立的节点），输出必须是
// **确定性全序**：同样的输入永远得到同样的顺序，且输出恰是输入节点的一个排列。
// 少一个节点在导出侧就是少一镜，所以任何形态都不许丢节点——走不通链的一律
// 按 position 追加在后面，而不是被丢弃。

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';

/// 按 narrative 链给 [nodes] 排序。
///
/// 规则：
/// - 只认 `EdgeType.narrative` 边；data / generation_source 边不参与建链。
/// - 两端都能在 [nodes] 里找到的边才算数（悬空边忽略）。
/// - 链头 = 参与 narrative 图且入度为 0 的节点，按 (dx, dy, id) 排。
/// - 从每个链头深度优先前序遍历；同源多出边按 (sortOrder, 边 id) 排。
/// - `visited` 防环、防汇合重复。
/// - 遍历走不到的节点（纯环、孤立节点）按 (dx, dy, id) 追加在末尾。
///
/// [include] 只过滤**输出**，不影响建链——滤掉链中间的节点，两侧仍保持链的
/// 相对序（EX-1′ 只导出 video result 节点即是此用法）。
List<CanvasNode> orderByNarrativeChain({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  bool Function(CanvasNode node)? include,
}) {
  if (nodes.isEmpty) return const <CanvasNode>[];

  final byId = <String, CanvasNode>{for (final n in nodes) n.id: n};

  // 只留 narrative 且两端都在场的边。
  final live = edges
      .where((e) =>
          e.edgeType == EdgeType.narrative &&
          byId.containsKey(e.sourceNodeId) &&
          byId.containsKey(e.targetNodeId))
      .toList();

  final successors = <String, List<CanvasEdge>>{};
  final inDegree = <String, int>{};
  final participating = <String>{};
  for (final e in live) {
    (successors[e.sourceNodeId] ??= <CanvasEdge>[]).add(e);
    inDegree[e.targetNodeId] = (inDegree[e.targetNodeId] ?? 0) + 1;
    participating..add(e.sourceNodeId)..add(e.targetNodeId);
  }
  for (final out in successors.values) {
    out.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
  }

  final heads = participating
      .where((id) => (inDegree[id] ?? 0) == 0)
      .map((id) => byId[id]!)
      .toList()
    ..sort(_byPositionThenId);

  final visited = <String>{};
  final ordered = <CanvasNode>[];

  // 显式栈的深度优先前序——递归在长链上有爆栈风险，且这里不需要回溯状态。
  // visited 在**出栈时**才标记：同一节点可能被两条边先后压栈（菱形汇合），
  // 入栈时标记会让先压的那份在真正访问前就被当成已访问。
  for (final head in heads) {
    final stack = <CanvasNode>[head];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (!visited.add(node.id)) continue;
      ordered.add(node);
      final out = successors[node.id];
      if (out == null) continue;
      // 逆序压栈，弹出时才是 (sortOrder, 边 id) 升序。
      for (final e in out.reversed) {
        if (!visited.contains(e.targetNodeId)) {
          stack.add(byId[e.targetNodeId]!);
        }
      }
    }
  }

  // 遍历走不到的：纯环节点 + 完全不参与 narrative 的孤立节点。
  final rest = nodes.where((n) => !visited.contains(n.id)).toList()
    ..sort(_byPositionThenId);
  ordered.addAll(rest);

  return include == null ? ordered : ordered.where(include).toList();
}

int _byPositionThenId(CanvasNode a, CanvasNode b) {
  final byX = a.position.dx.compareTo(b.position.dx);
  if (byX != 0) return byX;
  final byY = a.position.dy.compareTo(b.position.dy);
  return byY != 0 ? byY : a.id.compareTo(b.id);
}
