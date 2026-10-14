// AssetsPanel：左栏「素材」页（画布重设计稿 main.js「左栏面板」panelAssets）。
//
// 面板头「素材」（不放上传键：现在没有「本地图片 → 节点」的导入路径）→ 分段「本画布 / 项目全部」→
// 类型 chip「全部 N / 图片 N / 视频 N」（N 随分段变）→ 两列网格 →「在画廊中打开全部 ›」。
// 稿上「拖进画布即建节点…」那行不画：这一轮不做拖放。
//
// 数据复用画廊：galleryControllerProvider（项目级产物）+ galleryGraphProvider（标签要的源配置节点），
// 「本画布」再按 canvasId 过滤——不另读库。派生全在 assets_model.dart（纯函数）。
// 点格子：产物在当前画布 = 单选它并移到视口中心（与大纲同一条 focusNodeOnCanvas）；在别的画布 =
// 走画廊「在画布中定位」那条路（gallery_actions.galleryLocateInCanvas：切过去再选中）。
//
// 新鲜度：画廊图不只本页 watch——画廊标签物化后常驻、角色页的引用计数（characterUsageProvider）也读它，
// 被它们保活着时，本页打开看到的可能是旧图（job 成功发生在本页没开的时候）。所以：
//   - 每次挂载（展开左栏、从别的页切过来）时图若已经活着，帧后让它失效一次——开页即是新的；没活着的话
//     本页这次 build 本来就现读，不再多读一遍。
//   - 本页开着时，本项目有 job 转成功（上一刻还不是成功、这一刻是）⇒ 帧后再失效一次（与画廊标签脏刷新
//     的入口相同）。成功的 job 会一直留在注册表里、别的 job 每跳一次进度整张表都会再发一遍，所以按前后
//     两刻比，不记账。
// 删除：当前画布的条目按画布控制器里的实时节点表过一遍（assets_model.assetsWithoutDeleted）——节点删了格子
// 立刻消失，不等画廊图重读；点格子时节点表里找不到就不选中（选中一个不存在的 id，状态栏写「选中 1」，
// 检查器却是空的）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_error_banner.dart';
import '../../../../theme/components/ink_icon.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../../theme/primitives/ink_activatable.dart';
import '../../../../theme/tokens.dart';
import '../../../gallery/models/gallery_graph.dart';
import '../../../gallery/models/gallery_item.dart';
import '../../../gallery/providers/gallery_controller.dart';
import '../../../gallery/providers/gallery_graph_provider.dart';
import '../../../gallery/util/gallery_meta.dart';
import '../../../gallery/widgets/gallery_actions.dart';
import '../../../generation/models/job_state.dart';
import '../../../generation/providers/jobs_registry.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/active_project.dart';
import '../../../shell/providers/shell_controller.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../node_card.dart' show nodeTypeLabel;
import 'assets_model.dart';
import 'left_panel_parts.dart';
import 'left_rail_actions.dart';

class AssetsPanel extends ConsumerStatefulWidget {
  const AssetsPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 分段的测试锚点。
  static Key scopeKey(AssetScope scope) =>
      ValueKey<String>('leftRail-assets-scope-${scope.name}');

  /// 类型 chip 的测试锚点。
  static Key kindKey(AssetKindFilter kind) =>
      ValueKey<String>('leftRail-assets-kind-${kind.name}');

  /// 「在画廊中打开全部」的测试锚点。
  static const Key openGalleryKey =
      ValueKey<String>('leftRail-assets-open-gallery');

  @override
  ConsumerState<AssetsPanel> createState() => _AssetsPanelState();
}

class _AssetsPanelState extends ConsumerState<AssetsPanel> {
  AssetScope _scope = AssetScope.canvas;
  AssetKindFilter _kind = AssetKindFilter.all;

  @override
  void initState() {
    super.initState();
    // 开页即是新的（见头注）：图此刻已经活着 ⇒ 是被别处保活着的，可能早于刚成功的 job，帧后让它失效一次。
    // 推到帧后：initState 跑在 build 阶段里，同步改 provider 图会被 Riverpod 断言掉。
    final ProjectRef? project = ref.read(activeProjectProvider);
    if (project != null && ref.exists(galleryGraphProvider(project.id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(galleryGraphProvider(project.id));
      });
    }
  }

  void _onJobs(List<JobState>? previous, List<JobState> next) {
    final ProjectRef? project = ref.read(activeProjectProvider);
    if (project == null) return;
    // 上一刻就已经是成功的不算新产物（成功的 job 会一直留在注册表里）。
    final Set<String> succeededBefore = <String>{
      for (final JobState j in previous ?? const <JobState>[])
        if (j is JobSucceeded) j.jobId,
    };
    bool fresh = false;
    for (final JobState j in next) {
      if (j is! JobSucceeded || succeededBefore.contains(j.jobId)) continue;
      // 拿不到 projectId（生产里不会发生）就当作可能是本项目：多刷一次远比漏刷便宜。
      if (j.projectId == null || j.projectId == project.id) fresh = true;
    }
    if (!fresh) return;
    // 推到帧后：监听回调可能落在别处的 build 里，同步改 provider 图会被 Riverpod 断言掉。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(galleryGraphProvider(project.id));
    });
  }

  /// 点格子：当前画布 = 单选 + 移到视口中心；别的画布 = 画廊的「在画布中定位」。
  void _locate(ProjectRef project, GalleryItem item) {
    final String canvasId = widget.canvasId;
    if (item.canvasId != canvasId) {
      galleryLocateInCanvas(ref, project: project, item: item);
      return;
    }
    final List<CanvasNode> nodes =
        ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final CanvasNode? node =
        nodes.where((CanvasNode n) => n.id == item.nodeId).firstOrNull;
    // 节点表里没有它（刚删掉，或画布节点还没载入）：不选中——选中一个找不到的 id，状态栏写「选中 1」，
    // 检查器却是空的。
    if (node == null) return;
    focusNodeOnCanvas(ref, canvasId: canvasId, node: node);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<JobState>>(jobsRegistryProvider, _onJobs);
    final l = context.l10n;
    final ProjectRef? project = ref.watch(activeProjectProvider);
    if (project == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LeftPanelHeader(title: l.leftRailAssets),
          Expanded(child: LeftPanelNote(l.leftRailAssetsNoProject)),
        ],
      );
    }

    final AsyncValue<List<GalleryItem>> itemsAsync =
        ref.watch(galleryControllerProvider(project.id));
    final GalleryGraph graph =
        ref.watch(galleryGraphProvider(project.id)).valueOrNull ??
            GalleryGraph.empty;
    // 本画布的实时节点表：删掉的节点，格子立刻消失（不等画廊图重读）。
    final List<CanvasNode>? liveNodes =
        ref.watch(canvasNodesControllerProvider(widget.canvasId)).valueOrNull;
    final List<GalleryItem> all = assetsWithoutDeleted(
      itemsAsync.valueOrNull ?? const <GalleryItem>[],
      canvasId: widget.canvasId,
      liveNodes: liveNodes,
    );
    final List<GalleryItem> scoped =
        assetsInScope(all, scope: _scope, canvasId: widget.canvasId);
    final AssetCounts counts = countAssets(scoped);
    final List<GalleryItem> shown = assetsOfKind(scoped, _kind);
    // take 号在本画布的实时节点表上数（与检查器历史页同一份、同一个函数），别的画布用画廊图。
    final Map<String, AssetCaption> captions = assetCaptions(
      graph,
      all,
      canvasId: widget.canvasId,
      canvasNodes: liveNodes,
    );

    final Widget body;
    if (!itemsAsync.hasValue && itemsAsync.hasError) {
      // 读库失败要显性报错：静默降级成空网格 = 谎报「还没有生成的素材」。
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: InkErrorBanner(
          message: l10nAsyncError(context, itemsAsync.error!),
        ),
      );
    } else if (!itemsAsync.hasValue) {
      body = const SizedBox.shrink();
    } else {
      body = ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpacing.s12,
                vertical: InkSpacing.lg,
              ),
              child: Text(
                l.leftRailAssetsEmpty,
                textAlign: TextAlign.center,
                style: context.inkTypography.meta
                    .copyWith(color: context.inkColors.fg5),
              ),
            )
          else
            _AssetGrid(
              items: shown,
              tileOf: (GalleryItem item) => _AssetTile(
                key: ValueKey<String>('leftRail-asset-${galleryItemKey(item)}'),
                projectId: project.id,
                item: item,
                caption: _captionOf(context, item, captions[galleryItemKey(item)]),
                onTap: () => _locate(project, item),
              ),
            ),
          _OpenGalleryLink(
            onTap: () =>
                ref.read(shellControllerProvider.notifier).openGallery(project),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeftPanelHeader(title: l.leftRailAssets),
        _ScopeSegments(
          scope: _scope,
          onChanged: (AssetScope s) => setState(() => _scope = s),
        ),
        _KindChips(
          kind: _kind,
          counts: counts,
          onChanged: (AssetKindFilter k) => setState(() => _kind = k),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// 「源配置名 · 成片」/「源配置名 · take N」；批量 slot 照画廊对 slot 的写法「源配置名 #n」（不参与 take
  /// 编号，见 util/take_numbers.dart 的 takeNumbersOn）。源配置名空着（或找不到源节点）时回落到类型名，与画廊 tile 的回落
  /// 同一口径。
  static String _captionOf(
    BuildContext context,
    GalleryItem item,
    AssetCaption? caption,
  ) {
    final l = context.l10n;
    final String label = caption?.config?.label ?? '';
    final String name = label.isNotEmpty
        ? label
        : nodeTypeLabel(
            context,
            item.kind == GalleryItemKind.video
                ? CanvasNodeType.video
                : CanvasNodeType.image,
          );
    final int? slot = caption?.slot;
    if (slot != null) return '$name #$slot';
    final int? take = caption?.take;
    return take == null ? l.leftRailAssetFinal(name) : l.leftRailAssetTake(name, take);
  }
}

/// 分段：外边距上 10 / 左右 12；26 高（border-box）；surface2 底 + outline 边 + 圆角 4；内边距 2、段间距 2。
class _ScopeSegments extends StatelessWidget {
  const _ScopeSegments({required this.scope, required this.onChanged});

  final AssetScope scope;
  final ValueChanged<AssetScope> onChanged;

  /// 稿写明 box-sizing: border-box：26 已含边框。
  static const double height = 26;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final l = context.l10n;
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s10, InkSpacing.s12, 0),
      padding: const EdgeInsets.all(InkSpacing.s2),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _Segment(
              key: AssetsPanel.scopeKey(AssetScope.canvas),
              label: l.leftRailAssetsThisCanvas,
              selected: scope == AssetScope.canvas,
              onTap: () => onChanged(AssetScope.canvas),
            ),
          ),
          const SizedBox(width: InkSpacing.s2),
          Expanded(
            child: _Segment(
              key: AssetsPanel.scopeKey(AssetScope.project),
              label: l.leftRailAssetsWholeProject,
              selected: scope == AssetScope.project,
              onTap: () => onChanged(AssetScope.project),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一段：选中 surface5 底 + fg1，未选 fg4；11 号字；圆角 3。
class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      focusRingRadius: BorderRadius.circular(InkRadius.s3),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.surface5 : null,
          borderRadius: BorderRadius.circular(InkRadius.s3),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.meta.copyWith(color: selected ? c.fg1 : c.fg4),
        ),
      ),
    );
  }
}

/// 类型 chip：外边距上 10 / 左右 12 / 下 4，间距 6。
class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.kind,
    required this.counts,
    required this.onChanged,
  });

  final AssetKindFilter kind;
  final AssetCounts counts;
  final ValueChanged<AssetKindFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget chip(AssetKindFilter k, String label) => _Chip(
          key: AssetsPanel.kindKey(k),
          label: label,
          selected: kind == k,
          onTap: () => onChanged(k),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s12,
        InkSpacing.s10,
        InkSpacing.s12,
        InkSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          chip(AssetKindFilter.all, l.leftRailAssetsKindAll(counts.all)),
          const SizedBox(width: InkSpacing.s6),
          chip(AssetKindFilter.image, l.leftRailAssetsKindImage(counts.image)),
          const SizedBox(width: InkSpacing.s6),
          chip(AssetKindFilter.video, l.leftRailAssetsKindVideo(counts.video)),
        ],
      ),
    );
  }
}

/// 胶囊 chip：20 高（+ 上下 1px 边）、圆角 999、10 号字。选中 accentWash 底 + accentWashBorder 边 + accent 字；
/// 未选 outline 边 + fg4。
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 稿 content-box：20 + 上下 1px 边。
  static const double height = 22;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      focusRingRadius: BorderRadius.circular(InkRadius.pill),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accentWash : null,
          border: Border.all(color: selected ? c.accentWashBorder : c.outline),
          borderRadius: BorderRadius.circular(InkRadius.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: t.micro.copyWith(color: selected ? c.accent : c.fg4),
        ),
      ),
    );
  }
}

/// 两列网格：行距 10、列距 8；内边距上下 8、左右 12。
class _AssetGrid extends StatelessWidget {
  const _AssetGrid({required this.items, required this.tileOf});

  final List<GalleryItem> items;
  final Widget Function(GalleryItem item) tileOf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < items.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: InkSpacing.s10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: tileOf(items[i])),
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: i + 1 < items.length
                      ? tileOf(items[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 一格：16:9 缩略（cover、圆角 3、1px outline）+ 4 + 标签（10 号 fg5，单行省略）。
/// 图片画产物本身，视频画已落库的首帧缩略；解析与画廊同款（galleryResolveFile）。
class _AssetTile extends ConsumerWidget {
  const _AssetTile({
    super.key,
    required this.projectId,
    required this.item,
    required this.caption,
    required this.onTap,
  });

  final String projectId;
  final GalleryItem item;
  final String caption;
  final VoidCallback onTap;

  /// 缩略解码宽（逻辑 px，再乘 dpr）：240 面板两列，一格约 104。
  static const double _decodeWidth = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool video = item.kind == GalleryItemKind.video;
    final String? rel = video ? item.thumbnailRelativePath : item.relativePath;
    final File? file = rel == null
        ? null
        : galleryResolveFile(
            ref,
            projectId: projectId,
            canvasId: item.canvasId,
            relativePath: rel,
          );
    // 没缩略可画时：视频给一枚类型图标，图片留 thumb 底（文件坏了同样回落）。
    final Widget placeholder = video
        ? Center(
            child: InkIcon(InkGlyph.videoConfig, size: InkIconSize.sm, color: c.fg6),
          )
        : const SizedBox.shrink();
    return InkActivatable(
      onTap: onTap,
      semanticLabel: caption,
      builder: (BuildContext context, bool hovered, bool focused) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.thumbFill,
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              // outline 画在盒子内沿：格子宽度仍撑满列；hover 时描边提一档。
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: hovered ? c.control : c.outline),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: file == null
                  ? placeholder
                  : Image.file(
                      file,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (_decodeWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
          ),
          const SizedBox(height: InkSpacing.xs),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.micro.copyWith(color: c.fg5),
          ),
        ],
      ),
    );
  }
}

/// 底部链接「在画廊中打开全部 ›」：11 号 accent；点 = 在外壳里打开当前项目的画廊。
class _OpenGalleryLink extends StatelessWidget {
  const _OpenGalleryLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final String label = context.l10n.leftRailAssetsOpenGallery;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkActivatable(
          key: AssetsPanel.openGalleryKey,
          onTap: onTap,
          semanticLabel: label,
          builder: (BuildContext context, bool hovered, bool focused) => Text(
            label,
            style: t.meta.copyWith(color: hovered ? c.accentHover : c.accent),
          ),
        ),
      ),
    );
  }
}
