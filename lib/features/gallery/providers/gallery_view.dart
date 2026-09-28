// 画廊的派生视图：图 → 索引 → 每个产物的 meta → 按筛选过滤后的列表。
//
// 全是同步派生（Provider，非 Future），上游 galleryGraphProvider / galleryControllerProvider
// 未就绪时给空值；界面按 galleryControllerProvider 的 AsyncValue 决定 loading / error 态。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';
import '../models/gallery_selection.dart';
import '../util/gallery_meta.dart';
import 'gallery_controller.dart';
import 'gallery_filter.dart';
import 'gallery_graph_provider.dart';
import 'gallery_selection.dart';

final galleryIndexProvider = Provider.autoDispose.family<GalleryIndex, String>((ref, projectId) {
  final GalleryGraph graph = ref.watch(galleryGraphProvider(projectId)).valueOrNull ?? GalleryGraph.empty;
  return GalleryIndex.build(graph);
}, name: 'galleryIndexProvider');

/// key（galleryItemKey）→ meta。
final galleryMetaProvider =
    Provider.autoDispose.family<Map<String, GalleryItemMeta>, String>((ref, projectId) {
  final GalleryGraph graph = ref.watch(galleryGraphProvider(projectId)).valueOrNull ?? GalleryGraph.empty;
  final GalleryIndex index = ref.watch(galleryIndexProvider(projectId));
  final List<GalleryItem> items = ref.watch(galleryControllerProvider(projectId)).valueOrNull ?? const <GalleryItem>[];
  return Map<String, GalleryItemMeta>.unmodifiable(<String, GalleryItemMeta>{
    for (final GalleryItem item in items) galleryItemKey(item): galleryMetaFor(graph, index, item),
  });
}, name: 'galleryMetaProvider');

/// 筛选后的产物列表（保持聚合序）。
final galleryFilteredItemsProvider =
    Provider.autoDispose.family<List<GalleryItem>, String>((ref, projectId) {
  final List<GalleryItem> items = ref.watch(galleryControllerProvider(projectId)).valueOrNull ?? const <GalleryItem>[];
  final GalleryFilter filter = ref.watch(galleryFilterProvider(projectId));
  final Map<String, GalleryItemMeta> meta = ref.watch(galleryMetaProvider(projectId));
  return filterGalleryItems(
    items,
    filter,
    metaOf: (GalleryItem i) => meta[galleryItemKey(i)] ?? GalleryItemMeta.empty,
  );
}, name: 'galleryFilteredItemsProvider');

/// 锚点对应的产物（选中集为空 / 锚点已不在列表里 → null）。
final galleryAnchorItemProvider = Provider.autoDispose.family<GalleryItem?, String>((ref, projectId) {
  final String? anchor =
      ref.watch(gallerySelectionProvider(projectId).select((GallerySelection s) => s.anchor));
  if (anchor == null) return null;
  final List<GalleryItem> items = ref.watch(galleryControllerProvider(projectId)).valueOrNull ?? const <GalleryItem>[];
  for (final GalleryItem i in items) {
    if (galleryItemKey(i) == anchor) return i;
  }
  return null;
}, name: 'galleryAnchorItemProvider');
