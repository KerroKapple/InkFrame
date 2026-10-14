// 左栏「素材」页的纯函数：分段（本画布 / 项目全部）、类型计数与过滤、网格标签。
//
// 数据是画廊那一份（galleryGraphProvider → galleryControllerProvider 的项目级产物），这里只做派生，
// 不读库。网格标签的「源配置名」取画廊的 galleryConfigNodeOf（result 节点走 sourceNodeId，批量 slot
// 先经它挂的 result 容器），与画廊信息栏同一口径。
import 'package:flutter/foundation.dart';

import '../../../gallery/models/gallery_graph.dart';
import '../../../gallery/models/gallery_item.dart';
import '../../../gallery/util/gallery_meta.dart';
import '../../models/canvas_node.dart';

/// 分段：本画布 / 项目全部。
enum AssetScope { canvas, project }

/// 类型 chip：全部 / 图片 / 视频。
enum AssetKindFilter { all, image, video }

/// 三个 chip 的计数（随分段变）。
typedef AssetCounts = ({int all, int image, int video});

/// 分段过滤：本画布 = 只留 [canvasId] 的产物；项目全部 = 原样。保持画廊的聚合序（新 → 旧）。
List<GalleryItem> assetsInScope(
  List<GalleryItem> items, {
  required AssetScope scope,
  required String canvasId,
}) =>
    switch (scope) {
      AssetScope.project => items,
      AssetScope.canvas => <GalleryItem>[
          for (final GalleryItem i in items)
            if (i.canvasId == canvasId) i,
        ],
    };

AssetCounts countAssets(List<GalleryItem> items) {
  int image = 0;
  int video = 0;
  for (final GalleryItem i in items) {
    switch (i.kind) {
      case GalleryItemKind.image:
        image++;
      case GalleryItemKind.video:
        video++;
    }
  }
  return (all: items.length, image: image, video: video);
}

/// 类型过滤（在分段之后）。
List<GalleryItem> assetsOfKind(List<GalleryItem> items, AssetKindFilter kind) =>
    switch (kind) {
      AssetKindFilter.all => items,
      AssetKindFilter.image => <GalleryItem>[
          for (final GalleryItem i in items)
            if (i.kind == GalleryItemKind.image) i,
        ],
      AssetKindFilter.video => <GalleryItem>[
          for (final GalleryItem i in items)
            if (i.kind == GalleryItemKind.video) i,
        ],
    };

/// 网格标签的两段：源配置节点 + take 序号。界面拼成「源配置名 · 成片」或「源配置名 · take N」。
@immutable
class AssetCaption {
  const AssetCaption({this.config, this.take});

  /// 源 config 节点；来源节点已经不在（孤儿产物）时为 null，界面回落到类型名。
  final CanvasNode? config;

  /// 同一 config 名下不止一个产物时，本产物按生成时间从早到晚的序号（1 起）；只有一个时为 null =「成片」。
  final int? take;
}

/// 每个产物（按 [galleryItemKey]）的标签。
///
/// take 在**传入的全部产物**里编号（调用方给的是整个项目的产物）——切分段 / 类型只改「显示哪些格」，
/// 同一格的号不会跟着变。孤儿产物（找不到源 config）各自成片，不互相编号。
Map<String, AssetCaption> assetCaptions(
  GalleryGraph graph,
  List<GalleryItem> items,
) {
  final Map<String, CanvasNode?> configOf = <String, CanvasNode?>{};
  final Map<String, List<GalleryItem>> byConfig = <String, List<GalleryItem>>{};
  for (final GalleryItem item in items) {
    final CanvasNode? config = galleryConfigNodeOf(graph, item);
    configOf[galleryItemKey(item)] = config;
    if (config != null) {
      (byConfig['${item.canvasId}|${config.id}'] ??= <GalleryItem>[]).add(item);
    }
  }
  final Map<String, int> takeOf = <String, int>{};
  for (final List<GalleryItem> group in byConfig.values) {
    if (group.length < 2) continue;
    final List<GalleryItem> oldestFirst = <GalleryItem>[...group]..sort(_byCreation);
    for (int i = 0; i < oldestFirst.length; i++) {
      takeOf[galleryItemKey(oldestFirst[i])] = i + 1;
    }
  }
  return <String, AssetCaption>{
    for (final GalleryItem item in items)
      galleryItemKey(item): AssetCaption(
        config: configOf[galleryItemKey(item)],
        take: takeOf[galleryItemKey(item)],
      ),
  };
}

/// 生成时间从早到晚；同刻（同一批的几格）按 slot 序，再按路径——全序稳定。
int _byCreation(GalleryItem a, GalleryItem b) {
  final int byTime = a.createdAt.compareTo(b.createdAt);
  if (byTime != 0) return byTime;
  final int bySlot = (a.slotIndex ?? -1).compareTo(b.slotIndex ?? -1);
  if (bySlot != 0) return bySlot;
  return a.relativePath.compareTo(b.relativePath);
}
