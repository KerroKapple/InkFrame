// OutlinePanel：左栏「大纲」页（画布重设计稿 main.js「左栏面板」panelOutline）。
//
// 面板头「大纲」+ 画布切换胶囊（有活动项目才画）→ 筛选框（名称或提示词，不区分大小写）→ 分组列表。
// 分组由 util/outline_model.dart 的 buildCanvasOutline 产出，这里只渲染：
//   - 组头 26（上外边距 6）：泳道色点 8×8 圆角 2（手动 tint → 风格词推断 → control，与泳道底色同一
//     口径）+ 泳道名 + 等宽计数「N 镜」；「未分泳道」「未入链」没有色点，未入链的计数只写数字。
//   - 镜头行 40：序号（等宽 10 号、宽 16，链序两位补零，未入链不画）| 44×25 缩略（最新产物；没有产物 =
//     thumb 底 + 类型图标）| 名称 / 类型 | 状态（node_card.dart 的 nodeStatusOf，与节点卡同一判据）。
//     选中行 surface5 底。
//   - 产物子行 26：「└」+ 28×16 缩略 + 「成片 · 图像 / 视频」，名下多于 1 个时「 · 共 N 个」；
//     有活动 job 时再加一行「生成中…」（缩略位是 thumb 色空块）。
// 点镜头行 / 产物子行 = 在画布上单选该节点并把它移到视口中心（left_rail_actions.dart）。
// 空态：画布上没有配置节点时，面板体里居中一行说明。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_icon.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../../theme/primitives/ink_activatable.dart';
import '../../../../theme/tokens.dart';
import '../../../gallery/widgets/gallery_actions.dart' show galleryResolveFile;
import '../../../generation/models/job_state.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/active_project.dart';
import '../../models/canvas_edge.dart';
import '../../models/canvas_node.dart';
import '../../models/style_lane.dart';
import '../../providers/canvas_edges_controller.dart';
import '../../providers/canvas_lanes_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/node_active_job.dart';
import '../../util/lane_tint.dart';
import '../../util/outline_model.dart';
import '../node_card.dart'
    show NodeStatus, NodeStatusKind, configMainText, nodeDisplayName, nodeStatusOf;
import 'canvas_switcher.dart';
import 'left_panel_parts.dart';
import 'left_rail_actions.dart';

/// 进行中图标转一圈的时长（与通知卡的进行中图标同速）。
const Duration _kSpinTurn = Duration(milliseconds: 900);

class OutlinePanel extends ConsumerStatefulWidget {
  const OutlinePanel({super.key, required this.canvasId});

  final String canvasId;

  /// 筛选框的测试锚点。
  static const Key filterKey = ValueKey<String>('leftRail-outline-filter');

  /// 某个配置节点的镜头行。
  static Key shotKey(String nodeId) =>
      ValueKey<String>('leftRail-outline-shot-$nodeId');

  /// 某个配置节点名下的产物子行。
  static Key artifactKey(String nodeId) =>
      ValueKey<String>('leftRail-outline-artifact-$nodeId');

  /// 某个配置节点的「生成中…」子行。
  static Key generatingKey(String nodeId) =>
      ValueKey<String>('leftRail-outline-generating-$nodeId');

  /// 组头：lane 组带泳道 id，另两组只有种类。
  static Key groupKey(OutlineGroupKind kind, {String? laneId}) =>
      ValueKey<String>('leftRail-outline-group-${kind.name}-${laneId ?? ''}');

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final String canvasId = widget.canvasId;
    final ProjectRef? project = ref.watch(activeProjectProvider);
    final AsyncValue<List<CanvasNode>> nodesAsync =
        ref.watch(canvasNodesControllerProvider(canvasId));
    final List<CanvasEdge> edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasEdge>[];
    final List<StyleLane> lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
            const <StyleLane>[];

    final Widget body;
    if (!nodesAsync.hasValue) {
      // 节点还没到：不先画一句「画布上还没有配置节点」再闪掉。
      body = const SizedBox.shrink();
    } else {
      final CanvasOutline outline = buildCanvasOutline(
        nodes: nodesAsync.requireValue,
        edges: edges,
        lanes: lanes,
        query: _filter.text,
        nameOf: (CanvasNode n) => nodeDisplayName(context, n),
        promptOf: configMainText,
      );
      body = outline.configCount == 0
          ? LeftPanelNote(l.leftRailOutlineEmpty)
          : ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final OutlineGroup g in outline.groups) ...<Widget>[
                  _GroupHeader(
                    key: OutlinePanel.groupKey(g.kind, laneId: g.lane?.id),
                    group: g,
                  ),
                  for (final OutlineShot s in g.shots)
                    _ShotBlock(
                      key: ValueKey<String>('leftRail-outline-block-${s.node.id}'),
                      canvasId: canvasId,
                      projectId: project?.id,
                      shot: s,
                    ),
                ],
              ],
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeftPanelHeader(
          title: l.leftRailOutline,
          trailing: project == null
              ? null
              : CanvasSwitcher(canvasId: canvasId, project: project),
        ),
        LeftPanelFilterField(
          key: OutlinePanel.filterKey,
          controller: _filter,
          hint: l.leftRailOutlineFilterHint,
          onChanged: (_) => setState(() {}),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// 组头：26 高、上外边距 6、左右 12；色点 + 组名（11 号 fg5）+ 等宽计数（10 号 fg6）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.group});

  final OutlineGroup group;

  static const double height = 26;
  static const double dot = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final StyleLane? lane = group.lane;
    final String label = switch (group.kind) {
      OutlineGroupKind.lane =>
        (lane == null || lane.label.isEmpty) ? l.laneUntitled : lane.label,
      OutlineGroupKind.unassigned => l.leftRailGroupNoLane,
      OutlineGroupKind.unchained => l.leftRailGroupNotInSequence,
    };
    final int n = group.shots.length;
    // 未入链的不是序列里的镜，计数只写数字（稿）。
    final String count = group.kind == OutlineGroupKind.unchained
        ? n.toString()
        : l.leftRailGroupShotCount(n);
    return Padding(
      padding: const EdgeInsets.only(top: InkSpacing.s6),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Row(
          children: <Widget>[
            if (lane != null) ...<Widget>[
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  // 与泳道底色（lane_background）同一口径：手动 tint → 风格词推断 → control。
                  color: effectiveLaneTint(
                        tintColor: lane.tintColor,
                        stylePrompt: lane.stylePrompt,
                      ) ??
                      c.control,
                  borderRadius: BorderRadius.circular(InkRadius.xs),
                ),
              ),
              const SizedBox(width: InkSpacing.s6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.meta.copyWith(color: c.fg5),
              ),
            ),
            const SizedBox(width: InkSpacing.s6),
            Text(count, style: t.monoSmall.copyWith(color: c.fg6)),
          ],
        ),
      ),
    );
  }
}

/// 一镜：镜头行 + （有产物）产物子行 + （有活动 job）「生成中…」子行。
class _ShotBlock extends ConsumerWidget {
  const _ShotBlock({
    super.key,
    required this.canvasId,
    required this.projectId,
    required this.shot,
  });

  final String canvasId;
  final String? projectId;
  final OutlineShot shot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CanvasNode node = shot.node;
    final CanvasNode? latest = shot.latest;
    final JobState? job = ref.watch(nodeActiveJobProvider(node.id));
    // 只订阅「这两个节点选没选中」：选中换到别的行时，不相干的行不重建。
    final (bool shotSelected, bool artifactSelected) = ref.watch(
      canvasSelectionControllerProvider(canvasId).select(
        (Set<String> s) => (
          s.contains(node.id),
          latest != null && s.contains(latest.id),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ShotRow(
          canvasId: canvasId,
          projectId: projectId,
          shot: shot,
          status: nodeStatusOf(node, job: job, hasArtifact: latest != null),
          selected: shotSelected,
          onTap: () => focusNodeOnCanvas(ref, canvasId: canvasId, node: node),
        ),
        if (latest != null)
          _ArtifactRow(
            key: OutlinePanel.artifactKey(node.id),
            canvasId: canvasId,
            projectId: projectId,
            result: latest,
            count: shot.artifactCount,
            selected: artifactSelected,
            onTap: () => focusNodeOnCanvas(ref, canvasId: canvasId, node: latest),
          ),
        if (job != null) _GeneratingRow(key: OutlinePanel.generatingKey(node.id)),
      ],
    );
  }
}

/// 镜头行：40 高、左右 12、间距 8；选中 surface5 底。
class _ShotRow extends StatelessWidget {
  const _ShotRow({
    required this.canvasId,
    required this.projectId,
    required this.shot,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String canvasId;
  final String? projectId;
  final OutlineShot shot;
  final NodeStatus status;
  final bool selected;
  final VoidCallback onTap;

  static const double height = 40;

  /// 序号列宽；子行用同一宽度缩进，「└」正对本行缩略图的左沿（稿 padding-left 36 = 12 + 16 + 8）。
  static const double numberWidth = 16;
  static const double thumbWidth = 44;
  static const double thumbHeight = 25;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final CanvasNode node = shot.node;
    final int? seq = shot.sequence;
    final String name = nodeDisplayName(context, node);
    return InkActivatable(
      key: OutlinePanel.shotKey(node.id),
      onTap: onTap,
      semanticLabel: name,
      selected: selected,
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        color: selected ? c.surface5 : null,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: numberWidth,
              child: seq == null
                  ? null
                  : Text(
                      seq.toString().padLeft(2, '0'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: t.monoSmall.copyWith(
                        color: selected ? c.accent : c.fg5,
                      ),
                    ),
            ),
            const SizedBox(width: InkSpacing.sm),
            _Thumb(
              canvasId: canvasId,
              projectId: projectId,
              result: shot.latest,
              width: thumbWidth,
              height: thumbHeight,
              outlined: true,
              placeholder: Center(
                child: InkIcon(
                  _typeGlyph(node.type),
                  size: InkIconSize.xs,
                  color: c.fg6,
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: selected ? c.fg1 : c.fg2),
                  ),
                  Text(
                    _typeLabel(l, node.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.micro.copyWith(color: c.fg6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: InkSpacing.sm),
            _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}

/// 行尾状态：进行中 = 转圈 + 百分比（accent）；排队中（fg5）；有产物 = success 勾；就绪 / 草稿（fg6）。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final NodeStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    switch (status.kind) {
      case NodeStatusKind.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Spin(
              child: InkIcon(
                InkGlyph.progress,
                size: InkIconSize.xs,
                color: c.accent,
              ),
            ),
            const SizedBox(width: InkSpacing.xs),
            Text(
              '${status.percent ?? 0}%',
              style: t.monoSmall.copyWith(color: c.accent),
            ),
          ],
        );
      case NodeStatusKind.queued:
        return Text(
          l.canvasRenderQueueStatusQueued,
          style: t.micro.copyWith(color: c.fg5),
        );
      case NodeStatusKind.done:
        return InkIcon(
          InkGlyph.success,
          size: InkIconSize.s14,
          color: c.success,
          semanticLabel: l.nodeStatusDone,
        );
      case NodeStatusKind.ready:
        return Text(
          l.leftRailStatusReady,
          style: t.micro.copyWith(color: c.fg6),
        );
      case NodeStatusKind.draft:
        return Text(
          l.leftRailStatusDraft,
          style: t.micro.copyWith(color: c.fg6),
        );
      case NodeStatusKind.pending:
        // 只有 result 节点会是「等待中」；大纲只列配置节点，这一支到不了。
        return Text(
          l.nodeStatusPending,
          style: t.micro.copyWith(color: c.fg6),
        );
    }
  }
}

/// 产物子行：「└」+ 28×16 缩略 + 「成片 · 图像」（多于 1 个时「 · 共 N 个」）。点 = 定位这个产物节点。
class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({
    super.key,
    required this.canvasId,
    required this.projectId,
    required this.result,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String canvasId;
  final String? projectId;
  final CanvasNode result;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String kind = result.videoUrl != null
        ? l.leftRailArtifactVideo
        : l.leftRailArtifactImage;
    final String label =
        count > 1 ? l.leftRailArtifactCount(kind, count) : kind;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      builder: (BuildContext context, bool hovered, bool focused) => _ChildRow(
        selected: selected,
        thumb: _Thumb(
          canvasId: canvasId,
          projectId: projectId,
          result: result,
          width: _ChildRow.thumbWidth,
          height: _ChildRow.thumbHeight,
          outlined: false,
          placeholder: const SizedBox.shrink(),
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.meta.copyWith(color: c.fg4),
        ),
      ),
    );
  }
}

/// 「生成中…」子行：缩略位是 thumb 色空块；不可点（还没有可定位的产物节点）。
class _GeneratingRow extends StatelessWidget {
  const _GeneratingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return _ChildRow(
      selected: false,
      thumb: Container(
        width: _ChildRow.thumbWidth,
        height: _ChildRow.thumbHeight,
        decoration: BoxDecoration(
          color: c.thumbFill,
          borderRadius: BorderRadius.circular(InkRadius.xs),
        ),
      ),
      label: Text(
        context.l10n.inspectorStatusRunning,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.meta.copyWith(color: c.fg4),
      ),
    );
  }
}

/// 子行骨架：26 高、左右 12；序号列宽的空位 + 8 →「└」→ 8 → 缩略 → 8 → 文字。
class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.selected,
    required this.thumb,
    required this.label,
  });

  final bool selected;
  final Widget thumb;
  final Widget label;

  static const double height = 26;
  static const double thumbWidth = 28;
  static const double thumbHeight = 16;

  /// 稿 content-box：10 + 1px 左 / 下边。
  static const double elbow = 11;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      color: selected ? c.surface5 : null,
      child: Row(
        children: <Widget>[
          const SizedBox(width: _ShotRow.numberWidth),
          const SizedBox(width: InkSpacing.sm),
          // 稿 margin-top: -8px：在行里居中后整体上提，竖线去接上一行；等价于在它下方垫 8。
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.sm),
            child: Container(
              width: elbow,
              height: elbow,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.control),
                  bottom: BorderSide(color: c.control),
                ),
              ),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          thumb,
          const SizedBox(width: InkSpacing.sm),
          Expanded(child: label),
        ],
      ),
    );
  }
}

/// 产物缩略：图片画 image_url，视频画已落库的首帧缩略（thumbnail_url）；文件解析与画廊 / ⌘K 同款
/// （galleryResolveFile）。没有产物 / 没有项目上下文 / 文件坏了 → [placeholder]。
class _Thumb extends ConsumerWidget {
  const _Thumb({
    required this.canvasId,
    required this.projectId,
    required this.result,
    required this.width,
    required this.height,
    required this.outlined,
    required this.placeholder,
  });

  final String canvasId;
  final String? projectId;
  final CanvasNode? result;
  final double width;
  final double height;

  /// 镜头行的缩略带 1px outline（画在盒内，盒子仍是 [width]×[height]）；子行的不带。
  final bool outlined;
  final Widget placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final String? rel = result?.thumbnailUrl ?? result?.imageUrl;
    final String? pid = projectId;
    final File? file = (rel == null || pid == null)
        ? null
        : galleryResolveFile(
            ref,
            projectId: pid,
            canvasId: canvasId,
            relativePath: rel,
          );
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.thumbFill,
        borderRadius: BorderRadius.circular(InkRadius.xs),
      ),
      foregroundDecoration: outlined
          ? BoxDecoration(
              border: Border.all(color: c.outline),
              borderRadius: BorderRadius.circular(InkRadius.xs),
            )
          : null,
      child: file == null
          ? placeholder
          : Image.file(
              file,
              fit: BoxFit.cover,
              // LB-23：按显示尺寸缩略解码，别把原图整张塞进 ImageCache。
              cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// 进行中图标转圈；减弱动效（MediaQuery.disableAnimations）下不转——与通知卡同一口径。
class _Spin extends StatefulWidget {
  const _Spin({required this.child});

  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _turns =
      AnimationController(vsync: this, duration: _kSpinTurn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turns.stop();
    } else if (!_turns.isAnimating) {
      unawaited(_turns.repeat());
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turns, child: widget.child);
}

/// 没有产物时缩略位上的类型图标：与工具条建节点、节点卡缩小态同一组图标。
InkGlyph _typeGlyph(CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => InkGlyph.imageConfig,
      CanvasNodeType.video => InkGlyph.videoConfig,
      CanvasNodeType.shot => InkGlyph.shot,
      CanvasNodeType.text => InkGlyph.text,
    };

/// 第二行的类型：图像配置 / 视频配置 / 镜头 / 文本。
String _typeLabel(AppLocalizations l, CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => l.leftRailTypeImageConfig,
      CanvasNodeType.video => l.leftRailTypeVideoConfig,
      CanvasNodeType.shot => l.leftRailTypeShot,
      CanvasNodeType.text => l.canvasNodeTextType,
    };
