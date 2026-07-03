// GalleryController —— 项目维度产物聚合（M3 素材库首切片，只读）。
//
// 聚合两路现有数据（无新表）：
//   1. 项目各画布的 result 节点 type_config（image_url / video_url）
//   2. batch_results 成功 slot（output_url，跨画布一次查询）
// 去重：slot 与节点主图同 (canvasId, path) 只留节点一条；createdAt 倒序。
// 坏行策略：created_at 缺失/类型不符 → 跳过该行；节点列级损坏（fromRow 抛
// InkError/FormatException）不逐行兜——由画廊 error 态 + 重试兜底。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import '../../canvas/models/canvas_node.dart';
import '../models/gallery_item.dart';

final galleryControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
  GalleryController,
  List<GalleryItem>,
  String
>(GalleryController.new, name: 'galleryControllerProvider');

class GalleryController
    extends AutoDisposeFamilyAsyncNotifier<List<GalleryItem>, String> {
  @override
  Future<List<GalleryItem>> build(String projectId) async {
    final canvasRepo = await ref.watch(canvasRepositoryProvider.future);
    final nodeRepo = await ref.watch(nodeRepositoryProvider.future);
    final batchRepo = await ref.watch(batchResultRepositoryProvider.future);

    final canvasNames = <String, String>{
      for (final row in await canvasRepo.listByProject(projectId))
        if (row[CanvasCol.id] != null)
          row[CanvasCol.id]!.toString(): row.optString(CanvasCol.name) ?? '',
    };

    final items = <GalleryItem>[];
    final seen = <String>{}; // '$canvasId|$relativePath'

    // 1) result 节点主产物（节点优先占据去重键）。各画布并发拉取,避免串行 N+1。
    final nodeRowsByCanvas = await Future.wait(
      canvasNames.keys.map(nodeRepo.listByCanvas),
    );
    final canvasEntries = canvasNames.entries.toList();
    for (var i = 0; i < canvasEntries.length; i++) {
      final entry = canvasEntries[i];
      for (final row in nodeRowsByCanvas[i]) {
        final node = CanvasNodeMapping.fromRow(row);
        if (node.role != NodeRole.result) continue;
        final path = node.videoUrl ?? node.imageUrl;
        if (path == null) continue;
        final createdAt = _asUtc(row[NodeCol.createdAt]);
        if (createdAt == null) continue;
        if (!seen.add('${entry.key}|$path')) continue;
        items.add(
          GalleryItem(
            kind: node.videoUrl != null
                ? GalleryItemKind.video
                : GalleryItemKind.image,
            relativePath: path,
            canvasId: entry.key,
            canvasName: entry.value,
            nodeId: node.id,
            createdAt: createdAt,
            durationMs: node.durationMs,
          ),
        );
      }
    }

    // 2) 批量成功 slot（仓储侧已过滤 status/软删）
    for (final row in await batchRepo.listSuccessByProject(projectId)) {
      final url = row.optString(BatchResultCol.outputUrl);
      final canvasId = row.optId(NodeCol.canvasId);
      final createdAt = _asUtc(row[BatchResultCol.createdAt]);
      if (url == null || url.isEmpty || canvasId == null || createdAt == null) {
        continue;
      }
      if (!seen.add('$canvasId|$url')) continue;
      items.add(
        GalleryItem(
          kind: GalleryItemKind.image,
          relativePath: url,
          canvasId: canvasId,
          canvasName: canvasNames[canvasId] ?? '',
          nodeId: row.reqId(BatchResultCol.nodeId),
          createdAt: createdAt,
          slotIndex: row.optInt(BatchResultCol.slotIndex),
        ),
      );
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
}

DateTime? _asUtc(Object? v) => switch (v) {
  final DateTime d => d.toUtc(),
  final String s => DateTime.tryParse(s)?.toUtc(),
  _ => null,
};
