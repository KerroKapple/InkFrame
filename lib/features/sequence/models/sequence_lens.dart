// 序列 lens（P2）：把 buildSequence 的播放清单再压成序列视图要的几何——每镜起点、总长、
// 场次标记、未入链计数。纯函数，无 Flutter 依赖。
//
// 场次标记的推导规则（拍板「场次标记由叙事链推导」，仓库没有标记模型）：
// 链上每个 shot 类型（分镜描述）的节点开启一个场次，标记落在它那一镜的起点，标签是节点名。
// 用户手打的标记（M 键）没有字段，不做。
import 'package:flutter/foundation.dart';

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/node_artifacts.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../../storyboard/util/sequence_builder.dart';

@immutable
class SceneMarker {
  const SceneMarker({required this.atMs, required this.label, required this.nodeId});
  final int atMs;
  final String label;
  final String nodeId;
}

@immutable
class SequenceLens {
  const SequenceLens({
    required this.shots,
    required this.startsMs,
    required this.totalMs,
    required this.markers,
    required this.unchainedCount,
  });

  static const SequenceLens empty = SequenceLens(
    shots: <SequenceShot>[],
    startsMs: <int>[],
    totalMs: 0,
    markers: <SceneMarker>[],
    unchainedCount: 0,
  );

  final List<SequenceShot> shots;
  /// 每镜在序列时间轴上的起点（ms），与 [shots] 等长。
  final List<int> startsMs;
  final int totalMs;
  final List<SceneMarker> markers;
  /// 有产物但不在叙事链上的 config 节点数（稿的「未入链 · N」）。
  final int unchainedCount;

  bool get isEmpty => shots.isEmpty;
  int get placeholderCount => shots.where((s) => s.kind == SequenceArtifactKind.none).length;
  int get videoCount => shots.where((s) => s.kind == SequenceArtifactKind.video).length;

  /// 全局毫秒 → (镜下标, 镜内偏移)。越界夹到首尾。
  ({int index, int offsetMs}) locate(int ms) {
    if (shots.isEmpty) return (index: 0, offsetMs: 0);
    if (ms <= 0) return (index: 0, offsetMs: 0);
    for (int i = shots.length - 1; i >= 0; i--) {
      if (ms >= startsMs[i]) {
        final int off = (ms - startsMs[i]).clamp(0, shots[i].durationMs);
        return (index: i, offsetMs: off);
      }
    }
    return (index: 0, offsetMs: 0);
  }

  int globalMs(int index, int offsetMs) {
    if (shots.isEmpty) return 0;
    final int i = index.clamp(0, shots.length - 1);
    return startsMs[i] + offsetMs.clamp(0, shots[i].durationMs);
  }
}

SequenceLens buildSequenceLens({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
}) {
  final List<SequenceShot> shots = buildSequence(nodes: nodes, edges: edges);
  final List<int> starts = <int>[];
  int acc = 0;
  for (final SequenceShot s in shots) {
    starts.add(acc);
    acc += s.durationMs;
  }

  final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final n in nodes) n.id: n};
  final List<SceneMarker> markers = <SceneMarker>[];
  for (int i = 0; i < shots.length; i++) {
    final CanvasNode? n = byId[shots[i].nodeId];
    if (n != null && n.type == CanvasNodeType.shot) {
      markers.add(SceneMarker(atMs: starts[i], label: n.label, nodeId: n.id));
    }
  }

  // 未入链：有产物的 config 节点里，不在链（narrative 边两端都在场）上的。
  final Set<String> ids = byId.keys.toSet();
  final Set<String> onChain = <String>{};
  for (final CanvasEdge e in edges) {
    if (e.edgeType != EdgeType.narrative) continue;
    if (!ids.contains(e.sourceNodeId) || !ids.contains(e.targetNodeId)) continue;
    onChain..add(e.sourceNodeId)..add(e.targetNodeId);
  }
  int unchained = 0;
  for (final CanvasNode n in nodes) {
    if (n.role != NodeRole.config || onChain.contains(n.id)) continue;
    if (latestResultFor(sourceNodeId: n.id, nodes: nodes) != null) unchained++;
  }

  return SequenceLens(
    shots: shots,
    startsMs: starts,
    totalMs: acc,
    markers: markers,
    unchainedCount: unchained,
  );
}
