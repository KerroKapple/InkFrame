// TrashDialog：项目回收站（LB-15 / GAP-2）。
//
// 软删项目列表（名字+删除时间）+ 逐项恢复；首版不做永久删除（卡面显式排除）。
// 读侧 trashedProjectsProvider（LB-06 规范：.when 带 error 横幅）；恢复走
// StudioProjectsController.restoreProject（内部刷新工作库），成功后本对话框
// 自刷新 trashed 列表。
//
// P7：外形从 Material 的 AlertDialog 换成浮层壳 InkOverlayDialog（= 设置浮层
// 那一个壳，720×520，左侧无导航）——回收站是「一块盖在 Studio 上的面板」，
// 不是系统提示框。它仍然是 showDialog 的路由：Esc / 点 ✕ / 点「关闭」都走
// Navigator.pop，恢复即时生效不可撤，所以底部那颗是「关闭」不是「取消」。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ink_overlay_dialog.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../controllers/studio_projects_controller.dart';
import '../providers/trashed_items_providers.dart';

class TrashDialog extends ConsumerWidget {
  const TrashDialog({super.key});

  /// 稿的浮层尺寸（content-box，边框在外面另加 1px）。
  static const double dialogWidth = 720;
  static const double dialogHeight = 520;

  static const Key titleBarKey = Key('trash.titleBar');
  static const Key closeKey = Key('trash.close');
  static const Key doneKey = Key('trash.done');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(trashedProjectsProvider);
    void close() => Navigator.of(context).pop();
    return InkOverlayDialog(
      title: context.l10n.studioTrash,
      width: dialogWidth,
      height: dialogHeight,
      titleBarKey: titleBarKey,
      closeKey: closeKey,
      escHint: context.l10n.settingsEscHint,
      closeTooltip: context.l10n.commonClose,
      onClose: close,
      footerNote: context.l10n.studioTrashFooterNote,
      footerActions: <Widget>[
        KeyedSubtree(
          key: doneKey,
          // Close 而非 Cancel：恢复即时生效不可撤（#190 评审 P3-3）。
          child: InkButton(label: context.l10n.commonClose, onPressed: close),
        ),
      ],
      child: itemsAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: InkSpacing.lg,
            height: InkSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (Object e, _) => Padding(
          padding: const EdgeInsets.all(InkSpacing.md),
          child: InkErrorBanner(message: l10nAsyncError(context, e)),
        ),
        data: (List<TrashedItem> items) =>
            items.isEmpty ? const _TrashEmpty() : _TrashList(items: items),
      ),
    );
  }
}

/// 空态：一行 fg5 说明，居中（浮层里不再用整块空态插图——它只有 520 高）。
class _TrashEmpty extends StatelessWidget {
  const _TrashEmpty();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Center(
      child: Text(
        context.l10n.studioTrashEmpty,
        style: context.inkTypography.body.copyWith(color: c.fg5),
      ),
    );
  }
}

class _TrashList extends ConsumerWidget {
  const _TrashList({required this.items});

  final List<TrashedItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final TextStyle head = context.inkTypography.meta.copyWith(color: c.fg6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 表头照设置页：26 高 + 1px 下沿，11px fg6。
        Container(
          height: 27,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.borderStrong)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(context.l10n.studioTrashColumnName, style: head),
              ),
              // 动作列表头留空（与 API 密钥表同例：按钮自己说明自己）。
              const SizedBox(width: _TrashRow.actionColumnWidth),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (BuildContext context, int i) => _TrashRow(
              item: items[i],
              onRestore: () => _restore(context, ref, items[i]),
            ),
          ),
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

  /// 「恢复」列宽：中英文都放得下。
  static const double actionColumnWidth = 96;

  final TrashedItem item;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: 41, // content 40 + border-bottom 1
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.fg1),
                ),
                Text(
                  context.l10n.studioTrashDeletedAt(item.deletedAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: c.fg5),
                ),
              ],
            ),
          ),
          SizedBox(
            width: actionColumnWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkButton(
                label: context.l10n.studioRestore,
                variant: InkButtonVariant.secondary,
                onPressed: onRestore,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
