// 左栏大纲的分组模型（纯函数）：画布节点 + 边 + 泳道 → 一组组镜头行。widget 只负责渲染。
//
// 分组口径（PR-4 派工单 §3）：
//   a. 叙事链上的配置节点（role == config）按泳道分组：组序跟泳道 sortOrder，组内按叙事链序。
//      在链上但不属于任何泳道（laneId 为空 / 泳道已不在）的进「未分泳道」，排在泳道组之后。
//   b. 不在链上的配置节点进「未入链」，放在最后，按位置 (dx, dy, id) 排、不编号。
//   空组不出：没有镜头的泳道不画组头，筛选后一个都不匹配的组整组不画。
//
// 「在链上」的判据只有一份：[narrativeChainMembers]——narrative 边两端都在节点集里。组内行序是叙事链序
// （[narrativeSequenceIndex]，不折叠：链上每个节点都排得上位置）。
//
// 镜号（行首的「01」、⌘K 镜头组的「序列 003」）用**序列的口径**：[sequenceShotNumbers]——序列 lens 折叠后的
// 镜序（全画布的，1 起，不是组内序号），节点归哪一镜复用「在序列中查看」的判据
// （sequence/util/shot_index.dart）。同一张图在大纲、⌘K、序列视图、画廊（「序列 002」）里因此是同一个号。
// 几种节点由此共号或无号：
//   - 借出产物的配置节点与借走它产物的那一镜同号（「导入剧本 + 用本镜备注生成图像」那条主路径：镜头 →
//     图像配置，图挂在配置名下，序列里放在镜头那一镜）；
//   - 链上但不在任何一镜里的节点（折叠时被跳过：自己没产物没备注，也没借到、没被借）不编号，仍留在泳道组里。
// 组头「N 镜」是组内不同镜号的个数（[OutlineGroup.shotCount]），不是行数。
//
// 「未入链」组列的是不在链上的**全部**配置节点（有没有产物都列）；序列标签状态栏的「未入链 · N」只数其中
// 有产物的（SequenceLens.unchainedCount）——两处口径不同，数字对不上是正常的。
import 'package:flutter/foundation.dart';

import '../../sequence/models/sequence_lens.dart';
import '../../sequence/util/shot_index.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/canvas_node_take.dart';
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

/// 链上节点 → 1 起的**链序**（叙事链 DFS 序，[orderByNarrativeChain]，不折叠）。不在链上的节点不在表里。
///
/// 只给大纲排组内行序用；显示出来的镜号不是它，是 [sequenceShotNumbers]（序列折叠后的镜序）。
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

/// 节点 → 它所在那一镜的镜号（1 起），序列的口径：大纲行首的镜号、⌘K 镜头组的「序列 NNN」都从这里取，
/// 与序列视图、画廊的序号是同一个数。
///
/// 镜 = 序列 lens 的镜（[buildSequenceLens]：叙事链折叠后只留链上的镜——「借产物」的后继并进前一镜，
/// 既无产物也无备注的节点跳过）；节点归哪一镜 = [shotIndexByNode]（与「在序列中查看」同一判据：产物归
/// 来源配置节点，借出产物的配置节点归借走它的那一镜）。不在任何一镜里的节点不在表里。
Map<String, int> sequenceShotNumbers(List<CanvasNode> nodes, List<CanvasEdge> edges) {
  final SequenceLens lens = buildSequenceLens(nodes: nodes, edges: edges);
  return <String, int>{
    for (final MapEntry<String, int> e in shotIndexByNode(lens, nodes: nodes).entries)
      e.key: e.value + 1,
  };
}

/// 一行镜头：配置节点 + 镜号 + 当前 take（固定的 ?? 最新的）。
@immutable
class OutlineShot {
  const OutlineShot({
    required this.node,
    this.sequence,
    this.current,
    this.artifactCount = 0,
  });

  final CanvasNode node;

  /// 所在那一镜的镜号（1 起，序列口径，[sequenceShotNumbers]）；未入链、或链上但不在任何一镜里为 null
  /// （不编号）。
  final int? sequence;

  /// 当前 take（result 节点，[currentResultFor] 口径：配置节点固定的那个还活着就是它，否则按 created_at
  /// 取最新）；没有产物为 null。
  final CanvasNode? current;

  /// 名下产物总数（[resultsFor] 口径，固定与否不影响）。> 1 时产物子行写「共 N 个」。
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

  /// 组内不同镜号的个数（组头「N 镜」）：同一镜的几行（镜头 + 借出产物的配置）只算一镜，没有镜号的行不算。
  int get shotCount => <int>{
        for (final OutlineShot s in shots)
          if (s.sequence case final int n) n,
      }.length;
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
  // 链序只管「谁在链上、组内怎么排」；行首显示的镜号走序列口径。
  final Map<String, int> chainOrder = narrativeSequenceIndex(nodes, edges);
  final Map<String, int> shotNumber = sequenceShotNumbers(nodes, edges);

  final String q = query.trim().toLowerCase();
  bool matches(CanvasNode n) {
    if (q.isEmpty) return true;
    if (nameOf(n).toLowerCase().contains(q)) return true;
    final String? prompt = promptOf(n);
    return prompt != null && prompt.toLowerCase().contains(q);
  }

  // 产物按来源分桶一次，再逐桶交给 resultsFor / currentResultFor——「当前」只有那一个判官，这里不另写
  // 一份；桶内保持节点列表原序（resultsFor 对缺时间戳的产物按原序取末位为最新）。桶里没有配置节点，
  // 固定的 take 得显式传 pinnedResultId。
  final Map<String, List<CanvasNode>> resultsBySource = <String, List<CanvasNode>>{};
  for (final CanvasNode n in nodes) {
    final String? source = n.sourceNodeId;
    if (n.role != NodeRole.result || source == null) continue;
    (resultsBySource[source] ??= <CanvasNode>[]).add(n);
  }
  OutlineShot shotOf(CanvasNode n) {
    final List<CanvasNode> bucket = resultsBySource[n.id] ?? const <CanvasNode>[];
    return OutlineShot(
      node: n,
      sequence: shotNumber[n.id],
      current: currentResultFor(sourceNodeId: n.id, nodes: bucket, pinnedResultId: n.pinnedResultId),
      artifactCount: resultsFor(sourceNodeId: n.id, nodes: bucket).length,
    );
  }

  final List<CanvasNode> chained = <CanvasNode>[
    for (final CanvasNode n in configs)
      if (chainOrder.containsKey(n.id)) n,
  ]..sort((CanvasNode a, CanvasNode b) => chainOrder[a.id]!.compareTo(chainOrder[b.id]!));
  // 没有边时 orderByNarrativeChain 退化成按 (dx, dy, id) 排——「按位置」借它的口径，不另写比较器。
  final List<CanvasNode> unchained = orderByNarrativeChain(
    nodes: <CanvasNode>[
      for (final CanvasNode n in configs)
        if (!chainOrder.containsKey(n.id)) n,
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
