// 角色引用计数（P4）：角色库行的「M 处引用」与编辑框「被引用」chip 的唯一口径。
//
// 【只数 config 节点】result 节点的 type_config 是生成时从 config 整份拷过来的，
// 把它也数进去，每跑一次生成引用数就翻一倍——那不是"被几处用了"，是"生成过几次"。
// 【跨项目所有画布】角色是项目级的，一个角色可能挂在别的画布上，只数当前画布会偏小。
// 【按节点 id 去重】同一节点在图里只应出现一次；去重是防御，也顺带吃掉
// character_ids 数组里重复写同一个 id 的情况。
//
// 数据来源复用 galleryGraphProvider——它已经是"全项目 canvas + node"的只读投影，
// 不为这个计数再加仓储方法、更不加迁移。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gallery/models/gallery_graph.dart';
import '../../gallery/providers/gallery_graph_provider.dart';
import '../models/canvas_node.dart';

/// config 节点 type_config 里挂载角色的键（内部协议字面量，不 i18n）。
const String kCharacterIdsKey = 'character_ids';

/// 一个 config 节点挂了哪些角色 id。非法 / 空值剔除，保序去重。
Set<String> characterIdsOf(CanvasNode node) {
  final Object? raw = node.typeConfig[kCharacterIdsKey];
  if (raw is! List) return const <String>{};
  final Set<String> ids = <String>{};
  for (final Object? e in raw) {
    final String id = e?.toString() ?? '';
    if (id.isNotEmpty) ids.add(id);
  }
  return ids;
}

/// 角色 id → 引用它的 config 节点列表（画布顺序 → 画布内节点顺序，稳定）。
/// 纯函数：入参是只读投影，出参只依赖入参，可脱离 Riverpod 单测。
Map<String, List<CanvasNode>> indexCharacterUsages(GalleryGraph graph) {
  final Map<String, List<CanvasNode>> byCharacter = <String, List<CanvasNode>>{};
  final Map<String, Set<String>> seenNodes = <String, Set<String>>{};
  for (final GalleryCanvasInfo canvas in graph.canvases) {
    for (final CanvasNode node in graph.nodesOf(canvas.id)) {
      if (node.role != NodeRole.config) continue;
      for (final String id in characterIdsOf(node)) {
        if (!(seenNodes[id] ??= <String>{}).add(node.id)) continue;
        (byCharacter[id] ??= <CanvasNode>[]).add(node);
      }
    }
  }
  return byCharacter;
}

/// 项目内每个角色被哪些 config 节点引用。计数 = 列表长度。
final characterUsageProvider = FutureProvider.autoDispose
    .family<Map<String, List<CanvasNode>>, String>((ref, projectId) async {
      final GalleryGraph graph = await ref.watch(
        galleryGraphProvider(projectId).future,
      );
      return indexCharacterUsages(graph);
    }, name: 'characterUsageProvider');
