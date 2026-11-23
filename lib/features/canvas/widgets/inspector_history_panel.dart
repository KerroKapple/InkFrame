// InspectorHistoryPanel：检查器「历史」页 = 选中节点的 take 列表（画布重设计稿 main.js inspectorHistory）。
//
// 列哪些 take（新 → 旧）：
//   - 选中配置节点 ⇒ 它名下的全部产物（node_artifacts.resultsFor）；
//   - 选中产物节点 ⇒ 它的兄弟（同一个 sourceNodeId，含它自己），选中的这张高亮（surface5 底）；
//     没有来源的孤儿产物只列它自己。
// 顶部说明「<节点名> 的全部 take」：配置节点用它自己的引用名（nodeRefName）；产物节点用它来源的那个。
// 行：72×41 缩略（cover、圆角 3、1px outline）|「take N」（N 按时间正序，最早的是 take 1；名下只有一个写
//   「成片」——号由 util/take_numbers.dart 的 takeNumbersOn 给，与左栏素材页的格子同一个函数）
//   + meta（10 号 fg5）：相对时间（复用画廊的 galleryTimeAgo）· 种子（type_config 里有 seed 才写）。
// 「在用」= 这个 take 有 data 出边（首帧 / 尾帧 / 参考，往下游流）：缩略描边换 accent，右侧写「在用」。
// 「当前」= 这一镜的当前 take（固定的 ?? 最新的，判据 util/take_status.dart 的 resultTakeStatusOf）：右侧写「当前」，
//   被固定时前面画图钉（InkGlyph.pin）。其余有来源的 take 右侧一个「设为当前」按钮（InkActivatable，可 Tab / 回车），
//   走 providers/current_take_controller.dart 的 setCurrent；按钮是行里更深的那层手势，点它不触发行的「单选 + 居中」。
//   孤儿产物（没有来源，或来源配置已删 / 不在画布上）既不画「当前」也不画按钮。「当前」与「在用」是两件事（W5 之前不一定是同一张），两样都画。
// 点一行 = 单选那个产物节点并把它移到视口中心（left_rail_actions.focusNodeOnCanvas，与左栏同一条路）；
// 选中换到那张产物上之后，页签停在历史页不动（inspectorTabProvider），列表变成它的兄弟、它高亮。
// 名下没有产物：一行 fg5 说明。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../gallery/util/gallery_time.dart';
import '../../gallery/widgets/gallery_actions.dart' show galleryResolveFile;
import '../../shell/providers/active_project.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/current_take_controller.dart';
import '../util/node_artifacts.dart';
import '../util/take_numbers.dart';
import '../util/take_status.dart';
import 'left_rail/left_rail_actions.dart';
import 'node_card.dart' show nodeRefName;

class InspectorHistoryPanel extends ConsumerWidget {
  const InspectorHistoryPanel({super.key, required this.canvasId, required this.node});

  final String canvasId;

  /// 检查器此刻选中的那一个节点。
  final CanvasNode node;

  /// 缩略尺寸（稿 72×41，16:9）。
  static const double thumbWidth = 72;
  static const double thumbHeight = 41;

  /// 某个 take 行的测试锚点（挂在行的点击壳上）。
  static Key takeKey(String nodeId) => ValueKey<String>('inspector-history-take-$nodeId');

  /// 某个 take 行的「设为当前」按钮。
  static Key setCurrentKey(String nodeId) => ValueKey<String>('inspector-history-set-current-$nodeId');

  /// 某个 take 行的「当前」徽标（固定时里面有图钉）。
  static Key currentBadgeKey(String nodeId) => ValueKey<String>('inspector-history-current-$nodeId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
    final List<CanvasNode> takes = _takesOf(node, nodes);
    if (takes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(InkSpacing.s14, InkSpacing.s12, InkSpacing.s14, InkSpacing.s6),
        child: Text(l.inspectorHistoryEmpty, style: t.meta.copyWith(color: c.fg5)),
      );
    }

    final List<CanvasEdge> edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[];
    // 往下游流 = 当了别人的首帧 / 尾帧 / 参考（data 边的起点）。
    final Set<String> flowing = <String>{
      for (final CanvasEdge e in edges)
        if (e.edgeType == EdgeType.data) e.sourceNodeId,
    };
    final String? projectId = ref.watch(activeProjectProvider)?.id;
    final DateTime now = ref.watch(clockProvider).nowUtc();
    final CanvasNode owner = _ownerOf(node, nodes);
    // 来源配置还在画布上（owner 回落成产物自己 = 来源已删）：不在就不谈「当前」——
    // resultTakeStatusOf 只看 sourceNodeId，配置节点软删后产物仍带着它，画出按钮也只会 noSource、点了没反应。
    final bool sourceAlive = owner.role == NodeRole.config;
    // take 号与左栏素材页同一个函数：按时间正序、最早的是 take 1；名下只有一个 ⇒ 不在表里 =「成片」。
    final Map<String, int> takeNumbers = takeNumbersOn(nodes);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(InkSpacing.s14, InkSpacing.s12, InkSpacing.s14, InkSpacing.s6),
          child: Text(
            l.inspectorHistoryHeading(nodeRefName(context, owner)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.meta.copyWith(color: c.fg4),
          ),
        ),
        for (int i = 0; i < takes.length; i++)
          _TakeRow(
            canvasId: canvasId,
            projectId: projectId,
            take: takes[i],
            number: takeNumbers[takes[i].id],
            meta: _metaOf(l, takes[i], now),
            highlighted: takes[i].id == node.id,
            inUse: flowing.contains(takes[i].id),
            status: sourceAlive ? resultTakeStatusOf(takes[i], nodes) : null,
            onTap: () => focusNodeOnCanvas(ref, canvasId: canvasId, node: takes[i]),
            onSetCurrent: () =>
                ref.read(currentTakeControllerProvider(canvasId)).setCurrent(takes[i].id, l: l).ignore(),
          ),
      ],
    );
  }

  /// 配置节点 = 名下全部产物；产物节点 = 同一来源下的全部兄弟（含自己）；孤儿产物 = 只有它自己
  /// （它要是连产物 url 都没有，那就是空表）。
  static List<CanvasNode> _takesOf(CanvasNode node, List<CanvasNode> nodes) {
    if (node.role == NodeRole.config) return resultsFor(sourceNodeId: node.id, nodes: nodes);
    final String? source = node.sourceNodeId;
    if (source != null) return resultsFor(sourceNodeId: source, nodes: nodes);
    return (node.imageUrl ?? node.videoUrl) == null ? const <CanvasNode>[] : <CanvasNode>[node];
  }

  /// 说明行里写谁的名字：配置节点写自己；产物节点写它的来源（来源已不在画布上就写它自己）。
  static CanvasNode _ownerOf(CanvasNode node, List<CanvasNode> nodes) {
    final String? source = node.role == NodeRole.result ? node.sourceNodeId : null;
    if (source == null) return node;
    for (final CanvasNode n in nodes) {
      if (n.id == source) return n;
    }
    return node;
  }

  /// 第二行：相对时间 · 种子。都没有就是空串（不画这一行）。
  static String _metaOf(AppLocalizations l, CanvasNode take, DateTime now) {
    final DateTime? at = take.createdAt;
    final Object? seed = take.typeConfig['seed'];
    return <String>[
      if (at != null) galleryTimeAgo(l, at, now),
      if (seed is int) l.inspectorHistorySeed(seed),
    ].join(' · ');
  }
}

/// 一个 take：内边距上下 8、左右 14，间距 10；选中的这张 surface5 底。
class _TakeRow extends ConsumerWidget {
  const _TakeRow({
    required this.canvasId,
    required this.projectId,
    required this.take,
    required this.number,
    required this.meta,
    required this.highlighted,
    required this.inUse,
    required this.status,
    required this.onTap,
    required this.onSetCurrent,
  });

  final String canvasId;
  final String? projectId;
  final CanvasNode take;

  /// take 号；null =「成片」（名下只有这一个）。
  final int? number;
  final String meta;

  /// 检查器此刻选中的就是这一张（surface5 底）。
  final bool highlighted;
  final bool inUse;

  /// 它在同源兄弟里的 take 状态；null = 孤儿产物（没有来源，或来源配置已删，谈不上当前）：不画「当前」也不画按钮。
  final ResultTakeStatus? status;
  final VoidCallback onTap;

  /// 「设为当前」。
  final VoidCallback onSetCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    // 图片画 image_url，视频画已落库的首帧缩略（thumbnail_url）；解析与左栏 / 画廊同款。
    final String? rel = take.thumbnailUrl ?? take.imageUrl;
    final String? pid = projectId;
    final File? file = (rel == null || pid == null)
        ? null
        : galleryResolveFile(ref, projectId: pid, canvasId: canvasId, relativePath: rel);
    final int? n = number;
    final ResultTakeStatus? s = status;
    return InkActivatable(
      key: InspectorHistoryPanel.takeKey(take.id),
      onTap: onTap,
      selected: highlighted,
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        color: highlighted ? c.surface5 : null,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.sm),
        child: Row(
          children: <Widget>[
            Container(
              width: InspectorHistoryPanel.thumbWidth,
              height: InspectorHistoryPanel.thumbHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.thumbFill,
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              // 描边画在盒内（前景装饰），盒子仍是 72×41；在用的 take 换 accent。
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: inUse ? c.accent : c.outline),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: file == null
                  ? null
                  : Image.file(
                      file,
                      fit: BoxFit.cover,
                      // LB-23：按显示尺寸缩略解码，别把原图整张塞进 ImageCache。
                      cacheWidth: (InspectorHistoryPanel.thumbWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(width: InkSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    n == null ? l.inspectorHistoryFinal : l.inspectorHistoryTake(n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.fg2),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.micro.copyWith(color: c.fg5),
                    ),
                ],
              ),
            ),
            if (s != null && s.current) ...<Widget>[
              const SizedBox(width: InkSpacing.s10),
              Row(
                key: InspectorHistoryPanel.currentBadgeKey(take.id),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (s.pinned) ...<Widget>[
                    InkIcon(InkGlyph.pin, size: InkIconSize.s14, color: c.accent),
                    const SizedBox(width: InkSpacing.xs),
                  ],
                  Text(l.takeCurrentBadge, style: t.meta.copyWith(color: c.accent)),
                ],
              ),
            ],
            if (inUse) ...<Widget>[
              const SizedBox(width: InkSpacing.s10),
              Text(l.inspectorHistoryInUse, style: t.meta.copyWith(color: c.accent)),
            ],
            if (s != null && !s.current) ...<Widget>[
              const SizedBox(width: InkSpacing.s10),
              // 行里更深的一层手势：点它只设为当前，不冒泡成行的「单选 + 居中」。
              InkActivatable(
                key: InspectorHistoryPanel.setCurrentKey(take.id),
                onTap: onSetCurrent,
                semanticLabel: l.takeSetCurrent,
                focusRingRadius: BorderRadius.circular(InkRadius.s3),
                builder: (BuildContext context, bool hovered, bool focused) =>
                    InkSecondaryButton(l.takeSetCurrent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
