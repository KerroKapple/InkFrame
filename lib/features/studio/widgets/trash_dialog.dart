// TrashDialog：项目回收站（LB-15 / GAP-2）。
//
// 软删项目列表（名字+删除时间）+ 逐项恢复；首版不做永久删除（卡面显式排除）。
// 读侧 trashedProjectsProvider（LB-06 规范：.when 带 error 横幅）；恢复走
// StudioProjectsController.restoreProject（内部刷新工作库），成功后本对话框
// 自刷新 trashed 列表。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../controllers/studio_projects_controller.dart';
import '../providers/trashed_items_providers.dart';

class TrashDialog extends ConsumerWidget {
  const TrashDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final itemsAsync = ref.watch(trashedProjectsProvider);

    return AlertDialog(
      backgroundColor: colors.surface2,
      title: Text(context.l10n.studioTrash),
      content: SizedBox(
        width: 420,
        child: itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(InkSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => InkErrorBanner(message: l10nAsyncError(context, e)),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(InkSpacing.lg),
                  child: Text(
                    context.l10n.studioTrashEmpty,
                    style: typo.caption.copyWith(color: colors.fg3),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        _TrashRow(
                          item: item,
                          onRestore: () => _restore(context, ref, item),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TrashedItem item,
  ) async {
    // 跨 await 依赖首个 await 前 read 持有（#188 P1-1 惯例）。
    final controller = ref.read(studioProjectsControllerProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedMsg = context.l10n.studioRestoreFailed;
    try {
      await controller.restoreProject(item.id);
      // controller 已刷新工作库；这里刷新回收站列表（本对话框仍挂着）。
      container.invalidate(trashedProjectsProvider);
    } on InkError {
      messenger?.showSnackBar(
        SnackBar(content: Text(failedMsg), duration: const Duration(seconds: 3)),
      );
    }
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.item, required this.onRestore});

  final TrashedItem item;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: typo.body.copyWith(color: colors.fg1),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  context.l10n.studioTrashDeletedAt(item.deletedAt.toLocal()),
                  style: typo.caption.copyWith(color: colors.fg3),
                ),
              ],
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          TextButton(
            onPressed: onRestore,
            child: Text(context.l10n.studioRestore),
          ),
        ],
      ),
    );
  }
}
