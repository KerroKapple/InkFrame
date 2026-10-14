// NodeCard：画布上的单个节点卡片（Workspace v2 稿）。
//
// 224 宽：18px 标题行（名称 500 + 类型 10px）| 6 | 16:9 图区（4px 圆角 + 1px outline，
// 选中 accent；outline 画在盒子外一圈）| 6 | 16px 状态行（状态文字 + 等宽 meta）。
// 无外框、无阴影、无标题条底色。端口在图区垂直中心向外偏移 5px：入=空心，出=实心。
//
// 端口按需显示（画布重设计稿 › 画布交互）：悬停 / 选中 / 连线模式（起点或候选）时两侧
// 都亮出来，供连线；平时只留真挂着连线的那一侧（[NodeCard.hasInEdge] /
// [NodeCard.hasOutEdge]，由画布按存量边 + 产出线算好传进来）——没连线的卡片不再
// 挂着两颗悬空的小圆点。悬停态是本卡片的局部状态（MouseRegion），不进 provider。
//
// 稿上没有卡片角落的连线 / 删除小圆钮：连线走工具条「连线」（选中节点后），
// 删除走 Delete 键——[onStartLink] / [onDelete] 保留在 API 上供上层继续持有，
// 本卡片不再渲染它们。
//
// 图区内容：result 节点 = 缩略图（image / video）；还没出图 / 文件丢了的 result 占位 =
// 左下角一行 11px 小字（[_ThumbLabel]）。
// config 节点（提示词条与节点文字稿）：正文（提示词 / 文本 / 镜头备注）贴图区顶部、最多三行，
// 12/1.55 fg2；图区底部另起一行 10px fg5 摘要——video config 是「起始帧 ← X · 结束帧 ← Y ·
// 运镜」，image config 是镜头语言摘要（设了才画）。以前 video 有入边时摘要会顶掉提示词，
// 现在两样都画。画布缩到 kCompactCardScale（0.6）以下时正文与摘要都收起，只留居中的类型
// 图标——那个缩放下几行小字糊成一团，谁也读不了。
//
// 拖拽（HI-13）：位移累积在本卡片局部状态（Transform.translate），每帧只重建
// 自身；onPanEnd 把累计位移一次性回调 onDragEnd，由上层提交 controller。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../providers/canvas_compact_cards.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/node_active_job.dart';
import '../providers/node_drag_delta.dart';
import '../util/camera_labels.dart';
import '../util/lane_tint.dart';
import 'video_node_body.dart';

class NodeCard extends ConsumerStatefulWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDragEnd,
    this.lane,
    this.onStartLink,
    this.onDelete,
    this.isLinkSource = false,
    this.isLinkCandidate = false,
    this.hasInEdge = false,
    this.hasOutEdge = false,
  });

  final CanvasNode node;

  /// 所在泳道（Lanes 稿改动 3）：卡片底部一行 6px 色点 + 「继承 X」——跨道拖动改写 lane_id 时
  /// 用户能立刻看见风格变了。无道节点为 null，该行留空（高度照旧预留，卡片尺寸恒定）。
  final StyleLane? lane;
  final bool selected;
  final VoidCallback onTap;

  /// 拖拽结束时回调一次累计位移（落点提交）；拖拽中不触发。
  final void Function(Offset totalDelta) onDragEnd;

  /// 进入连线模式的入口（本卡片不渲染，见头注）。
  final VoidCallback? onStartLink;

  /// 删除入口（本卡片不渲染，见头注）。
  final VoidCallback? onDelete;

  /// 本节点是否为当前连线模式的起点（UI 高亮）。
  final bool isLinkSource;

  /// 连线模式下此节点是否为合法目标（非起点 → 高亮为点击候选）。
  final bool isLinkCandidate;

  /// 入口这一侧真挂着一条画出来的线（存量边或推导的产出线）→ 入端口常驻。
  final bool hasInEdge;

  /// 出口这一侧真挂着一条画出来的线 → 出端口常驻。
  final bool hasOutEdge;

  static const double thumbHeight = 126; // 224 × 9 / 16

  /// 入 / 出端口圆点的测试锚点（每张卡片内唯一）。
  static const Key inPortKey = ValueKey<String>('node-card-in-port');
  static const Key outPortKey = ValueKey<String>('node-card-out-port');

  /// config 卡图区正文（提示词 / 文本 / 镜头备注）的测试锚点。
  static const Key configTextKey = ValueKey<String>('node-card-config-text');

  /// config 卡图区底部摘要行的测试锚点。
  static const Key configSummaryKey = ValueKey<String>('node-card-config-summary');

  /// 缩小态居中类型图标的测试锚点。
  static const Key compactGlyphKey = ValueKey<String>('node-card-compact-glyph');

  @override
  ConsumerState<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends ConsumerState<NodeCard> {
  bool _dragging = false;

  /// 鼠标悬停在卡片上——两侧端口都亮出来（供连线）。
  bool _hovered = false;

  /// 拖拽中的累计位移——只重建本卡片，不推全画布 state。
  Offset _dragOffset = Offset.zero;

  /// 拖拽期捕获的广播口——dispose 兜底清残留用（dispose 后 ref 不可用）。
  StateController<NodeDragDelta?>? _dragBroadcast;

  @override
  void dispose() {
    // 拖拽中被删（如 Delete 快捷键）不会走 onPanEnd，广播会残留脏值；
    // 微任务延后清理避开 widget 树锁，容器已销毁时静默放弃。
    final broadcast = _dragBroadcast;
    final nodeId = widget.node.id;
    if (_dragging && broadcast != null) {
      scheduleMicrotask(() {
        try {
          if (broadcast.state?.nodeId == nodeId) broadcast.state = null;
        } on StateError {
          // ProviderContainer 已 dispose（应用退出/测试收尾）——无需清理。
        }
      });
    }
    super.dispose();
  }

  void _endDrag({required bool commit}) {
    final total = _dragOffset;
    setState(() {
      _dragging = false;
      _dragOffset = Offset.zero;
    });
    // 先清广播再提交落点：连线层切回 controller 座标，避免一帧双重位移。
    ref.read(nodeDragDeltaProvider.notifier).state = null;
    if (commit && total != Offset.zero) {
      widget.onDragEnd(total);
    }
  }

  void _broadcastDrag() {
    final broadcast = ref.read(nodeDragDeltaProvider.notifier);
    _dragBroadcast = broadcast;
    broadcast.state = (nodeId: widget.node.id, delta: _dragOffset);
  }

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final highlighted =
        widget.selected || widget.isLinkSource || widget.isLinkCandidate;
    final Color edge = highlighted ? colors.accent : colors.outline;
    final Color outPort = highlighted ? colors.accent : colors.fg5;
    // 稿：shot 节点只有出端口。
    final bool hasIn =
        !(node.type == CanvasNodeType.shot && node.role == NodeRole.config);
    // 端口按需显示：悬停 / 选中 / 连线模式两侧都亮；平时只留挂着线的那一侧。
    final bool revealPorts = _hovered || highlighted;
    final bool showInPort = hasIn && (revealPorts || widget.hasInEdge);
    final bool showOutPort = revealPorts || widget.hasOutEdge;

    return Transform.translate(
      offset: _dragOffset,
      child: MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          // opaque：卡片内任何位置（含空图区）都可点选 / 拖拽。
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: (_) {
            setState(() {
              _dragging = true;
              _dragOffset = Offset.zero;
            });
            _broadcastDrag();
          },
          onPanUpdate: (d) {
            setState(() => _dragOffset += d.delta);
            _broadcastDrag();
          },
          onPanEnd: (_) => _endDrag(commit: true),
          onPanCancel: () => _endDrag(commit: false),
          child: SizedBox(
            width: kNodeCardSize.width,
            height: kNodeCardSize.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 18,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            nodeDisplayName(context, node),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.bodyStrong.copyWith(color: colors.fg1),
                          ),
                        ),
                        const SizedBox(width: InkSpacing.sm),
                        Text(node.type.name, style: typo.micro.copyWith(color: colors.fg5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: NodeCard.thumbHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(InkRadius.sm),
                          child: ColoredBox(
                            color: colors.thumbFill,
                            child: _NodeBody(
                              node: node,
                              resolver: ref.watch(fileResolverServiceProvider),
                            ),
                          ),
                        ),
                      ),
                      // 稿用的是 CSS outline：画在盒子【外】一圈，不占布局。
                      Positioned(
                        left: -1,
                        top: -1,
                        right: -1,
                        bottom: -1,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: edge),
                              borderRadius: BorderRadius.circular(InkRadius.s5),
                            ),
                          ),
                        ),
                      ),
                      if (showInPort)
                        Positioned(
                          left: -5,
                          top: NodeCard.thumbHeight / 2 - 5,
                          child: Container(
                            key: NodeCard.inPortKey,
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.surface1,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.fg5, width: 1.5),
                            ),
                          ),
                        ),
                      if (showOutPort)
                        Positioned(
                          right: -5,
                          top: NodeCard.thumbHeight / 2 - 5,
                          child: Container(
                            key: NodeCard.outPortKey,
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: outPort, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: _StatusRow(node: node),
                  ),
                ),
                const SizedBox(height: 5),
                // 稿：14 高继承行——6px 方色点（道的 tint）+ 「继承 X」10px fg5。
                SizedBox(
                  height: 14,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: widget.lane == null ? const SizedBox.shrink() : _InheritRow(lane: widget.lane!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 泳道继承行：色点取道的有效 tint（没有则 fg6），文字「继承 <道名>」。
class _InheritRow extends StatelessWidget {
  const _InheritRow({required this.lane});
  final StyleLane lane;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Color? tint = effectiveLaneTint(tintColor: lane.tintColor, stylePrompt: lane.stylePrompt);
    final String name = lane.label.isEmpty ? context.l10n.laneUntitled : lane.label;
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tint ?? colors.fg6,
            borderRadius: BorderRadius.circular(InkRadius.s1),
          ),
        ),
        const SizedBox(width: InkSpacing.s6),
        Expanded(
          child: Text(
            context.l10n.laneInherits(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.micro.copyWith(color: colors.fg5),
          ),
        ),
      ],
    );
  }
}

/// 显示名：空标题回退类型名。
String nodeDisplayName(BuildContext context, CanvasNode node) =>
    node.label.isEmpty ? nodeTypeLabel(context, node.type) : node.label;

/// 引用名（用户拍板）：别处引用一个节点时不重复它的类型——「镜头 01 · 图像」引用为「镜头 01」。
/// 规则：label 以「 · <本地化类型名>」结尾时去掉该尾段；其余原样。
String nodeRefName(BuildContext context, CanvasNode node) {
  final String name = nodeDisplayName(context, node);
  final String suffix = ' · ${nodeTypeLabel(context, node.type)}';
  return name.endsWith(suffix) && name.length > suffix.length
      ? name.substring(0, name.length - suffix.length)
      : name;
}

String nodeTypeLabel(BuildContext context, CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => context.l10n.canvasNodeImageType,
      CanvasNodeType.text => context.l10n.canvasNodeTextType,
      CanvasNodeType.video => context.l10n.canvasNodeVideoType,
      CanvasNodeType.shot => context.l10n.canvasNodeShotType,
    };

/// 节点状态的种类。判据只有 [nodeStatusOf] 一份：节点卡状态行与左栏大纲行共用，两处不会走岔。
enum NodeStatusKind { running, queued, done, pending, ready, draft }

/// 节点此刻的状态；[percent] 只在 running 时有值（进度 × 100 四舍五入）。
typedef NodeStatus = ({NodeStatusKind kind, int? percent});

/// 节点状态判据。
///
/// - [job]：nodeActiveJobProvider 的值（只会是非终态）。running → 进行中带百分比；
///   queued / submitting → 排队中。终态在那条 provider 里到不了，真来了按「就绪」报（与抽出前同口径）。
/// - 没有活动 job：result 节点看自己有没有产物 url（完成 / 等待中）；config 节点看
///   [hasArtifact]（名下已有产物 = 完成），再看正文（[configMainText]）——有 = 就绪、空 = 草稿。
///
/// [hasArtifact] 只有左栏大纲会传 true：节点卡的产物另有成片卡，config 卡的状态行只说草稿 / 就绪。
NodeStatus nodeStatusOf(
  CanvasNode node, {
  required JobState? job,
  bool hasArtifact = false,
}) {
  if (job != null) {
    return switch (job) {
      JobRunning(:final double progress) => (
          kind: NodeStatusKind.running,
          percent: (progress * 100).round(),
        ),
      JobQueued() || JobSubmitting() => (kind: NodeStatusKind.queued, percent: null),
      JobSucceeded() || JobFailed() || JobCancelled() => (
          kind: NodeStatusKind.ready,
          percent: null,
        ),
    };
  }
  if (node.role == NodeRole.result) {
    return (
      kind: (node.imageUrl ?? node.videoUrl) != null
          ? NodeStatusKind.done
          : NodeStatusKind.pending,
      percent: null,
    );
  }
  if (hasArtifact) return (kind: NodeStatusKind.done, percent: null);
  return (
    kind: configMainText(node) == null ? NodeStatusKind.draft : NodeStatusKind.ready,
    percent: null,
  );
}

/// 状态行：左状态文字（进行中 accent，其余 fg4），右等宽 meta（provider id / camera / txt）。
class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final NodeStatus s = nodeStatusOf(
      node,
      job: ref.watch(nodeActiveJobProvider(node.id)),
    );
    final String status = switch (s.kind) {
      NodeStatusKind.running => l.inspectorStatusRunningWithProgress(s.percent ?? 0),
      NodeStatusKind.queued => l.canvasRenderQueueStatusQueued,
      NodeStatusKind.done => l.nodeStatusDone,
      NodeStatusKind.pending => l.nodeStatusPending,
      NodeStatusKind.ready => l.nodeStatusReady,
      NodeStatusKind.draft => l.nodeStatusDraft,
    };
    final Color statusColor =
        s.kind == NodeStatusKind.running ? colors.accent : colors.fg4;

    final String meta = switch (node.type) {
      CanvasNodeType.text => 'txt',
      CanvasNodeType.shot => 'txt',
      _ => (node.typeConfig['provider_id'] as String?) ?? '',
    };

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.meta.copyWith(color: statusColor),
          ),
        ),
        const SizedBox(width: InkSpacing.sm),
        Text(meta, style: typo.monoSmall.copyWith(color: colors.fg5)),
      ],
    );
  }
}

class _NodeBody extends StatelessWidget {
  const _NodeBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    if (node.role == NodeRole.result) {
      if (node.type == CanvasNodeType.video) {
        return VideoNodeBody(node: node);
      }
      return _ResultBody(node: node, resolver: resolver);
    }
    return _ConfigBody(node: node);
  }
}

/// 图区左下角 11px fg6 说明文字（稿：padding 8 10，行高 1.45）——只剩 result 占位在用
/// （还没出图 / 文件丢了）；config 卡的正文与摘要走 [_ConfigText]。
class _ThumbLabel extends StatelessWidget {
  const _ThumbLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(InkSpacing.s10, InkSpacing.sm, InkSpacing.s10, InkSpacing.sm),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typo.meta.copyWith(color: colors.fg6),
        ),
      ),
    );
  }
}

/// config 卡图区：常态画正文 + 底部摘要行，缩小态只画居中的类型图标。
///
/// 缩小态读 [canvasCompactCardsProvider]——它只在越过阈值那一下翻转，缩放的每一帧不会
/// 把卡片拖进重建。单测里的节点可以没有 canvasId（见 CanvasNode 头注）：没有画布就谈不上
/// 缩放，按常态画。
class _ConfigBody extends ConsumerWidget {
  const _ConfigBody({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String canvasId = node.canvasId ?? '';
    final bool compact = canvasId.isNotEmpty && ref.watch(canvasCompactCardsProvider(canvasId));
    if (compact) {
      return Center(
        child: InkIcon(
          _configGlyph(node.type),
          key: NodeCard.compactGlyphKey,
          size: InkIconSize.md,
          color: context.inkColors.fg6,
        ),
      );
    }
    if (node.type == CanvasNodeType.video) return _VideoConfigText(node: node);
    final ShotLanguage lang = node.shotLanguage;
    return _ConfigText(
      text: configMainText(node),
      // 底部行：image config = 镜头语言摘要（设了才画）；text / shot 没有底部行。
      summary: node.type == CanvasNodeType.image && !lang.isEmpty
          ? shotLanguageSummary(context, lang)
          : null,
    );
  }
}

/// config 卡的正文：shot = 镜头备注，text = 正文，image / video = 提示词。
/// 去首尾空白；空串归 null（= 不画正文）。
///
/// 公开：状态判据（[nodeStatusOf] 的草稿 / 就绪）与左栏大纲的「按提示词筛选」都读这一份。
String? configMainText(CanvasNode node) {
  final String? raw = switch (node.type) {
    CanvasNodeType.shot => node.typeConfig['shot_notes'] as String?,
    CanvasNodeType.text => node.textContent,
    CanvasNodeType.image || CanvasNodeType.video => node.promptText,
  };
  final String? trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// 缩小态的类型图标：image / video / text 与工具条新建节点同一枚；shot 用「剧本」——
/// 镜头卡的正文就是从剧本拆出来的镜头备注。
InkGlyph _configGlyph(CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => InkGlyph.imageConfig,
      CanvasNodeType.video => InkGlyph.videoConfig,
      CanvasNodeType.text => InkGlyph.text,
      CanvasNodeType.shot => InkGlyph.shot,
    };

/// config 卡图区的文字排布：正文贴顶、最多三行省略，摘要单行贴底；两样都没有时图区留空。
class _ConfigText extends StatelessWidget {
  const _ConfigText({required this.text, required this.summary});

  /// 正文（已去首尾空白）；null = 不画。
  final String? text;

  /// 底部摘要行；null = 不画。
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final String? body = text;
    final String? line = summary;
    if (body == null && line == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s10, horizontal: InkSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 正文占满摘要行以外的高度并贴顶；没有正文时这块空着，摘要照样贴底。
          // 放大界面字号后三行放不下时按这块的高度裁掉，不会把摘要行挤出图区。
          Expanded(
            child: body == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      body,
                      key: NodeCard.configTextKey,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typo.body.copyWith(color: colors.fg2, height: 1.55),
                    ),
                  ),
          ),
          if (line != null)
            Text(
              line,
              key: NodeCard.configSummaryKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.micro.copyWith(color: colors.fg5),
            ),
        ],
      ),
    );
  }
}

/// video config：正文 = 提示词；底部摘要行 = 起始帧 ← X · 结束帧 ← Y · 运镜（稿）。
/// 以前有入边时摘要会顶掉提示词；现在两样都画，摘要只占底部一行。
class _VideoConfigText extends ConsumerWidget {
  const _VideoConfigText({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final String canvasId = node.canvasId ?? '';
    final List<CanvasEdge> edges = canvasId.isEmpty
        ? const <CanvasEdge>[]
        : (ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[]);
    final List<CanvasNode> nodes = canvasId.isEmpty
        ? const <CanvasNode>[]
        : (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[]);
    final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final n in nodes) n.id: n};

    final List<String> parts = <String>[];
    for (final CanvasEdge e in edges) {
      if (e.targetNodeId != node.id || e.edgeType != EdgeType.data) continue;
      final CanvasNode? src = byId[e.sourceNodeId];
      if (src == null) continue;
      final String roleLabel = switch (e.role) {
        EdgeRole.firstFrame => l.inspectorRoleFirstFrame,
        EdgeRole.lastFrame => l.inspectorRoleLastFrame,
        EdgeRole.reference => l.inspectorRoleReference,
      };
      parts.add('$roleLabel ← ${nodeRefName(context, src)}');
    }
    final CameraMovement? camera = parseCameraMovement(node.cameraName);
    if (camera != null) parts.add(cameraMovementLabel(context, camera));

    return _ConfigText(
      text: configMainText(node),
      summary: parts.isEmpty ? null : parts.join(' · '),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    final url = node.imageUrl;
    if (url == null) {
      return _ThumbLabel(context.l10n.resultNodePending);
    }
    // 单测允许 projectId/canvasId 为空 → 退化为占位（避免 PathSecurityError）。
    if (node.projectId == null || node.canvasId == null) {
      return _ThumbLabel(url);
    }

    File file;
    try {
      file = resolver.resolve(
        projectId: node.projectId!,
        canvasId: node.canvasId!,
        relativePath: url,
      );
    } on PathSecurityError {
      return _ThumbLabel(context.l10n.resultNodeImageMissing);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // ME-26：按卡片宽度解码，避免原图全尺寸进 image cache。
      cacheWidth: (kNodeCardSize.width * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => _ThumbLabel(context.l10n.resultNodeImageMissing),
    );
  }
}
