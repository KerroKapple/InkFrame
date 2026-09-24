// 画廊筛选（稿的左栏四组：范围 / 类型 / 模型 / 标记）。
//
// 按 projectId 分键，keepAlive：切标签、切项目再回来，筛选还在——这是 #234 持久标签
// 外壳在真实使用里最容易翻的地方（用户点名要验的三条之一）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_item.dart';
import '../util/gallery_meta.dart';

/// 稿的「标记」组里仓库能推出来的两项（「收藏」无字段，不画）。
enum GalleryMark { currentLine, inSequence }

class GalleryFilter {
  const GalleryFilter({this.kind, this.canvasId, this.providerId, this.mark});

  final GalleryItemKind? kind;
  final String? canvasId;
  final String? providerId;
  final GalleryMark? mark;

  bool get isActive => kind != null || canvasId != null || providerId != null || mark != null;

  GalleryFilter copyWith({
    GalleryItemKind? Function()? kind,
    String? Function()? canvasId,
    String? Function()? providerId,
    GalleryMark? Function()? mark,
  }) =>
      GalleryFilter(
        kind: kind != null ? kind() : this.kind,
        canvasId: canvasId != null ? canvasId() : this.canvasId,
        providerId: providerId != null ? providerId() : this.providerId,
        mark: mark != null ? mark() : this.mark,
      );

  @override
  bool operator ==(Object other) =>
      other is GalleryFilter &&
      other.kind == kind &&
      other.canvasId == canvasId &&
      other.providerId == providerId &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(kind, canvasId, providerId, mark);
}

bool galleryFilterMatches(GalleryFilter filter, GalleryItem item, GalleryItemMeta meta) =>
    (filter.kind == null || item.kind == filter.kind) &&
    (filter.canvasId == null || item.canvasId == filter.canvasId) &&
    (filter.providerId == null || meta.providerId == filter.providerId) &&
    (filter.mark == null ||
        switch (filter.mark!) {
          GalleryMark.currentLine => meta.onNarrativeChain,
          GalleryMark.inSequence => meta.sequenceIndex != null,
        });

/// [metaOf] 缺省时模型 / 标记轴当作全部不命中以外的「无信息」——只按类型与画布过滤。
List<GalleryItem> filterGalleryItems(
  List<GalleryItem> items,
  GalleryFilter filter, {
  GalleryItemMeta Function(GalleryItem item)? metaOf,
}) =>
    <GalleryItem>[
      for (final GalleryItem item in items)
        if (galleryFilterMatches(filter, item, metaOf?.call(item) ?? GalleryItemMeta.empty)) item,
    ];

final galleryFilterProvider = StateProvider.family<GalleryFilter, String>(
  (ref, projectId) => const GalleryFilter(),
  name: 'galleryFilterProvider',
);
