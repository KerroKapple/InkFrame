// galleryGraphProvider：一次读出项目里画廊要的全部数据（画布 / 节点 / 连线 / 成功 slot）。
//
// 这是画廊唯一的读库入口：GalleryController 的产物列表从它派生，筛选计数 / 右栏 / 血缘
// 也从它算。脏刷新（GalleryTab）invalidate 的是它，controller 跟着级联重算。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../models/gallery_graph.dart';

final galleryGraphProvider =
    FutureProvider.autoDispose.family<GalleryGraph, String>((ref, projectId) async {
  final canvasRepo = await ref.watch(canvasRepositoryProvider.future);
  final nodeRepo = await ref.watch(nodeRepositoryProvider.future);
  final edgeRepo = await ref.watch(edgeRepositoryProvider.future);
  final batchRepo = await ref.watch(batchResultRepositoryProvider.future);

  final List<GalleryCanvasInfo> canvases = <GalleryCanvasInfo>[
    for (final row in await canvasRepo.listByProject(projectId))
      if (row[CanvasCol.id] != null)
        GalleryCanvasInfo(
          id: row[CanvasCol.id]!.toString(),
          name: row.optString(CanvasCol.name) ?? '',
          baseStylePrefix: row.optString(CanvasCol.baseStylePrefix) ?? '',
        ),
  ];

  // 各画布并发拉取节点与连线，避免串行 N+1。
  final List<List<Map<String, Object?>>> nodeRows =
      await Future.wait(canvases.map((c) => nodeRepo.listByCanvas(c.id)));
  final List<List<Map<String, Object?>>> edgeRows =
      await Future.wait(canvases.map((c) => edgeRepo.listByCanvas(c.id)));

  final Map<String, List<CanvasNode>> nodesByCanvas = <String, List<CanvasNode>>{};
  final Map<String, List<CanvasEdge>> edgesByCanvas = <String, List<CanvasEdge>>{};
  for (int i = 0; i < canvases.length; i++) {
    nodesByCanvas[canvases[i].id] =
        List<CanvasNode>.unmodifiable(nodeRows[i].map(CanvasNodeMapping.fromRow));
    edgesByCanvas[canvases[i].id] =
        List<CanvasEdge>.unmodifiable(edgeRows[i].map(CanvasEdgeMapping.fromRow));
  }

  final Map<String, List<GalleryBatchSlot>> slotsByNode = <String, List<GalleryBatchSlot>>{};
  for (final row in await batchRepo.listSuccessByProject(projectId)) {
    final String? url = row.optString(BatchResultCol.outputUrl);
    final String? canvasId = row.optId(NodeCol.canvasId);
    final int? slot = row.optInt(BatchResultCol.slotIndex);
    final DateTime? createdAt = _asUtc(row[BatchResultCol.createdAt]);
    if (url == null || url.isEmpty || canvasId == null || slot == null || createdAt == null) {
      continue;
    }
    final String nodeId = row.reqId(BatchResultCol.nodeId);
    (slotsByNode[nodeId] ??= <GalleryBatchSlot>[]).add(GalleryBatchSlot(
      nodeId: nodeId,
      canvasId: canvasId,
      slotIndex: slot,
      outputUrl: url,
      createdAt: createdAt,
      promoted: row[BatchResultCol.promoted] == true,
    ));
  }
  for (final List<GalleryBatchSlot> l in slotsByNode.values) {
    l.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
  }

  return GalleryGraph(
    canvases: List<GalleryCanvasInfo>.unmodifiable(canvases),
    nodesByCanvas: Map<String, List<CanvasNode>>.unmodifiable(nodesByCanvas),
    edgesByCanvas: Map<String, List<CanvasEdge>>.unmodifiable(edgesByCanvas),
    slotsByNode: Map<String, List<GalleryBatchSlot>>.unmodifiable(slotsByNode),
  );
}, name: 'galleryGraphProvider');

DateTime? _asUtc(Object? v) => switch (v) {
      final DateTime d => d.toUtc(),
      final String s => DateTime.tryParse(s)?.toUtc(),
      _ => null,
    };
