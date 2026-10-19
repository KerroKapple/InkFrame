// 叙事链拼接底座——「改叙事边」的纯函数，不碰 widget / provider。
//
// 插入一镜（insertPlan）、删中间一镜前后接上（bridgePlan）、大纲挪位（movePlan /
// siblingReorderPlan）、拖到线上时的让位（makeRoomShifts）、成环判据
// （wouldCreateNarrativeCycle）、撤销（invertSplice）都在这里算成一份 [SplicePlan]，
// 由 `CanvasEdgesController.applySplice` 在一个事务里执行（先软删 → 再改序 → 最后建）。
// 后续的连线菜单「插入节点…」、拖到叙事线上插一镜、删除接上、大纲拖动改序、切线
// 都共用这一套，不各写一套。
//
// 【只认叙事边】链判断一律只看 `EdgeType.narrative`；data / generationSource 不参与
// 入度、出度、后继、成环中的任何一项。
//
// 【加的边不撞唯一索引】库上 `uq_edges_live`（source, target, edge_type WHERE
// deleted_at IS NULL）保证在世的同两端同类型至多一条。所有 plan 构造都经
// [_PlanBuilder]：加的边既不与「删后仍在世」的边重复，彼此之间也不重复。
//
// 【撤销按两端找边】[SpliceUndoToken] 只存 [EdgeEndpoints]，不存边 id——撤销「删线」
// 重建出来的是新 id。找边一律 `key.matches(e)` / `findEdgeByEndpoints`：
// EdgeEndpoints 的 == / hashCode 含 role，拿 key 去 Map 查或用 == 比在世边的快照，
// 改过 role 的边会对不上。
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/edge_endpoints.dart';
import 'create_menu_model.dart' show nextNarrativeSortOrder;
import 'lane_geometry.dart';

/// 拖到叙事线上插一镜时「后移一格」的额外间距：一格 = 卡片主轴尺寸 + 本值。
/// 世界坐标里的布局常量，不是视觉令牌（同 kResultColumnGap）。
const double kSpliceSlotGap = 64;

/// 一条待建的边。
typedef SpliceEdgeSpec = ({
  String sourceNodeId,
  String targetNodeId,
  EdgeType edgeType,
  EdgeRole role,
  int sortOrder,
});

/// 一次拼接要做的三样事：软删哪些边、改哪些边的 sortOrder、建哪些边。
///
/// 手写不可变值对象。执行顺序固定为 删 → 改序 → 建（见 applySplice）：先删才能腾出
/// `uq_edges_live` 的槽位，「删 A→B 再建 A→B」才不撞索引。
@immutable
class SplicePlan {
  const SplicePlan({
    this.removeEdgeIds = const <String>{},
    this.addEdges = const <SpliceEdgeSpec>[],
    this.sortOrders = const <String, int>{},
  });

  final Set<String> removeEdgeIds;
  final List<SpliceEdgeSpec> addEdges;

  /// 边 id → 新 sortOrder。
  final Map<String, int> sortOrders;

  bool get isEmpty =>
      removeEdgeIds.isEmpty && addEdges.isEmpty && sortOrders.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplicePlan &&
          setEquals(removeEdgeIds, other.removeEdgeIds) &&
          listEquals(addEdges, other.addEdges) &&
          mapEquals(sortOrders, other.sortOrders);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(removeEdgeIds),
        Object.hashAll(addEdges),
        Object.hashAllUnordered(
            sortOrders.entries.map((e) => Object.hash(e.key, e.value))),
      );

  @override
  String toString() =>
      'SplicePlan(remove: $removeEdgeIds, add: $addEdges, sortOrders: $sortOrders)';
}

/// 删除接上的结果：[plan] 只含要建的桥接边；[skippedSegments] = 因分叉 / 汇合没接上的段数
/// （文案归调用方）。
typedef BridgePlan = ({SplicePlan plan, int skippedSegments});

/// 一次拼接的撤销令牌：按两端记，不记边 id。
///
/// - [removed]：被软删的边（两端 + 角色）与它原来的 sortOrder——撤销时同两端此刻没有在世边、
///   且两端节点仍在世（见 [invertSplice] 的 aliveNodeIds）就重建；
/// - [added]：新建边的两端——撤销时按两端找在世边删掉；
/// - [previousSortOrders]：被改序的边的两端 → 原 sortOrder。只遍历 entries，不拿 key 查 Map。
@immutable
class SpliceUndoToken {
  const SpliceUndoToken({
    this.removed = const <({EdgeEndpoints key, int sortOrder})>[],
    this.added = const <EdgeEndpoints>[],
    this.previousSortOrders = const <EdgeEndpoints, int>{},
  });

  final List<({EdgeEndpoints key, int sortOrder})> removed;
  final List<EdgeEndpoints> added;
  final Map<EdgeEndpoints, int> previousSortOrders;

  bool get isEmpty =>
      removed.isEmpty && added.isEmpty && previousSortOrders.isEmpty;
}

/// 能不能插进叙事链：只有 image / video / shot 的**配置**节点能。
/// 文本节点进了链也成不了一镜（create_menu_model 头注），产物不在链上（export_order 头注）。
bool canInsertType(CanvasNode node) =>
    node.role == NodeRole.config &&
    (node.type == CanvasNodeType.image ||
        node.type == CanvasNodeType.video ||
        node.type == CanvasNodeType.shot);

/// 把 [newNodeId] 插进叙事边 [edge]（A→B）：删 A→B，建 A→X（沿用 A→B 的 sortOrder——
/// 在 A 的分叉里占原来那一位）与 X→B（sortOrder 0）。
///
/// 边不是叙事边、X 已有任何叙事边（已在链上的挪位走 [movePlan]）、X 是 A 或 B ⇒ null。
SplicePlan? insertPlan({
  required CanvasEdge edge,
  required String newNodeId,
  required List<CanvasEdge> edges,
}) {
  if (edge.edgeType != EdgeType.narrative) return null;
  if (newNodeId == edge.sourceNodeId || newNodeId == edge.targetNodeId) {
    return null;
  }
  for (final CanvasEdge e in edges) {
    if (_isNarrative(e) &&
        (e.sourceNodeId == newNodeId || e.targetNodeId == newNodeId)) {
      return null;
    }
  }
  final _PlanBuilder b = _PlanBuilder(edges)
    ..remove(edge)
    ..add(edge.sourceNodeId, newNodeId, sortOrder: edge.sortOrder)
    ..add(newNodeId, edge.targetNodeId, sortOrder: 0);
  return b.build();
}

/// 删掉 [deletedIds] 之后把链前后接上。
///
/// 按「连续被删的一段」（被删节点经叙事边相连的极大串）逐段算：
/// - 段没有外来叙事入边或没有外去叙事出边（删的是链头 / 链尾 / 孤立的一圈）⇒ 无事可接，不计 skipped；
/// - 段内每个节点叙事入度 == 1 且出度 == 1（计全部叙事边，含连向被删节点的）⇒ 接 段前一镜 P →
///   段后一镜 S，sortOrder 沿用 P→段首 那条；
/// - 否则（段里有分叉 / 汇合）⇒ 整段不接，skippedSegments + 1。
/// P == S、P→S 已有在世叙事边 ⇒ 不接、不计 skipped。
///
/// 返回的 plan 只含要建的桥接边；被删节点自己的边不在这里删（随节点删除走）。
BridgePlan bridgePlan({
  required Set<String> deletedIds,
  required List<CanvasEdge> edges,
}) {
  final List<CanvasEdge> narrative = edges.where(_isNarrative).toList();
  final Map<String, int> inDeg = <String, int>{};
  final Map<String, int> outDeg = <String, int>{};
  for (final CanvasEdge e in narrative) {
    outDeg[e.sourceNodeId] = (outDeg[e.sourceNodeId] ?? 0) + 1;
    inDeg[e.targetNodeId] = (inDeg[e.targetNodeId] ?? 0) + 1;
  }

  final _PlanBuilder b = _PlanBuilder(edges);
  int skipped = 0;
  final Set<String> visited = <String>{};
  for (final String start in deletedIds) {
    if (!visited.add(start)) continue;
    // 无向扩张出这一段：两端都被删的叙事边把它们连成一串。
    final Set<String> segment = <String>{start};
    final List<String> stack = <String>[start];
    while (stack.isNotEmpty) {
      final String cur = stack.removeLast();
      for (final CanvasEdge e in narrative) {
        final String? other = e.sourceNodeId == cur
            ? e.targetNodeId
            : (e.targetNodeId == cur ? e.sourceNodeId : null);
        if (other == null || !deletedIds.contains(other)) continue;
        if (segment.add(other)) {
          visited.add(other);
          stack.add(other);
        }
      }
    }

    final List<CanvasEdge> extIn = <CanvasEdge>[
      for (final CanvasEdge e in narrative)
        if (segment.contains(e.targetNodeId) &&
            !segment.contains(e.sourceNodeId))
          e,
    ];
    final List<CanvasEdge> extOut = <CanvasEdge>[
      for (final CanvasEdge e in narrative)
        if (segment.contains(e.sourceNodeId) &&
            !segment.contains(e.targetNodeId))
          e,
    ];
    if (extIn.isEmpty || extOut.isEmpty) continue; // 链头 / 链尾：无事可接

    final bool simple =
        segment.every((String id) => inDeg[id] == 1 && outDeg[id] == 1);
    if (!simple) {
      skipped++;
      continue;
    }
    // 入度 == 出度 == 1 的连通段就是一条简单路径：外来入边、外去出边各恰一条。
    final CanvasEdge head = extIn.single;
    final CanvasEdge tail = extOut.single;
    b.add(head.sourceNodeId, tail.targetNodeId, sortOrder: head.sortOrder);
  }
  return (plan: b.build(), skippedSegments: skipped);
}

/// 拖到叙事线 [edge]（A→B）上插一镜时，A、B 之间放不下一张卡 ⇒ B 及 B 的全部叙事后继
/// 沿泳道主轴后移一格；放得下 ⇒ 空 map。
///
/// 主轴：horizontal = x、vertical = y（无泳道按 horizontal 传）。一格 = 卡片主轴尺寸 +
/// [kSpliceSlotGap]；放得下 = A 卡尾到 B 卡头的空隙 ≥ 卡片主轴尺寸 + 2 · gap。
/// 卡片矩形一律按 position + kNodeCardSize 算，不读 CanvasNode.size（DB 的 size 列不驱动渲染）。
/// 后继走 DFS、去重、遇到 A 停（链上有环时每个节点只移一次、A 不动）。
/// 返回 节点 id → 位移；调用方包成 moveNodes 的 NodeMove。
Map<String, Offset> makeRoomShifts({
  required CanvasEdge edge,
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  required LaneDirection direction,
}) {
  final Map<String, CanvasNode> byId = <String, CanvasNode>{
    for (final CanvasNode n in nodes) n.id: n,
  };
  final CanvasNode? a = byId[edge.sourceNodeId];
  final CanvasNode? b = byId[edge.targetNodeId];
  if (a == null || b == null) return const <String, Offset>{};

  final bool horizontal = direction == LaneDirection.horizontal;
  final double cardMain =
      horizontal ? kNodeCardSize.width : kNodeCardSize.height;
  final double aStart = horizontal ? a.position.dx : a.position.dy;
  final double bStart = horizontal ? b.position.dx : b.position.dy;
  final double gap = bStart - (aStart + cardMain);
  if (gap >= cardMain + 2 * kSpliceSlotGap) return const <String, Offset>{};

  final double slot = cardMain + kSpliceSlotGap;
  final Offset shift = horizontal ? Offset(slot, 0) : Offset(0, slot);

  final Map<String, List<String>> successors = <String, List<String>>{};
  for (final CanvasEdge e in edges) {
    if (!_isNarrative(e)) continue;
    (successors[e.sourceNodeId] ??= <String>[]).add(e.targetNodeId);
  }
  final Set<String> seen = <String>{};
  final List<String> stack = <String>[b.id];
  while (stack.isNotEmpty) {
    final String cur = stack.removeLast();
    if (cur == a.id || !seen.add(cur)) continue;
    stack.addAll(successors[cur] ?? const <String>[]);
  }
  return <String, Offset>{
    for (final String id in seen)
      if (byId.containsKey(id)) id: shift,
  };
}

/// 大纲拖动：把已在链上的 [nodeId]（X）挪到 [afterId]（A）之后。
///
/// - X 叙事入度或出度 ≥ 2（分叉 / 汇合，与 bridgePlan 同口径）、X == A ⇒ null；
/// - X 已是 A 的直接后继 ⇒ 空 plan；
/// - 否则摘出 X（删 X 的入 / 出叙事边，P→S 接上，sortOrder 沿用 P→X），再插到 A 后：
///   A 恰一条叙事出边 A→B ⇒ 删 A→B、建 A→X（沿用 A→B 的 sortOrder）与 X→B；
///   A 无出边或有分叉 ⇒ 建 A→X，排在 A 已有分支之后（[nextNarrativeSortOrder]），不拆分叉。
SplicePlan? movePlan({
  required String nodeId,
  required String afterId,
  required List<CanvasEdge> edges,
}) {
  if (nodeId == afterId) return null;
  final List<CanvasEdge> ins = <CanvasEdge>[
    for (final CanvasEdge e in edges)
      if (_isNarrative(e) && e.targetNodeId == nodeId) e,
  ];
  final List<CanvasEdge> outs = <CanvasEdge>[
    for (final CanvasEdge e in edges)
      if (_isNarrative(e) && e.sourceNodeId == nodeId) e,
  ];
  if (ins.length >= 2 || outs.length >= 2) return null;
  if (ins.isNotEmpty && ins.single.sourceNodeId == afterId) {
    return const SplicePlan();
  }

  final _PlanBuilder b = _PlanBuilder(edges);
  // 摘出 X，前后接上。
  for (final CanvasEdge e in ins) {
    b.remove(e);
  }
  for (final CanvasEdge e in outs) {
    b.remove(e);
  }
  if (ins.isNotEmpty && outs.isNotEmpty) {
    b.add(ins.single.sourceNodeId, outs.single.targetNodeId,
        sortOrder: ins.single.sortOrder);
  }

  // 插到 A 后——看的是摘出之后的边集（X 已没有任何叙事边）。
  final List<CanvasEdge> remaining = b.alive();
  final List<CanvasEdge> anchorOuts = <CanvasEdge>[
    for (final CanvasEdge e in remaining)
      if (_isNarrative(e) && e.sourceNodeId == afterId) e,
  ];
  if (anchorOuts.length == 1) {
    final CanvasEdge ab = anchorOuts.single;
    b
      ..remove(ab)
      ..add(afterId, nodeId, sortOrder: ab.sortOrder)
      ..add(nodeId, ab.targetNodeId, sortOrder: 0);
  } else {
    b.add(afterId, nodeId,
        sortOrder: nextNarrativeSortOrder(anchorId: afterId, edges: remaining));
  }
  return b.build();
}

/// 同一分叉下兄弟换序：把 [parentId] 的**全部**叙事出边 sortOrder 改成 0..n-1。
///
/// 先按 [orderedChildIds] 的顺序编号；列表里不是 P 直接后继的 id、重复的 id 忽略。
/// 列表可以不完整：没列出的后继保持彼此原来的相对顺序（原 sortOrder 升序，同号按边 id），
/// 接在列出的后面继续编号——结果总是 P 全部叙事出边的一个 0..n-1 排列，不会撞号。
/// 不删不加；值不变的边不写进 sortOrders。
SplicePlan siblingReorderPlan({
  required String parentId,
  required List<String> orderedChildIds,
  required List<CanvasEdge> edges,
}) {
  final Map<String, CanvasEdge> byChild = <String, CanvasEdge>{
    for (final CanvasEdge e in edges)
      if (_isNarrative(e) && e.sourceNodeId == parentId) e.targetNodeId: e,
  };
  final Map<String, int> sortOrders = <String, int>{};
  final Set<String> seen = <String>{};
  int next = 0;
  for (final String child in orderedChildIds) {
    final CanvasEdge? e = byChild[child];
    if (e == null || !seen.add(child)) continue;
    final int order = next++;
    if (e.sortOrder != order) sortOrders[e.id] = order;
  }
  // 没列出的后继：按原相对顺序接在后面，否则会与上面的新编号撞号。
  final List<CanvasEdge> unlisted = <CanvasEdge>[
    for (final MapEntry<String, CanvasEdge> entry in byChild.entries)
      if (!seen.contains(entry.key)) entry.value,
  ];
  unlisted.sort((CanvasEdge x, CanvasEdge y) {
    final int bySort = x.sortOrder.compareTo(y.sortOrder);
    return bySort != 0 ? bySort : x.id.compareTo(y.id);
  });
  for (final CanvasEdge e in unlisted) {
    final int order = next++;
    if (e.sortOrder != order) sortOrders[e.id] = order;
  }
  return SplicePlan(sortOrders: Map<String, int>.unmodifiable(sortOrders));
}

/// 建叙事边 [sourceNodeId] → [targetNodeId] 会不会成环：沿叙事边从 target 能走到 source ⇒ true；
/// 两端相同 ⇒ true。
bool wouldCreateNarrativeCycle({
  required String sourceNodeId,
  required String targetNodeId,
  required List<CanvasEdge> edges,
}) {
  if (sourceNodeId == targetNodeId) return true;
  final Map<String, List<String>> successors = <String, List<String>>{};
  for (final CanvasEdge e in edges) {
    if (!_isNarrative(e)) continue;
    (successors[e.sourceNodeId] ??= <String>[]).add(e.targetNodeId);
  }
  final Set<String> seen = <String>{};
  final List<String> stack = <String>[targetNodeId];
  while (stack.isNotEmpty) {
    final String cur = stack.removeLast();
    if (cur == sourceNodeId) return true;
    if (!seen.add(cur)) continue;
    stack.addAll(successors[cur] ?? const <String>[]);
  }
  return false;
}

/// 由令牌算撤销用的 plan，全程按两端找边、不用边 id：
/// - [SpliceUndoToken.added]：按两端找在世边 → 删（找不到跳过）；
/// - [SpliceUndoToken.removed]：同两端此刻（扣掉上一步要删的）没有在世边 → 按原 role / sortOrder 重建；
/// - [SpliceUndoToken.previousSortOrders]：找到边就改回原值。
/// 三样都空 ⇒ null（对象都已不在，调用方判 gone）。
///
/// 【端点节点在不在】本函数只看边、看不到节点：节点删除会把它的边一起软删，于是
/// 「端点已删的边」在 [current] 里同样不在世，单看边会被当成可重建、建到软删节点上。
/// 调用方须传 [aliveNodeIds] = 画布此刻在世的节点 id 集合（节点控制器当前的 id 集）：
/// removed 里任一端不在其中的边跳过、不重建；因此三样都空时同样返回 null。
/// 传 null = 不按节点过滤（只给已确知端点都在世的场合用）。
SplicePlan? invertSplice(
  SpliceUndoToken token,
  List<CanvasEdge> current, {
  Set<String>? aliveNodeIds,
}) {
  final _PlanBuilder b = _PlanBuilder(current);
  for (final EdgeEndpoints k in token.added) {
    final CanvasEdge? e = findEdgeByEndpoints(b.alive(), k);
    if (e != null) b.remove(e);
  }
  // 「删 A→B 又建 A→B」的令牌：上一步已把新建那条删掉，这里要能把原来那条建回来，
  // 所以「此刻在世」看的是扣掉本 plan 要删的之后。
  for (final ({EdgeEndpoints key, int sortOrder}) r in token.removed) {
    if (aliveNodeIds != null &&
        (!aliveNodeIds.contains(r.key.sourceNodeId) ||
            !aliveNodeIds.contains(r.key.targetNodeId))) {
      continue; // 端点节点已删：不把边建到软删节点上
    }
    b.add(r.key.sourceNodeId, r.key.targetNodeId,
        edgeType: r.key.edgeType, role: r.key.role, sortOrder: r.sortOrder);
  }
  final List<CanvasEdge> alive = b.alive();
  for (final MapEntry<EdgeEndpoints, int> entry
      in token.previousSortOrders.entries) {
    final CanvasEdge? e = findEdgeByEndpoints(alive, entry.key);
    if (e != null) b.sortOrders[e.id] = entry.value;
  }
  final SplicePlan plan = b.build();
  return plan.isEmpty ? null : plan;
}

bool _isNarrative(CanvasEdge e) => e.edgeType == EdgeType.narrative;

/// plan 构造器：记删 / 加 / 改序，保证加的边不撞「删后仍在世」的边、彼此也不重复，
/// 且不建自环。
class _PlanBuilder {
  _PlanBuilder(this._edges);

  final List<CanvasEdge> _edges;
  final Set<String> _remove = <String>{};
  final List<SpliceEdgeSpec> _add = <SpliceEdgeSpec>[];
  final Map<String, int> sortOrders = <String, int>{};

  void remove(CanvasEdge e) => _remove.add(e.id);

  /// 删后仍在世的边（不含本 plan 要建的）。
  List<CanvasEdge> alive() => <CanvasEdge>[
        for (final CanvasEdge e in _edges)
          if (!_remove.contains(e.id)) e,
      ];

  void add(
    String source,
    String target, {
    EdgeType edgeType = EdgeType.narrative,
    EdgeRole role = EdgeRole.reference,
    required int sortOrder,
  }) {
    if (source == target) return;
    final EdgeEndpoints key = EdgeEndpoints(
        sourceNodeId: source, targetNodeId: target, edgeType: edgeType);
    if (findEdgeByEndpoints(alive(), key) != null) return;
    for (final SpliceEdgeSpec s in _add) {
      if (s.sourceNodeId == source &&
          s.targetNodeId == target &&
          s.edgeType == edgeType) {
        return;
      }
    }
    _add.add((
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: edgeType,
      role: role,
      sortOrder: sortOrder,
    ));
  }

  SplicePlan build() => SplicePlan(
        removeEdgeIds: Set<String>.unmodifiable(_remove),
        addEdges: List<SpliceEdgeSpec>.unmodifiable(_add),
        sortOrders: Map<String, int>.unmodifiable(sortOrders),
      );
}
