// GalleryScreen：项目维度产物画廊（Screens 稿第 2 屏接线版）。
//
// 三栏：筛选 220 | 网格 | 信息 320（尺寸按稿 CSS content-box：+1px 描边）。
// 壳 chrome（菜单栏 / 标签栏的「存为角色」/ 面包屑「全部产物」/ 状态栏计数）在 shell 层。
// 状态：galleryControllerProvider(projectId) 的 loading / error / empty / data 四态。
//
// 稿上有、仓库没有后端因而不画的：「发送到画布」「派生新节点」「悬停自动播」「收藏」
//「角色参考」类型（见 PR #235）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../../theme/tokens.dart';
import '../models/gallery_item.dart';
import '../providers/gallery_controller.dart';
import '../providers/gallery_filter.dart';
import '../providers/gallery_graph_provider.dart';
import 'gallery_filter_panel.dart';
import 'gallery_grid.dart';
import 'gallery_info_panel.dart';

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
    final AsyncValue<List<GalleryItem>> itemsAsync = ref.watch(galleryControllerProvider(projectId));
    // Material 根：对话框 / SnackBar 需要 Material 祖先。
    return Material(
      color: colors.surface1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GalleryFilterPanel(projectId: projectId),
          Expanded(
            // 【skipLoadingOnRefresh 保持默认 true——别动这个 when 的参数】
            // ref.invalidate 走 refresh 而非 reload，刷新期间不走 loading 分支 ⇒
            // 网格不卸载 ⇒ 滚动位置 / 选中集全保（gallery_refresh_test 会红）。
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _GalleryErrorState(
                onRetry: () => ref.invalidate(galleryGraphProvider(projectId)),
              ),
              data: (List<GalleryItem> items) => items.isEmpty
                  ? const _GalleryEmptyState()
                  : GalleryGrid(projectId: projectId),
            ),
          ),
          GalleryInfoPanel(projectId: projectId, projectName: projectName),
        ],
      ),
    );
  }
}

/// 筛选无命中：说明 + 清除筛选（复用空态视觉语汇）。
class GalleryNoMatchState extends ConsumerWidget {
  const GalleryNoMatchState({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.filter_alt_off_outlined, size: 32, color: colors.fg3),
          const SizedBox(height: InkSpacing.md),
          Text(context.l10n.galleryFilterNoMatches, style: typo.body.copyWith(color: colors.fg3)),
          const SizedBox(height: InkSpacing.md),
          InkGhostButton(
            label: context.l10n.galleryFilterClear,
            icon: Icons.filter_alt_off_outlined,
            onPressed: () => ref.read(galleryFilterProvider(projectId).notifier).state = const GalleryFilter(),
          ),
        ],
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
              child: Icon(Icons.photo_library_outlined, size: 32, color: colors.accent),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              context.l10n.galleryEmptyTitle,
              style: typo.dialogTitle.copyWith(color: colors.fg1),
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
