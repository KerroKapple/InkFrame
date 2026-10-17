// 新建菜单（画布重设计稿 › 画布交互「拖线到空白处 → 建节点」）的菜单项判据——纯函数，不碰 widget / provider。
//
// 四个入口（从出端口拖到空白处 / 双击空白 / Tab / 空白处右键「新建…」）开的是同一个菜单，区别只在有没有
// 「从哪张卡拖出来」的连线上下文：
//   - 带上下文：源带图像产物 ⇒ 当首帧 / 当尾帧（建视频配置）、当参考（建图像配置），各连一条对应角色的
//     data 边；源有叙事锚点 ⇒「下一镜」（建与锚点同类型的配置节点 + 锚点 → 新节点的 narrative 边）。
//     两组之间一条分隔线。
//     视频产物不出前三项——首帧 / 尾帧 / 参考是图像语义。
//   - 不带上下文：图像配置 · 视频配置 · 文本 · 镜头 · 泳道。
//
// 【叙事边只连配置节点】仓库里建 narrative 边的只有两处：导入剧本（shot → shot）与 shot 检查器的
// 「用本镜备注生成」（shot → image / video 配置）。读侧全把叙事链当成「配置节点的序列」：export_order
// 头注写明 result 节点「自己不在 narrative 链上」，sequence_builder 不让 result 独立成镜，左栏大纲只列链上的
// 配置节点。text 节点进了链也成不了一镜（没有备注、没有产物，buildSequence 直接跳过）。所以「下一镜」的叙事
// 边一律连在 shot / image / video 的**配置节点**上（[narrativeAnchorOf]）：从配置卡拖出来就是它自己；从产物
// 卡拖出来（稿上的示例源正是「镜头 01 · 成片」）是它的来源配置节点。文本卡、来源已删的孤儿产物没有锚点，
// 不出这一项。
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import 'node_artifacts.dart';

/// 新建菜单里的一项。
enum CreateMenuAction {
  /// 当首帧 · 新建视频配置：源 → 新节点一条 data 边，角色首帧。
  asFirstFrame,

  /// 当尾帧 · 新建视频配置：data 边，角色尾帧。
  asLastFrame,

  /// 当参考 · 新建图像配置：data 边，角色参考。
  asReference,

  /// 下一镜（叙事）：与源同类型的配置节点 + narrative 边（源 → 新）。
  nextShot,

  /// 图像配置（I）。
  imageConfig,

  /// 视频配置（G）。
  videoConfig,

  /// 文本（T）。
  text,

  /// 镜头。
  shot,

  /// 泳道（F）：不建节点，开「新建泳道」框。
  lane,
}

/// 一项要连的线：源 → 新节点。
typedef CreateMenuEdge = ({EdgeType type, EdgeRole role});

/// 不带连线上下文时的菜单项（与浮动工具条的建节点组同序）。
const List<CreateMenuAction> kPlainCreateActions = <CreateMenuAction>[
  CreateMenuAction.imageConfig,
  CreateMenuAction.videoConfig,
  CreateMenuAction.text,
  CreateMenuAction.shot,
  CreateMenuAction.lane,
];

/// 带图像产物时的三项。
const List<CreateMenuAction> kImageSourceActions = <CreateMenuAction>[
  CreateMenuAction.asFirstFrame,
  CreateMenuAction.asLastFrame,
  CreateMenuAction.asReference,
];

/// 源节点「带图像产物」：image 类型（配置或产物都算——图像配置连到视频上当首帧，是连线模式里
/// 早就有的智能默认），或名下最新的产物是一张图。视频产物 / 视频配置不算。
bool sourceCarriesImage(CanvasNode source, List<CanvasNode> nodes) {
  if (source.type == CanvasNodeType.image) return true;
  return latestResultFor(sourceNodeId: source.id, nodes: nodes)?.imageUrl != null;
}

/// 「下一镜」的叙事锚点（narrative 边从它连出，新节点与它同类型）：源自己是 shot / image / video 的配置
/// 节点就是它；源是产物，就是它还在 [nodes] 里的来源配置节点（同样不能是文本）。没有锚点 ⇒ null，
/// 菜单不出「下一镜」（见头注）。
CanvasNode? narrativeAnchorOf(CanvasNode source, List<CanvasNode> nodes) {
  bool continuable(CanvasNode n) => n.role == NodeRole.config && n.type != CanvasNodeType.text;
  if (continuable(source)) return source;
  final String? origin = source.role == NodeRole.result ? source.sourceNodeId : null;
  if (origin == null) return null;
  for (final CanvasNode n in nodes) {
    if (n.id == origin) return continuable(n) ? n : null;
  }
  return null;
}

/// 菜单分组：组与组之间画分隔线，空组不出。[source] 为 null ⇒ 不带上下文的五项。
List<List<CreateMenuAction>> createMenuGroups({
  CanvasNode? source,
  List<CanvasNode> nodes = const <CanvasNode>[],
}) {
  if (source == null) return const <List<CreateMenuAction>>[kPlainCreateActions];
  return <List<CreateMenuAction>>[
    if (sourceCarriesImage(source, nodes)) kImageSourceActions,
    if (narrativeAnchorOf(source, nodes) != null) const <CreateMenuAction>[CreateMenuAction.nextShot],
  ];
}

/// 这一项要建的节点类型；泳道不建节点 ⇒ null。「下一镜」= 叙事锚点的类型（没有源 / 没有锚点也是 null）。
CanvasNodeType? createdNodeType(
  CreateMenuAction action, {
  CanvasNode? source,
  List<CanvasNode> nodes = const <CanvasNode>[],
}) =>
    switch (action) {
      CreateMenuAction.asFirstFrame ||
      CreateMenuAction.asLastFrame ||
      CreateMenuAction.videoConfig =>
        CanvasNodeType.video,
      CreateMenuAction.asReference || CreateMenuAction.imageConfig => CanvasNodeType.image,
      CreateMenuAction.nextShot => source == null ? null : narrativeAnchorOf(source, nodes)?.type,
      CreateMenuAction.text => CanvasNodeType.text,
      CreateMenuAction.shot => CanvasNodeType.shot,
      CreateMenuAction.lane => null,
    };

/// 这一项的边从哪个节点连出：「下一镜」从叙事锚点（产物 ⇒ 它的来源配置节点），其余从源本身；
/// 没有源 ⇒ null。
String? createdEdgeSourceId(
  CreateMenuAction action, {
  CanvasNode? source,
  List<CanvasNode> nodes = const <CanvasNode>[],
}) {
  if (source == null) return null;
  if (action == CreateMenuAction.nextShot) return narrativeAnchorOf(source, nodes)?.id;
  return source.id;
}

/// 「下一镜」新叙事边的 sortOrder：锚点 [anchorId] 现有出向 narrative 边的 sortOrder 最大值 + 1；一条都没有 ⇒ 0。
///
/// 叙事链给同源的分叉按 (sortOrder, 边 id) 排（narrative_order.dart）。不设就是默认的 0，与锚点已有的分支同序，
/// 谁先谁后落到边 id（UUID）上——新镜可能插到已有分支前面，序列与导出的顺序跟着变。取最大值 + 1（不是条数：
/// 已有的序号可能不连续），新镜固定排在已有分支之后，与「下一镜」接在后面的字面意思一致；已有分支的相对顺序
/// 不动，也不去改别的边。
int nextNarrativeSortOrder({
  required String anchorId,
  required List<CanvasEdge> edges,
}) {
  int? highest;
  for (final CanvasEdge e in edges) {
    if (e.sourceNodeId != anchorId || e.edgeType != EdgeType.narrative) continue;
    if (highest == null || e.sortOrder > highest) highest = e.sortOrder;
  }
  return highest == null ? 0 : highest + 1;
}

/// 这一项要连的线（源 → 新节点）；不连线的项 ⇒ null。
CreateMenuEdge? createdEdge(CreateMenuAction action) => switch (action) {
      CreateMenuAction.asFirstFrame => (type: EdgeType.data, role: EdgeRole.firstFrame),
      CreateMenuAction.asLastFrame => (type: EdgeType.data, role: EdgeRole.lastFrame),
      CreateMenuAction.asReference => (type: EdgeType.data, role: EdgeRole.reference),
      CreateMenuAction.nextShot => (type: EdgeType.narrative, role: EdgeRole.reference),
      CreateMenuAction.imageConfig ||
      CreateMenuAction.videoConfig ||
      CreateMenuAction.text ||
      CreateMenuAction.shot ||
      CreateMenuAction.lane =>
        null,
    };
