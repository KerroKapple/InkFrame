// GalleryFilter（GA-3）：画廊筛选状态 + 纯内存过滤。
//
// 手写不可变模型（三字段小对象,freezed 反而拖 build_runner 地雷面）；
// query 只匹配 canvasName（prompt 搜索明确 non-goal,见卡面）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_item.dart';

class GalleryFilter {
  const GalleryFilter({this.kind, this.canvasId, this.query = ''});

  /// null = 全部类型。
  final GalleryItemKind? kind;

  /// null = 全部画布。
  final String? canvasId;

  /// 匹配 canvasName（大小写不敏感,trim 后空串视为未激活）。
  final String query;

  bool get isActive =>
      kind != null || canvasId != null || query.trim().isNotEmpty;

  GalleryFilter copyWith({
    GalleryItemKind? Function()? kind,
    String? Function()? canvasId,
    String? query,
  }) =>
      GalleryFilter(
        kind: kind != null ? kind() : this.kind,
        canvasId: canvasId != null ? canvasId() : this.canvasId,
        query: query ?? this.query,
      );

  @override
  bool operator ==(Object other) =>
      other is GalleryFilter &&
      other.kind == kind &&
      other.canvasId == canvasId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(kind, canvasId, query);
}

/// 纯函数过滤：三轴 AND;保持入参顺序。
List<GalleryItem> filterGalleryItems(
  List<GalleryItem> items,
  GalleryFilter filter,
) {
  final q = filter.query.trim().toLowerCase();
  return <GalleryItem>[
    for (final item in items)
      if ((filter.kind == null || item.kind == filter.kind) &&
          (filter.canvasId == null || item.canvasId == filter.canvasId) &&
          (q.isEmpty || item.canvasName.toLowerCase().contains(q)))
        item,
  ];
}

/// 画廊筛选状态（screen-scoped:离开画廊即复位）。
final galleryFilterProvider =
    StateProvider.autoDispose<GalleryFilter>((ref) => const GalleryFilter(),
        name: 'galleryFilterProvider');
