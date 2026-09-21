// GalleryScreen：项目维度产物画廊（M3 素材库首切片，只读浏览）。
//
// 布局：InkWindowChrome（返回 + 面包屑）+ 产物网格；
// 状态：galleryControllerProvider(projectId) 的 loading / error / empty / data 四态。
// 入口：Studio 项目卡菜单「Gallery」（currentGalleryProjectProvider，app.dart 顶层切换）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/primitives/ink_accent_chip.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../../theme/tokens.dart';
import '../models/gallery_item.dart';
import '../providers/current_gallery_project.dart';
import '../providers/gallery_controller.dart';
import '../providers/gallery_filter.dart';
import 'gallery_tile.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final itemsAsync = ref.watch(galleryControllerProvider(projectId));
    // 筛选器是 autoDispose，而它唯一的 watcher _GalleryContent 只存在于
    // data 且非空这一个分支（见下方 when）。loading / error / 空态三条路径下
    // 筛选态会被静默回收 → 用户的筛选在一次重试后凭空消失。
    // 这条 watch 把筛选器的存活性锚在 GalleryScreen 自身的生命周期上，
    // 顺带驱动工具条的“筛选生效中”指示——它不是单纯为了渲染一个 chip
    // 才写的，删掉这条 watch 会让 4a 修的回收 bug 静默复发（Task 7 删
    // _GalleryTopChrome、放临时占位工具条时请保留这条 watch，Task 9 落地
    // 真正的 InkToolBar 时同样保留，别当死代码删掉）。
    final filtersActive = ref.watch(
      galleryFilterProvider(
        projectId,
      ).select((GalleryFilter f) => f.isActive),
    );
    // Material 根：筛选条的 Dropdown/TextField 需要 Material 祖先（GA-3）。
    return Material(
      color: colors.surfaceCanvas,
      child: Column(
        children: <Widget>[
          _GalleryTopChrome(
            projectName: projectName,
            filtersActive: filtersActive,
            onClearFilters: () =>
                ref.read(galleryFilterProvider(projectId).notifier).state =
                    const GalleryFilter(),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _GalleryErrorState(
                onRetry: () =>
                    ref.invalidate(galleryControllerProvider(projectId)),
              ),
              data: (items) => items.isEmpty
                  ? const _GalleryEmptyState()
                  : _GalleryContent(
                      // ValueKey(projectId)：切项目强制重建 State，保证
                      // _searchCtrl 的播种（initState）在每个项目上都跑一次，
                      // 不因 Element 复用而只在第一次切入时生效。
                      key: ValueKey<String>(projectId),
                      projectId: projectId,
                      items: items,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTopChrome extends ConsumerWidget {
  const _GalleryTopChrome({
    required this.projectName,
    required this.filtersActive,
    required this.onClearFilters,
  });

  final String projectName;
  final bool filtersActive;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkWindowChrome(
      leading: IconButton(
        tooltip: context.l10n.galleryBackTooltip,
        icon: Icon(Icons.arrow_back, size: 18, color: colors.fg2),
        onPressed: () =>
            ref.read(currentGalleryProjectProvider.notifier).state = null,
      ),
      center: Text(
        context.l10n.galleryBreadcrumb(projectName),
        style: typo.headlineXs.copyWith(color: colors.fg1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // T4a：筛选生效中指示 + 就地清除（Task 7 删 _GalleryTopChrome 时先落
      // 临时占位工具条，Task 9 再做真正的 InkToolBar）。
      trailing: filtersActive
          ? Tooltip(
              message: context.l10n.galleryFilterClear,
              child: InkAccentChip(
                label: context.l10n.galleryFilterActiveChip,
                icon: Icons.filter_alt,
                onPressed: onClearFilters,
              ),
            )
          : null,
    );
  }
}

/// GA-3：筛选条（类型分段 + 画布下拉 + canvasName 搜索）+ 过滤后网格/无命中态。
class _GalleryContent extends ConsumerStatefulWidget {
  const _GalleryContent({
    super.key,
    required this.projectId,
    required this.items,
  });

  final String projectId;
  final List<GalleryItem> items;

  @override
  ConsumerState<_GalleryContent> createState() => _GalleryContentState();
}

class _GalleryContentState extends ConsumerState<_GalleryContent> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    // _searchCtrl 是 onChanged 的唯一输入源，从不从 filter.query 读回；
    // 切项目 / error 重试 / data→空 三条路径都会重建 State 但不重建 filter，
    // 于是输入框显示空、筛选却仍然生效——界面与真相脱同步。
    final seeded = ref.read(galleryFilterProvider(widget.projectId)).query;
    _searchCtrl = TextEditingController(text: seeded)
      ..selection = TextSelection.collapsed(offset: seeded.length);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(galleryFilterProvider(widget.projectId).notifier).state =
        const GalleryFilter();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(galleryFilterProvider(widget.projectId));
    final notifier = ref.read(galleryFilterProvider(widget.projectId).notifier);
    // 顶栏 chip 的「清除筛选」只改 provider（跨 State 边界，够不到这里的
    // _searchCtrl）；这里单向回灌：filter.query 变了且跟输入框当前文本
    // 不一致时才写回。自己打字触发的那次变化，写回前 _searchCtrl.text
    // 已经等于 next.query，判等直接短路——不会打断输入时的光标。
    ref.listen<GalleryFilter>(galleryFilterProvider(widget.projectId), (
      _,
      next,
    ) {
      if (next.query != _searchCtrl.text) {
        _searchCtrl.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });
    final filtered = filterGalleryItems(widget.items, filter);
    // 画布下拉候选：保序去重（聚合序=createdAt 倒序内的首见序）。
    final canvasNames = <String, String>{
      for (final item in widget.items) item.canvasId: item.canvasName,
    };

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.xl,
            InkSpacing.md,
            InkSpacing.xl,
            0,
          ),
          child: Row(
            children: <Widget>[
              SegmentedButton<GalleryItemKind?>(
                segments: <ButtonSegment<GalleryItemKind?>>[
                  ButtonSegment<GalleryItemKind?>(
                    value: null,
                    label: Text(l.galleryFilterAll),
                  ),
                  ButtonSegment<GalleryItemKind?>(
                    value: GalleryItemKind.image,
                    label: Text(l.galleryKindImage),
                  ),
                  ButtonSegment<GalleryItemKind?>(
                    value: GalleryItemKind.video,
                    label: Text(l.galleryKindVideo),
                  ),
                ],
                selected: <GalleryItemKind?>{filter.kind},
                onSelectionChanged: (sel) => notifier.state =
                    filter.copyWith(kind: () => sel.first),
              ),
              const SizedBox(width: InkSpacing.md),
              Flexible(
                child: DropdownButton<String?>(
                  // 失配回落 null（评审 P2-1）：选中画布随数据刷新消失时不撞
                  // DropdownButton 的 value∈items 断言（GA-6 删除落地前置）。
                  value: canvasNames.containsKey(filter.canvasId)
                      ? filter.canvasId
                      : null,
                  // isExpanded + 省略号（评审 P1-1）：按钮宽度否则=最宽画布名，
                  // 长名在最小窗口直接 RenderFlex 溢出。
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        l.galleryFilterCanvasAll,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final entry in canvasNames.entries)
                      DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) =>
                      notifier.state = filter.copyWith(canvasId: () => v),
                ),
              ),
              const SizedBox(width: InkSpacing.md),
              Expanded(
                child: InkInput(
                  controller: _searchCtrl,
                  hintText: l.gallerySearchHint,
                  onChanged: (v) =>
                      notifier.state = filter.copyWith(query: v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _GalleryNoMatchState(onClear: _clearFilters)
              : _GalleryGrid(projectId: widget.projectId, items: filtered),
        ),
      ],
    );
  }
}

/// 筛选无命中：说明 + 清除筛选（复用空态视觉语汇）。
class _GalleryNoMatchState extends StatelessWidget {
  const _GalleryNoMatchState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.filter_alt_off_outlined, size: 32, color: colors.fg3),
          const SizedBox(height: InkSpacing.md),
          Text(
            context.l10n.galleryFilterNoMatches,
            style: typo.body.copyWith(color: colors.fg3),
          ),
          const SizedBox(height: InkSpacing.md),
          InkGhostButton(
            label: context.l10n.galleryFilterClear,
            icon: Icons.filter_alt_off_outlined,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({required this.projectId, required this.items});

  final String projectId;
  final List<GalleryItem> items;

  static const double _tileMaxExtent = 220;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(InkSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tileMaxExtent,
        mainAxisSpacing: InkSpacing.md,
        crossAxisSpacing: InkSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      // ValueKey：GridView 复用 Element 时防 tile 内部状态串位（评审 F2）。
      itemBuilder: (_, i) => GalleryTile(
        key: ValueKey<String>(
          '${items[i].canvasId}|${items[i].relativePath}|${items[i].slotIndex}',
        ),
        projectId: projectId,
        item: items[i],
      ),
    );
  }
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface3,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 32,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              context.l10n.galleryEmptyTitle,
              style: typo.headline.copyWith(color: colors.fg1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: InkSpacing.sm),
            Text(
              context.l10n.galleryEmptySubtitle,
              style: typo.body.copyWith(color: colors.fg3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryErrorState extends StatelessWidget {
  const _GalleryErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkErrorBanner(message: context.l10n.galleryLoadFailed),
            const SizedBox(height: InkSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: InkGhostButton(
                label: context.l10n.commonRetry,
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
