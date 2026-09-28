// 画廊选中集 / 缩略图尺寸档：都是用户的工作状态，keepAlive——切标签、切项目再回来不能丢。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_selection.dart';

final gallerySelectionProvider =
    StateProvider.family<GallerySelection, String>(
  (ref, projectId) => GallerySelection.none,
  name: 'gallerySelectionProvider',
);

/// 稿的「中 / 大 / 特大」：只改网格列数。
enum GalleryThumbSize {
  medium(5),
  large(4),
  xlarge(3);

  const GalleryThumbSize(this.columns);
  final int columns;
}

final galleryThumbSizeProvider = StateProvider<GalleryThumbSize>(
  (ref) => GalleryThumbSize.medium,
  name: 'galleryThumbSizeProvider',
);
