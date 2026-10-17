// EdgeEndpoints：按「两端 + 类型」认一条连线——撤销栈反向找边的唯一口径。
//
// 为什么不存边 id：撤销「删线」会重建这条线，重建出来的是新 id；之后再撤销
// 「连线」、再重做……命令里攥着的旧 id 早就不在了。两端 + 类型才是这条线的身份：
// 库上 `uq_edges_live`（source_node_id, target_node_id, edge_type WHERE
// deleted_at IS NULL）保证在世的至多一条。
//
// role 只给复原用、**不参与匹配**：updateRole 改过角色的边仍是「那一条」。
// 需要「上游所属配置节点」级别的找边（tc-take-edge-follow）另写匹配函数，
// 别改这里 [EdgeEndpoints.matches] 的语义。
//
// 手写不可变值对象（同 canvas_edge.dart 写法），== / hashCode 覆盖四个字段。
import 'package:flutter/foundation.dart';

import 'canvas_edge.dart';

@immutable
class EdgeEndpoints {
  const EdgeEndpoints({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.edgeType,
    this.role = EdgeRole.reference,
  });

  /// 从一条现存边拷出它的身份 + 角色（命令做快照时用）。
  static EdgeEndpoints of(CanvasEdge e) => EdgeEndpoints(
        sourceNodeId: e.sourceNodeId,
        targetNodeId: e.targetNodeId,
        edgeType: e.edgeType,
        role: e.role,
      );

  final String sourceNodeId;
  final String targetNodeId;
  final EdgeType edgeType;

  /// 复原时写回的角色；不参与 [matches]。
  final EdgeRole role;

  /// 只比 source / target / edgeType——不比 role、不比 id。
  bool matches(CanvasEdge e) =>
      e.sourceNodeId == sourceNodeId &&
      e.targetNodeId == targetNodeId &&
      e.edgeType == edgeType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeEndpoints &&
          sourceNodeId == other.sourceNodeId &&
          targetNodeId == other.targetNodeId &&
          edgeType == other.edgeType &&
          role == other.role;

  @override
  int get hashCode => Object.hash(sourceNodeId, targetNodeId, edgeType, role);

  @override
  String toString() =>
      'EdgeEndpoints($sourceNodeId -> $targetNodeId, $edgeType, $role)';
}

/// 在 [edges]（调用方传在世的边，比如画布边控制器的当前列表）里找两端 + 类型
/// 与 [k] 相同的那一条；没有 ⇒ null。
CanvasEdge? findEdgeByEndpoints(Iterable<CanvasEdge> edges, EdgeEndpoints k) {
  for (final CanvasEdge e in edges) {
    if (k.matches(e)) return e;
  }
  return null;
}
