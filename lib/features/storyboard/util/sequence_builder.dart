// 把画布的 narrative 链编译成一条播放清单（SB-6）。
//
// 输入是画布的全量节点 + 边，输出是「第 N 镜放什么、放多久」。排序复用
// SB-5 的 `orderByNarrativeChain`，产物查找复用 EX-1′ 首建的
// `latestResultFor`——本卡只消费，不再造第二套（卡面裁决）。
//
// ## 为什么需要「折叠」这一步
//
// 用户从 shot 节点点「用本镜备注生成图像」时，实际建出来的是：
//
//     shot ──narrative──> image config ──(sourceNodeId)──> image result
//
// 也就是说 **config 节点也在 narrative 链上**。如果照单把每个链上节点都当
// 一镜，一条 3 镜的分镜会播出 6 条：shot1(无产物→占位)、cfg1(图)、
// shot2(占位)、cfg2(图)……每镜都重复一遍。这不是边角情况——`_generateImageFromNotes`
// 是当前把图接进分镜链的**唯一**入口，不折叠等于这张卡不可用。
//
// 所以：一个链上节点若把自己的产物「借」给了前面的 shot，就不再单独成镜。

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/narrative_order.dart';
import '../../canvas/util/node_artifacts.dart';
import '../models/sequence_shot.dart';

/// 按 narrative 链把 [nodes] / [edges] 编译成播放清单。
///
/// 每镜的产物 = 该节点自己的最新 result；自己没有时，向它的 narrative 后继
/// 里找第一个有产物的 config 节点借用（并把那个后继标记为已消费，不再单独成镜）。
///
/// 既无产物、也无 notes 的节点直接跳过——它对预览没有任何可展示内容
/// （典型是纯 result 节点，它们本来就不该独立成镜）。
List<SequenceShot> buildSequence({
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
}) {
  if (nodes.isEmpty) return const <SequenceShot>[];

  final byId = <String, CanvasNode>{for (final n in nodes) n.id: n};

  // narrative 后继表（只认两端都在场的边），按 (sortOrder, 边 id) 定序，
  // 与 orderByNarrativeChain 的分叉规则保持一致。
  final successors = <String, List<CanvasEdge>>{};
  for (final e in edges) {
    if (e.edgeType != EdgeType.narrative) continue;
    if (!byId.containsKey(e.sourceNodeId)) continue;
    if (!byId.containsKey(e.targetNodeId)) continue;
    (successors[e.sourceNodeId] ??= <CanvasEdge>[]).add(e);
  }
  for (final out in successors.values) {
    out.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
  }

  final chain = orderByNarrativeChain(nodes: nodes, edges: edges);
  final consumed = <String>{};
  final out = <SequenceShot>[];

  for (final node in chain) {
    if (consumed.contains(node.id)) continue;
    // result 节点不独立成镜——它们是别人的产物，不是一镜。
    if (node.role == NodeRole.result) continue;

    var artifact = latestResultFor(sourceNodeId: node.id, nodes: nodes);
    if (artifact == null) {
      for (final e in successors[node.id] ?? const <CanvasEdge>[]) {
        final succ = byId[e.targetNodeId]!;
        if (succ.role == NodeRole.result) continue;
        // 已被前面的镜借走的产物不能再借一次——多个 shot 指向同一个 config
        // 时（分叉/汇合），同一张图会在序列里出现两遍。
        if (consumed.contains(succ.id)) continue;
        final borrowed = latestResultFor(sourceNodeId: succ.id, nodes: nodes);
        if (borrowed == null) continue;
        artifact = borrowed;
        consumed.add(succ.id);
        break;
      }
    }

    final notes = _notesOf(node);
    if (artifact == null && (notes == null || notes.isEmpty)) continue;

    out.add(
      _shotFor(node: node, artifact: artifact, notes: notes),
    );
  }

  return out;
}

SequenceShot _shotFor({
  required CanvasNode node,
  required CanvasNode? artifact,
  required String? notes,
}) {
  final shotDurationMs = _positiveInt(node.typeConfig['duration_ms']);

  if (artifact == null) {
    return SequenceShot(
      nodeId: node.id,
      kind: SequenceArtifactKind.none,
      durationMs: shotDurationMs ?? kDefaultShotDurationMs,
      label: node.label,
      notes: notes,
    );
  }

  final videoUrl = artifact.videoUrl;
  if (videoUrl != null) {
    // 视频优先用产物自己的真实时长（XM-1 探测回填），其次是 shot 的预期时长。
    // 这里只是兜底——真正的推进以播放进度为准。
    final realMs = _positiveInt(artifact.typeConfig['duration_ms']);
    return SequenceShot(
      nodeId: node.id,
      kind: SequenceArtifactKind.video,
      durationMs: realMs ?? shotDurationMs ?? kDefaultShotDurationMs,
      label: node.label,
      notes: notes,
      relativePath: videoUrl,
      canvasId: artifact.canvasId,
    );
  }

  return SequenceShot(
    nodeId: node.id,
    kind: SequenceArtifactKind.image,
    durationMs: shotDurationMs ?? kDefaultShotDurationMs,
    label: node.label,
    notes: notes,
    relativePath: artifact.imageUrl,
    canvasId: artifact.canvasId,
  );
}

/// shot 节点看 shot_notes；config 节点退而用 prompt（用户看得懂的都行）。
String? _notesOf(CanvasNode node) {
  final n = node.typeConfig['shot_notes'];
  if (n is String && n.trim().isNotEmpty) return n;
  final p = node.typeConfig['prompt'];
  if (p is String && p.trim().isNotEmpty) return p;
  return null;
}

/// 非正数与非 int 一律当缺失——0 或负的时长会让那一镜永远停不下来。
int? _positiveInt(Object? raw) => raw is int && raw > 0 ? raw : null;
