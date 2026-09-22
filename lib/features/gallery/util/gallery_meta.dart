// 画廊的派生信息（纯函数，全部从 GalleryGraph 上算）：
//   - galleryItemKey：产物的稳定 key（选中集 / 网格 key 共用）
//   - GalleryItemMeta：名称 / providerId / 是否在叙事链上 / 序列序号 / 提示词 / 运镜 / 关键帧来源
//   - GalleryLineageRow：血缘 · 当前线（分镜文本 → 关键帧来源 → 当前项），被弃分支只折成 +N
//
// 「当前线」「已入序列」不是存储字段，是从叙事链推出来的（用户拍板 2026-09-22）。
import 'package:flutter/foundation.dart';

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/node_artifacts.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../../storyboard/util/sequence_builder.dart';
import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';

String galleryItemKey(GalleryItem item) =>
    '${item.canvasId}|${item.relativePath}|${item.slotIndex}';

/// 一条关键帧 / 参考输入：角色 + 上游 config 节点显示名。
@immutable
class GalleryKeyframeRef {
  const GalleryKeyframeRef({required this.role, required this.sourceLabel});
  final EdgeRole role;
  final String sourceLabel;
}

@immutable
class GalleryItemMeta {
  const GalleryItemMeta({
    required this.label,
    this.providerId,
    this.onNarrativeChain = false,
    this.sequenceIndex,
    this.prompt,
    this.cameraName,
    this.keyframes = const <GalleryKeyframeRef>[],
    this.baseStylePrefix = '',
    this.configNodeId,
  });

  static const GalleryItemMeta empty = GalleryItemMeta(label: '');

  /// 源 config 节点的 label；批量 slot 追加「 #n」。为空时由界面回落到类型名。
  final String label;
  final String? providerId;
  final bool onNarrativeChain;
  /// 在序列播放清单里的序号（1 起）；不在序列里为 null。
  final int? sequenceIndex;
  final String? prompt;
  final String? cameraName;
  final List<GalleryKeyframeRef> keyframes;
  final String baseStylePrefix;
  final String? configNodeId;
}

enum GalleryLineageKind { shotText, input, current }

@immutable
class GalleryLineageRow {
  const GalleryLineageRow({
    required this.kind,
    required this.name,
    this.role,
    this.thumbRelativePath,
    this.thumbCanvasId,
    this.resultCount = 0,
    this.sequenceIndex,
  });

  final GalleryLineageKind kind;
  final String name;
  /// [kind] == input 时的边角色。
  final EdgeRole? role;
  final String? thumbRelativePath;
  final String? thumbCanvasId;
  /// 该 config 一共有多少个成功产物；> 1 时显示「从 N 个结果中选定」，其余折成「+N-1 分支」。
  final int resultCount;
  final int? sequenceIndex;

  int get branches => resultCount > 1 ? resultCount - 1 : 0;
}

/// 项目内所有画布的派生索引：叙事链成员 + 序列清单（一次算，按画布缓存）。
@immutable
class GalleryIndex {
  const GalleryIndex._(this._chain, this._sequence);

  factory GalleryIndex.build(GalleryGraph graph) {
    final Map<String, Set<String>> chain = <String, Set<String>>{};
    final Map<String, List<SequenceShot>> sequence = <String, List<SequenceShot>>{};
    for (final GalleryCanvasInfo c in graph.canvases) {
      final List<CanvasNode> nodes = graph.nodesOf(c.id);
      final List<CanvasEdge> edges = graph.edgesOf(c.id);
      final Set<String> ids = <String>{for (final CanvasNode n in nodes) n.id};
      final Set<String> members = <String>{};
      for (final CanvasEdge e in edges) {
        if (e.edgeType != EdgeType.narrative) continue;
        if (!ids.contains(e.sourceNodeId) || !ids.contains(e.targetNodeId)) continue;
        members..add(e.sourceNodeId)..add(e.targetNodeId);
      }
      chain[c.id] = members;
      // buildSequence 会把走不到的有产物节点追加在链尾（预览要能播）；「已入序列」
      // 只认真正在叙事链上的那些镜——否则每个产物都算已入序列，这个标记就没意义了。
      sequence[c.id] = <SequenceShot>[
        for (final SequenceShot s in buildSequence(nodes: nodes, edges: edges))
          if (members.contains(s.nodeId)) s,
      ];
    }
    return GalleryIndex._(chain, sequence);
  }

  final Map<String, Set<String>> _chain;
  final Map<String, List<SequenceShot>> _sequence;

  bool onChain(String canvasId, String configNodeId) =>
      _chain[canvasId]?.contains(configNodeId) ?? false;

  int? sequenceIndexOf(String canvasId, String relativePath) {
    final List<SequenceShot>? shots = _sequence[canvasId];
    if (shots == null) return null;
    for (int i = 0; i < shots.length; i++) {
      if (shots[i].relativePath == relativePath) return i + 1;
    }
    return null;
  }
}

/// 产物的 config 节点：result 节点走 sourceNodeId，批量 slot 的 nodeId 本身就是 config。
CanvasNode? galleryConfigNodeOf(GalleryGraph graph, GalleryItem item) {
  final Map<String, CanvasNode> byId = <String, CanvasNode>{
    for (final CanvasNode n in graph.nodesOf(item.canvasId)) n.id: n,
  };
  final CanvasNode? node = byId[item.nodeId];
  if (node == null) return null;
  if (node.role == NodeRole.result) {
    final String? src = node.sourceNodeId;
    return src == null ? null : byId[src];
  }
  return node;
}

GalleryItemMeta galleryMetaFor(GalleryGraph graph, GalleryIndex index, GalleryItem item) {
  final CanvasNode? config = galleryConfigNodeOf(graph, item);
  if (config == null) return GalleryItemMeta.empty;
  final Map<String, CanvasNode> byId = <String, CanvasNode>{
    for (final CanvasNode n in graph.nodesOf(item.canvasId)) n.id: n,
  };
  final List<GalleryKeyframeRef> keyframes = <GalleryKeyframeRef>[
    for (final CanvasEdge e in _inputsOf(graph, item.canvasId, config.id))
      if (byId[e.sourceNodeId] != null)
        GalleryKeyframeRef(role: e.role, sourceLabel: byId[e.sourceNodeId]!.label),
  ];
  return GalleryItemMeta(
    label: item.slotIndex == null ? config.label : '${config.label} #${item.slotIndex! + 1}',
    providerId: _providerIdOf(config),
    onNarrativeChain: index.onChain(item.canvasId, config.id),
    sequenceIndex: index.sequenceIndexOf(item.canvasId, item.relativePath),
    prompt: config.promptText,
    cameraName: config.cameraName,
    keyframes: keyframes,
    baseStylePrefix: graph.canvas(item.canvasId)?.baseStylePrefix ?? '',
    configNodeId: config.id,
  );
}

/// 血缘 · 当前线：分镜文本 → 各关键帧 / 参考输入 → 当前项。
List<GalleryLineageRow> galleryLineageFor(
  GalleryGraph graph,
  GalleryIndex index,
  GalleryItem item,
) {
  final CanvasNode? config = galleryConfigNodeOf(graph, item);
  if (config == null) return const <GalleryLineageRow>[];
  final List<CanvasNode> nodes = graph.nodesOf(item.canvasId);
  final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final CanvasNode n in nodes) n.id: n};
  final List<GalleryLineageRow> rows = <GalleryLineageRow>[];

  // 1. 叙事前驱（分镜文本）。
  final List<CanvasNode> preds = <CanvasNode>[
    for (final CanvasEdge e in graph.edgesOf(item.canvasId))
      if (e.edgeType == EdgeType.narrative && e.targetNodeId == config.id && byId[e.sourceNodeId] != null)
        byId[e.sourceNodeId]!,
  ]..sort((a, b) => a.id.compareTo(b.id));
  for (final CanvasNode p in preds) {
    rows.add(GalleryLineageRow(kind: GalleryLineageKind.shotText, name: p.label));
  }

  // 2. 关键帧 / 参考输入：上游 config 选定的那份产物。
  for (final CanvasEdge e in _inputsOf(graph, item.canvasId, config.id)) {
    final CanvasNode? u = byId[e.sourceNodeId];
    if (u == null) continue;
    final _Chosen chosen = _chosenArtifactOf(graph, nodes, u);
    rows.add(GalleryLineageRow(
      kind: GalleryLineageKind.input,
      role: e.role,
      name: chosen.label,
      thumbRelativePath: chosen.thumbPath,
      thumbCanvasId: item.canvasId,
      resultCount: chosen.count,
    ));
  }

  // 3. 当前项：同 config 的其余产物折成分支。
  final GalleryItemMeta meta = galleryMetaFor(graph, index, item);
  rows.add(GalleryLineageRow(
    kind: GalleryLineageKind.current,
    name: meta.label,
    thumbRelativePath: item.thumbnailRelativePath ?? (item.kind == GalleryItemKind.image ? item.relativePath : null),
    thumbCanvasId: item.canvasId,
    resultCount: _artifactCountOf(graph, nodes, config),
    sequenceIndex: meta.sequenceIndex,
  ));
  return rows;
}

// ── 内部 ─────────────────────────────────────────────────────────────────────

String? _providerIdOf(CanvasNode config) {
  final Object? v = config.typeConfig['provider_id'];
  return v is String && v.isNotEmpty ? v : null;
}

/// 进入 config 的 data 边，按角色（起始帧 → 结束帧 → 参考）再 sortOrder 排。
List<CanvasEdge> _inputsOf(GalleryGraph graph, String canvasId, String configId) {
  int rank(EdgeRole r) => switch (r) {
        EdgeRole.firstFrame => 0,
        EdgeRole.lastFrame => 1,
        EdgeRole.reference => 2,
      };
  final List<CanvasEdge> l = <CanvasEdge>[
    for (final CanvasEdge e in graph.edgesOf(canvasId))
      if (e.edgeType == EdgeType.data && e.targetNodeId == configId) e,
  ];
  l.sort((a, b) {
    final int r = rank(a.role).compareTo(rank(b.role));
    if (r != 0) return r;
    final int s = a.sortOrder.compareTo(b.sortOrder);
    return s != 0 ? s : a.id.compareTo(b.id);
  });
  return l;
}

int _artifactCountOf(GalleryGraph graph, List<CanvasNode> nodes, CanvasNode config) =>
    resultsFor(sourceNodeId: config.id, nodes: nodes).length + graph.slotsOf(config.id).length;

class _Chosen {
  const _Chosen({required this.label, required this.thumbPath, required this.count});
  final String label;
  final String? thumbPath;
  final int count;
}

/// 上游 config「选定」的产物：有 promoted slot 用它（名后缀 #n），否则最新 result。
_Chosen _chosenArtifactOf(GalleryGraph graph, List<CanvasNode> nodes, CanvasNode u) {
  final int count = _artifactCountOf(graph, nodes, u);
  for (final GalleryBatchSlot s in graph.slotsOf(u.id)) {
    if (s.promoted) {
      return _Chosen(label: '${u.label} #${s.slotIndex + 1}', thumbPath: s.outputUrl, count: count);
    }
  }
  final CanvasNode? latest = latestResultFor(sourceNodeId: u.id, nodes: nodes);
  return _Chosen(
    label: u.label,
    thumbPath: latest?.thumbnailUrl ?? latest?.imageUrl,
    count: count,
  );
}
