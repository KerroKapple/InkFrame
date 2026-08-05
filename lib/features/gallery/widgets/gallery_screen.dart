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
    // Material 根：筛选条的 Dropdown/TextField 需要 Material 祖先（GA-3）。
    return Material(
      color: colors.surfaceCanvas,
      child: Column(
        children: <Widget>[
          _GalleryTopChrome(projectName: projectName),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _GalleryErrorState(
                onRetry: () =>
                    ref.invalidate(galleryControllerProvider(projectId)),
              ),
              data: (items) => items.isEmpty
                  ? const _GalleryEmptyState()
                  : _GalleryContent(projectId: projectId, items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTopChrome extends ConsumerWidget {
  const _GalleryTopChrome({required this.projectName});

  final String projectName;

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
    );
  }
}

/// GA-3：筛选条（类型分段 + 画布下拉 + canvasName 搜索）+ 过滤后网格/无命中态。
class _GalleryContent extends ConsumerStatefulWidget {
  const _GalleryContent({required this.projectId, required this.items});

  final String projectId;
  final List<GalleryItem> items;

  @override
  ConsumerState<_GalleryContent> createState() => _GalleryContentState();
}

class _GalleryContentState extends ConsumerState<_GalleryContent> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(galleryFilterProvider.notifier).state = const GalleryFilter();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(galleryFilterProvider);
    final notifier = ref.read(galleryFilterProvider.notifier);
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
