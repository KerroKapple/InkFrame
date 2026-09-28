// GalleryController：项目维度产物聚合（M3 素材库首切片）。
//
// 数据源 = galleryGraphProvider（画布 / 节点 / 成功 slot 一次读出）；这里只把图变成
// 扁平的 GalleryItem 列表：
//   1) result 节点主产物（image_url / video_url），节点优先占据去重键 '$canvasId|$path'
//   2) 批量成功 slot（仓储侧已过滤 status / 软删）
// 排序：createdAt 倒序 → relativePath → canvasId → nodeId（全序稳定）。
// 脏刷新（GalleryTab）invalidate 的是 galleryGraphProvider，本 provider 级联重算。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas/models/canvas_node.dart';
import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';
import 'gallery_graph_provider.dart';

final galleryControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
  GalleryController,
  List<GalleryItem>,
  String
>(GalleryController.new, name: 'galleryControllerProvider');

class GalleryController
    extends AutoDisposeFamilyAsyncNotifier<List<GalleryItem>, String> {
  @override
  Future<List<GalleryItem>> build(String projectId) async {
    final GalleryGraph graph = await ref.watch(galleryGraphProvider(projectId).future);
    return galleryItemsFromGraph(graph);
  }
}

/// 纯函数：图 → 产物列表（单测直接打这里）。
List<GalleryItem> galleryItemsFromGraph(GalleryGraph graph) {
  final items = <GalleryItem>[];
  final seen = <String>{}; // '$canvasId|$relativePath'

  for (final GalleryCanvasInfo canvas in graph.canvases) {
    for (final CanvasNode node in graph.nodesOf(canvas.id)) {
      if (node.role != NodeRole.result) continue;
      final String? path = node.videoUrl ?? node.imageUrl;
      if (path == null) continue;
      final DateTime? createdAt = node.createdAt?.toUtc();
      if (createdAt == null) continue;
      if (!seen.add('${canvas.id}|$path')) continue;
      items.add(
        GalleryItem(
          kind: node.videoUrl != null ? GalleryItemKind.video : GalleryItemKind.image,
          relativePath: path,
          canvasId: canvas.id,
          canvasName: canvas.name,
          nodeId: node.id,
          createdAt: createdAt,
          durationMs: node.durationMs,
          thumbnailRelativePath: node.thumbnailUrl,
        ),
      );
    }
  }

  for (final List<GalleryBatchSlot> slots in graph.slotsByNode.values) {
    for (final GalleryBatchSlot slot in slots) {
      if (!seen.add('${slot.canvasId}|${slot.outputUrl}')) continue;
      items.add(
        GalleryItem(
          kind: GalleryItemKind.image,
          relativePath: slot.outputUrl,
          canvasId: slot.canvasId,
          canvasName: graph.canvas(slot.canvasId)?.name ?? '',
          nodeId: slot.nodeId,
          createdAt: slot.createdAt,
          slotIndex: slot.slotIndex,
        ),
      );
    }
  }

  items.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) return byTime;
    final byPath = a.relativePath.compareTo(b.relativePath);
    if (byPath != 0) return byPath;
    // 同刻同路径(跨画布同名文件):补 canvasId/nodeId 保证全序稳定。
    final byCanvas = a.canvasId.compareTo(b.canvasId);
    if (byCanvas != 0) return byCanvas;
    return a.nodeId.compareTo(b.nodeId);
  });
  return List.unmodifiable(items);
}
