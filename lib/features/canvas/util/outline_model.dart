// 左栏大纲的分组模型（纯函数）：画布节点 + 边 + 泳道 → 一组组镜头行。widget 只负责渲染。
//
// 分组口径（PR-4 派工单 §3）：
//   a. 叙事链上的配置节点（role == config）按泳道分组：组序跟泳道 sortOrder，组内按叙事链序。
//      在链上但不属于任何泳道（laneId 为空 / 泳道已不在）的进「未分泳道」，排在泳道组之后。
//   b. 不在链上的配置节点进「未入链」，放在最后，按位置 (dx, dy, id) 排、不编号。
//   空组不出：没有镜头的泳道不画组头，筛选后一个都不匹配的组整组不画。
//
// 「在链上」的判据只有一份：[narrativeChainMembers]——narrative 边两端都在节点集里。
// ⌘K 镜头组的「序列 003」与这里的「01」都从 [narrativeSequenceIndex] 来，两处不会走岔。
//
// 链序号是**全画布**的叙事链序（1 起），不是组内序号：同一镜在大纲、⌘K、画廊里是同一个号。
import 'package:flutter/foundation.dart';

import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import 'narrative_order.dart';
import 'node_artifacts.dart';

/// 叙事链成员：narrative 边两端都在 [nodes] 里的节点 id。悬空边（一端已删）不算。
Set<String> narrativeChainMembers(
  List<CanvasNode> nodes,
  List<CanvasEdge> edges,
) {
  final Set<String> ids = <String>{for (final CanvasNode n in nodes) n.id};
  final Set<String> members = <String>{};
  for (final CanvasEdge e in edges) {
    if (e.edgeType != EdgeType.narrative) continue;
    if (!ids.contains(e.sourceNodeId) || !ids.contains(e.targetNodeId)) continue;
    members
      ..add(e.sourceNodeId)
      ..add(e.targetNodeId);
  }
  return members;
}

/// 链上节点 → 1 起的链序号；顺序 = 叙事链序（[orderByNarrativeChain]）。不在链上的节点不在表里。
Map<String, int> narrativeSequenceIndex(
  List<CanvasNode> nodes,
  List<CanvasEdge> edges,
) {
  final Set<String> members = narrativeChainMembers(nodes, edges);
  if (members.isEmpty) return const <String, int>{};
  final List<CanvasNode> ordered = orderByNarrativeChain(
    nodes: nodes,
    edges: edges,
    include: (CanvasNode n) => members.contains(n.id),
  );
  return <String, int>{
    for (int i = 0; i < ordered.length; i++) ordered[i].id: i + 1,
  };
}

/// 一行镜头：配置节点 + 链序号 + 名下最新产物。
@immutable
class OutlineShot {
  const OutlineShot({
    required this.node,
    this.sequence,
    this.latest,
    this.artifactCount = 0,
  });

  final CanvasNode node;

  /// 全画布叙事链序（1 起）；未入链为 null（不编号）。
  final int? sequence;

  /// 名下最新的产物（result 节点，[resultsFor] 口径：按 created_at 取最新）；没有为 null。
  final CanvasNode? latest;

  /// 名下产物总数（同一口径）。> 1 时产物子行写「共 N 个」。
  final int artifactCount;
}

enum OutlineGroupKind {
  /// 某条泳道（[OutlineGroup.lane] 非空）。
  lane,

  /// 在链上、但不属于任何（现存的）泳道。
  unassigned,

  /// 不在叙事链上。
  unchained,
}

@immutable
class OutlineGroup {
  const OutlineGroup({required this.kind, required this.shots, this.lane});

  final OutlineGroupKind kind;

  /// [kind] == lane 时为该泳道，其余为 null。
  final StyleLane? lane;

  /// 至少一行（空组不产出）。
  final List<OutlineShot> shots;
}

/// 一次分组的结果。
@immutable
class CanvasOutline {
  const CanvasOutline({required this.groups, required this.configCount});

  final List<OutlineGroup> groups;

  /// 筛选**之前**画布上的配置节点总数：0 ⇒ 面板出空态；> 0 而 [groups] 为空 ⇒ 只是筛选没命中。
  final int configCount;
}

/// 分组。[nameOf] / [promptOf] 由界面传入（显示名回落要本地化，正文取法与节点卡同源），
/// 筛选在这里做：[query] 去首尾空白后，对名称或提示词做不区分大小写的包含匹配。
CanvasOutline buildCanvasOutline({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  required List<StyleLane> lanes,
  required String Function(CanvasNode node) nameOf,
  required String? Function(CanvasNode node) promptOf,
  String query = '',
}) {
  final List<CanvasNode> configs = <CanvasNode>[
    for (final CanvasNode n in nodes)
      if (n.role == NodeRole.config) n,
  ];
  final Map<String, int> sequence = narrativeSequenceIndex(nodes, edges);

  final String q = query.trim().toLowerCase();
  bool matches(CanvasNode n) {
    if (q.isEmpty) return true;
    if (nameOf(n).toLowerCase().contains(q)) return true;
    final String? prompt = promptOf(n);
    return prompt != null && prompt.toLowerCase().contains(q);
  }

  // 产物按来源分桶一次，再逐桶交给 resultsFor——「最新」只有那一个判官，这里不另写一份；
  // 桶内保持节点列表原序（resultsFor 对缺时间戳的产物按原序取末位为最新）。
  final Map<String, List<CanvasNode>> resultsBySource = <String, List<CanvasNode>>{};
  for (final CanvasNode n in nodes) {
    final String? source = n.sourceNodeId;
    if (n.role != NodeRole.result || source == null) continue;
    (resultsBySource[source] ??= <CanvasNode>[]).add(n);
  }
  OutlineShot shotOf(CanvasNode n) {
    final List<CanvasNode> results = resultsFor(
      sourceNodeId: n.id,
      nodes: resultsBySource[n.id] ?? const <CanvasNode>[],
    );
    return OutlineShot(
      node: n,
      sequence: sequence[n.id],
      latest: results.isEmpty ? null : results.first,
      artifactCount: results.length,
    );
  }

  final List<CanvasNode> chained = <CanvasNode>[
    for (final CanvasNode n in configs)
      if (sequence.containsKey(n.id)) n,
  ]..sort((CanvasNode a, CanvasNode b) => sequence[a.id]!.compareTo(sequence[b.id]!));
  // 没有边时 orderByNarrativeChain 退化成按 (dx, dy, id) 排——「按位置」借它的口径，不另写比较器。
  final List<CanvasNode> unchained = orderByNarrativeChain(
    nodes: <CanvasNode>[
      for (final CanvasNode n in configs)
        if (!sequence.containsKey(n.id)) n,
    ],
    edges: const <CanvasEdge>[],
  );

  // 泳道按 sortOrder 排；同序按传入顺序（List.sort 不保证稳定，用下标兜底）。
  final List<StyleLane> orderedLanes = <StyleLane>[...lanes];
  final Map<String, int> laneIndex = <String, int>{
    for (int i = 0; i < lanes.length; i++) lanes[i].id: i,
  };
  orderedLanes.sort((StyleLane a, StyleLane b) {
    final int byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : laneIndex[a.id]!.compareTo(laneIndex[b.id]!);
  });

  final List<OutlineGroup> groups = <OutlineGroup>[];
  for (final StyleLane lane in orderedLanes) {
    final List<OutlineShot> shots = <OutlineShot>[
      for (final CanvasNode n in chained)
        if (n.laneId == lane.id && matches(n)) shotOf(n),
    ];
    if (shots.isNotEmpty) {
      groups.add(OutlineGroup(kind: OutlineGroupKind.lane, lane: lane, shots: shots));
    }
  }
  final List<OutlineShot> unassigned = <OutlineShot>[
    for (final CanvasNode n in chained)
      if ((n.laneId == null || !laneIndex.containsKey(n.laneId)) && matches(n)) shotOf(n),
  ];
  if (unassigned.isNotEmpty) {
    groups.add(OutlineGroup(kind: OutlineGroupKind.unassigned, shots: unassigned));
  }
  final List<OutlineShot> loose = <OutlineShot>[
    for (final CanvasNode n in unchained)
      if (matches(n)) shotOf(n),
  ];
  if (loose.isNotEmpty) {
    groups.add(OutlineGroup(kind: OutlineGroupKind.unchained, shots: loose));
  }

  return CanvasOutline(groups: groups, configCount: configs.length);
}
