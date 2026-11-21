// 左栏素材页「参考库」段的纯函数：筛选 / 类别计数 / 视角列表，以及「当〈类别〉参考」的可用判据与同类替换规则。
//
// 纯函数，无 Flutter 依赖、不读 provider；文案映射（置灰原因、服务商名、上限 N）在调用方。
//
// 「当参考」判据按顺序判，命中第一条即停：
//   1. 选中数不是 1，或选中的 id 已不在节点表里 ⇒ noSelection；
//   2. 不是图像 / 视频配置节点（shot 也算这种：生成侧只读图像 / 视频配置的入边）⇒ notConfig；
//   3. 这个节点此刻用的服务商（与检查器 / 提示词条同一条链：util/generate_gate.dart）不收参考图，
//      或解析不出 / 已不在能力表里 ⇒ providerNoRefs；
//   4. 目标的 data/reference 入边里，源节点类别与本次相同的边 = 替换集；其中有源节点条目 id 相同的 ⇒ alreadyAttached；
//   5. 替换集为空、且现有 data/reference 入边数 ≥ maxRefImages ⇒ budgetFull。
//      只按边数算，与生成侧截断同一口径；挂载角色图的配额由检查器另外提示（ref_image_budget.dart），这里不重复算。
//      同类替换不占新名额，所以替换集非空时不判。
//
// 边表由画布边控制器提供，已不含软删的边，这里不再筛「在世」。
import '../../../../core/constants/import_keys.dart';
import '../../../../core/models/provider_capabilities.dart';
import '../../../../core/models/reference_item.dart';
import '../../models/canvas_edge.dart';
import '../../models/canvas_node.dart';
import '../../util/generate_gate.dart';

/// query 是否命中 [item]：先 trim，空 = 全部命中；否则按 searchText 子串匹配，大小写不敏感。
bool _matchesQuery(ReferenceItem item, String normalizedQuery) =>
    normalizedQuery.isEmpty || item.searchText.toLowerCase().contains(normalizedQuery);

String _normalizeQuery(String query) => query.trim().toLowerCase();

/// [all] 里属于 [category]、命中 [query]（与 [angle]，非空时）的条目，保持原顺序。
///
/// [angle] 只对姿势有意义（只有姿势带视角）；别的类别调用方传 null。
List<ReferenceItem> filterReferenceItems(
  List<ReferenceItem> all, {
  required ReferenceCategory category,
  String query = '',
  String? angle,
}) {
  final String q = _normalizeQuery(query);
  return all
      .where(
        (ReferenceItem item) =>
            item.category == category &&
            _matchesQuery(item, q) &&
            (angle == null || item.angle == angle),
      )
      .toList(growable: false);
}

/// 各类别命中 [query] 的条数（类别 chip 上的数字）；三个类别都有键，没命中的是 0。不看视角。
Map<ReferenceCategory, int> referenceCounts(
  List<ReferenceItem> all, {
  String query = '',
}) {
  final String q = _normalizeQuery(query);
  final Map<ReferenceCategory, int> counts = <ReferenceCategory, int>{
    for (final ReferenceCategory c in ReferenceCategory.values) c: 0,
  };
  for (final ReferenceItem item in all) {
    if (_matchesQuery(item, q)) counts[item.category] = counts[item.category]! + 1;
  }
  return counts;
}

/// 姿势条目里实际出现的视角，按首次出现的顺序去重；没有视角（null / 空串）的跳过。
List<String> referenceAngles(List<ReferenceItem> all) {
  final Set<String> seen = <String>{};
  final List<String> angles = <String>[];
  for (final ReferenceItem item in all) {
    if (item.category != ReferenceCategory.pose) continue;
    final String? angle = item.angle;
    if (angle == null || angle.isEmpty) continue;
    if (seen.add(angle)) angles.add(angle);
  }
  return angles;
}

/// 「当参考」点不动的原因（判据顺序见文件头）。
enum ReferenceAttachBlock {
  /// 没有恰好选中一个节点，或选中的已不在画布上。
  noSelection,

  /// 选中的不是图像 / 视频配置节点（含 shot）。
  notConfig,

  /// 当前服务商不收参考图（maxRefImages <= 0），或解析不出 / 已不在能力表里。
  providerNoRefs,

  /// 参考图已满，且没有同类别的旧参考库图可替换。
  budgetFull,
}

/// 可以「当参考」时的执行方案。
///
/// [replaceEdgeIds]：要断开的同类别旧参考边（新边与它们在一个事务里换掉，旧导入节点不删）。
/// [alreadyAttached]：同一张已经挂着——调用方什么也不改，只出胶囊。
typedef ReferenceAttachPlan = ({
  String targetNodeId,
  Set<String> replaceEdgeIds,
  bool alreadyAttached,
});

/// 把 [item] 当参考连到选中节点：block 与 plan 恰好一个非空。
({ReferenceAttachBlock? block, ReferenceAttachPlan? plan}) planReferenceAttach({
  required ReferenceItem item,
  required Set<String> selectedIds,
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  required List<ProviderCapabilities> capabilities,
  required String? lastUsedImageProviderId,
  required String? lastUsedVideoProviderId,
}) {
  ({ReferenceAttachBlock? block, ReferenceAttachPlan? plan}) blocked(
    ReferenceAttachBlock b,
  ) =>
      (block: b, plan: null);

  // 1. 恰好一个、且还在画布上。
  if (selectedIds.length != 1) return blocked(ReferenceAttachBlock.noSelection);
  final Map<String, CanvasNode> byId = <String, CanvasNode>{
    for (final CanvasNode n in nodes) n.id: n,
  };
  final CanvasNode? target = byId[selectedIds.single];
  if (target == null) return blocked(ReferenceAttachBlock.noSelection);

  // 2. 图像 / 视频配置节点。
  final bool isConfig = target.role == NodeRole.config &&
      (target.type == CanvasNodeType.image || target.type == CanvasNodeType.video);
  if (!isConfig) return blocked(ReferenceAttachBlock.notConfig);

  // 3. 服务商收参考图。上次使用按节点类型取（视频 / 图像各记各的，与提示词条同口径）。
  final Object? saved = target.typeConfig['provider_id'];
  final String? providerId = resolveConfigProviderId(
    savedProviderId: saved is String ? saved : null,
    lastUsedProviderId: target.type == CanvasNodeType.video
        ? lastUsedVideoProviderId
        : lastUsedImageProviderId,
    candidates: configProviderCandidates(target.type, capabilities),
  );
  ProviderCapabilities? caps;
  for (final ProviderCapabilities c in capabilities) {
    if (c.providerId == providerId) {
      caps = c;
      break;
    }
  }
  if (caps == null || caps.maxRefImages <= 0) {
    return blocked(ReferenceAttachBlock.providerNoRefs);
  }

  // 4. 目标的 data/reference 入边；同类别的进替换集，同一条目 ⇒ 已经是这张。
  final List<CanvasEdge> refEdges = edges
      .where(
        (CanvasEdge e) =>
            e.targetNodeId == target.id &&
            e.edgeType == EdgeType.data &&
            e.role == EdgeRole.reference,
      )
      .toList(growable: false);
  final Set<String> replaceEdgeIds = <String>{};
  bool alreadyAttached = false;
  for (final CanvasEdge e in refEdges) {
    final CanvasNode? source = byId[e.sourceNodeId];
    if (source == null) continue;
    if (source.typeConfig[ImportKeys.referenceCategory] != item.category.name) continue;
    replaceEdgeIds.add(e.id);
    if (source.typeConfig[ImportKeys.referenceItemId] == item.id) alreadyAttached = true;
  }

  // 5. 新增一张才占名额。
  if (replaceEdgeIds.isEmpty && refEdges.length >= caps.maxRefImages) {
    return blocked(ReferenceAttachBlock.budgetFull);
  }

  return (
    block: null,
    plan: (
      targetNodeId: target.id,
      replaceEdgeIds: replaceEdgeIds,
      alreadyAttached: alreadyAttached,
    ),
  );
}
