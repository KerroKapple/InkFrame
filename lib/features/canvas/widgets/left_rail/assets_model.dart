// 左栏「素材」页的纯函数：分段（本画布 / 项目全部）、删掉的不显示、类型计数与过滤、网格标签。
//
// 数据是画廊那一份（galleryGraphProvider → galleryControllerProvider 的项目级产物），这里只做派生，
// 不读库；当前画布另有画布控制器里的实时节点表，删除靠它立即生效。网格标签的「源配置名」取画廊的
// galleryConfigNodeOf（result 节点走 sourceNodeId，批量 slot 先经它挂的 result 容器），与画廊信息栏
// 同一口径。
//
// take 号：[takeNumbersOn] 是素材页格子与检查器历史页共用的那一个编号函数——每个配置节点名下有产物的
// result 节点按时间正序编号，名下只有一个时两处都写「成片」；批量 slot 不参与 take 编号，照画廊写「#n」。
import 'package:flutter/foundation.dart';

import '../../../gallery/models/gallery_graph.dart';
import '../../../gallery/models/gallery_item.dart';
import '../../../gallery/util/gallery_meta.dart';
import '../../models/canvas_node.dart';
import '../../util/node_artifacts.dart';

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

/// 删掉的不显示：[canvasId]（当前画布）的条目，节点已不在 [liveNodes]（画布控制器里的实时节点表）里的
/// 去掉——删除立即生效，不等画廊图重读。批量 slot 的 nodeId 是它挂的 result 容器，容器删了 slot 跟着走。
/// 别的画布的条目原样（手里没有它们的实时节点表）；[liveNodes] 为 null（还没载入）时不过滤。保持传入的序。
List<GalleryItem> assetsWithoutDeleted(
  List<GalleryItem> items, {
  required String canvasId,
  required List<CanvasNode>? liveNodes,
}) {
  if (liveNodes == null) return items;
  final Set<String> alive = <String>{for (final CanvasNode n in liveNodes) n.id};
  return <GalleryItem>[
    for (final GalleryItem i in items)
      if (i.canvasId != canvasId || alive.contains(i.nodeId)) i,
  ];
}

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

/// take 号——素材页的格子标签与检查器历史页共用这一个函数，两处的号不会走岔。
///
/// 同一来源（result 节点的 sourceNodeId，即它的配置节点）名下有产物的 result 节点按生成时间正序编号，
/// 最早的是 take 1；「有产物」「谁先谁后」都照 [resultsFor]（产物 url 非空；按 created_at，缺戳的垫底）。
/// 名下只有一个的不进表——它是「成片」，两处都不写号；没有来源的孤儿产物也不进表（各自成片）。
/// 批量 slot 不是 result 节点，不参与；批量的 result 容器转正之前没有产物 url，同样不参与。
/// [nodes] 是同一张画布的节点。
Map<String, int> takeNumbersOn(List<CanvasNode> nodes) {
  // 按来源分桶，桶内保持节点列表原序（resultsFor 对缺时间戳的产物按原序定先后）。
  final Map<String, List<CanvasNode>> bySource = <String, List<CanvasNode>>{};
  for (final CanvasNode n in nodes) {
    final String? source = n.sourceNodeId;
    if (n.role != NodeRole.result || source == null) continue;
    (bySource[source] ??= <CanvasNode>[]).add(n);
  }
  final Map<String, int> out = <String, int>{};
  for (final MapEntry<String, List<CanvasNode>> e in bySource.entries) {
    final List<CanvasNode> newestFirst = resultsFor(sourceNodeId: e.key, nodes: e.value);
    if (newestFirst.length < 2) continue;
    for (int i = 0; i < newestFirst.length; i++) {
      out[newestFirst[i].id] = newestFirst.length - i;
    }
  }
  return out;
}

/// 网格标签的几段：源配置节点 + take 号 / slot 号。界面拼成「源配置名 · 成片」「源配置名 · take N」，
/// 批量 slot 照画廊写「源配置名 #n」。
@immutable
class AssetCaption {
  const AssetCaption({this.config, this.take, this.slot});

  /// 源 config 节点；来源节点已经不在（孤儿产物）时为 null，界面回落到类型名。
  final CanvasNode? config;

  /// 产物节点的 take 号（[takeNumbersOn]，与检查器历史页同一个号，1 起）；名下只有它一个、没有来源、
  /// 或者是批量 slot 时为 null——节点主产物写「成片」。
  final int? take;

  /// 批量 slot 的槽位号（1 起）：不参与 take 编号，界面照画廊写「源配置名 #n」；节点主产物为 null。
  final int? slot;
}

/// 每个产物（按 [galleryItemKey]）的标签。
///
/// take 号不在产物列表上数，在**节点**上数（[takeNumbersOn]，检查器历史页用的是同一个函数）；批量 slot 不参与，
/// 写 slot 号。号只看节点，与传进来的是哪些产物无关——切分段 / 类型只改「显示哪些格」，同一格的号不会跟着变。
/// 节点表：[canvasId] 这张画布用 [canvasNodes]（画布控制器里的实时节点表——历史页读的也是它，删掉一个 take，
/// 两处的号一起变），其余画布（或 [canvasNodes] 为 null 时）用画廊图。
Map<String, AssetCaption> assetCaptions(
  GalleryGraph graph,
  List<GalleryItem> items, {
  String? canvasId,
  List<CanvasNode>? canvasNodes,
}) {
  final Map<String, Map<String, int>> takesByCanvas = <String, Map<String, int>>{};
  Map<String, int> takesOn(String id) => takesByCanvas[id] ??=
      takeNumbersOn((id == canvasId ? canvasNodes : null) ?? graph.nodesOf(id));
  return <String, AssetCaption>{
    for (final GalleryItem item in items)
      galleryItemKey(item): AssetCaption(
        config: galleryConfigNodeOf(graph, item),
        take: item.slotIndex == null ? takesOn(item.canvasId)[item.nodeId] : null,
        slot: item.slotIndex == null ? null : item.slotIndex! + 1,
      ),
  };
}
