// 库面板（Screens 稿第 1 屏）：220 + 1px 右描边，surface3。
//   「库」标题 → 行 28：全部项目（选中，带计数）/ 回收站（计数，点开回收站对话框）
//   → 撑开 → 底部 30 高「设置」行（打开设置层）。
// 稿上的「最近打开 / 归档 / 最近画布」仓库没有对应数据（无「最近打开」记录、无归档标记），不画。
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../providers/trashed_items_providers.dart';
import '../providers/workspace_projects_provider.dart';
import 'trash_dialog.dart';

class LibrarySidebar extends ConsumerWidget {
  const LibrarySidebar({super.key});

  /// 稿是 content-box：width 220 + border-right 1。
  static const double width = 221;

  static const Key allProjectsKey = Key('studio.library.allProjects');
  static const Key trashKey = Key('studio.library.trash');
  static const Key settingsKey = Key('studio.library.settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final int? projectCount =
        ref.watch(workspaceProjectsProvider).valueOrNull?.length;
    final int? trashCount =
        ref.watch(trashedProjectsProvider).valueOrNull?.length;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s14, InkSpacing.s12, InkSpacing.sm),
            child: Text(l.studioLibraryHeading, style: t.meta.copyWith(color: c.fg6)),
          ),
          _NavRow(
            key: allProjectsKey,
            label: l.studioLibraryAllProjects,
            count: projectCount,
            selected: true,
            onTap: null,
          ),
          _NavRow(
            key: trashKey,
            label: l.studioTrash,
            count: trashCount,
            selected: false,
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: c.scrim,
              builder: (_) => const TrashDialog(),
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: l.studioOpenSettings,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: settingsKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings),
                child: Container(
                  height: 31, // content 30 + border-top 1
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.fg6)),
                      ),
                      const SizedBox(width: InkSpacing.s10),
                      Text(l.studioSettings, style: t.body.copyWith(color: c.fg4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：28 高，padding 0 12，gap 10：12×10 方框（选中琥珀边）+ 名称 + 等宽 10px 计数。
class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Widget row = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      color: selected ? c.surface5 : null,
      child: Row(
        children: <Widget>[
          // 稿是 content-box：12×10 + 1px 边 ⇒ 14×12。
          Container(
            width: 14,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: selected ? c.accent : c.fg6),
              borderRadius: BorderRadius.circular(InkRadius.s1),
            ),
          ),
          const SizedBox(width: InkSpacing.s10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: selected ? c.fg1 : c.fg3)),
          ),
          if (count != null) Text('$count', style: t.monoSmall.copyWith(color: c.fg6)),
        ],
      ),
    );
    if (onTap == null) return Semantics(selected: selected, label: label, child: row);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
      ),
    );
  }
}

