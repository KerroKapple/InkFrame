// 画布标签体。
//
// canvasId == null 是合法态（spec §8.1 / D12）：显示的不是"出错了"，而是
// "从 Studio 选一个画布"，并带一个直接跳 Studio 标签的按钮——本 PR 不提供
// "关闭当前画布"，用户不能觉得卡死。
//
// 该空态在 T7 之前的生产代码里根本不可达（app.dart 从不以 null canvasId 构建
// CanvasScreen），本标签让它第一次真正可达。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../canvas/providers/current_canvas_id.dart';
import '../../../canvas/widgets/canvas_screen.dart';
import '../../models/shell_state.dart';
import '../../providers/shell_controller.dart';
import '../shell_empty_state.dart';

class CanvasTab extends ConsumerWidget {
  const CanvasTab({super.key, required this.isVisible});

  /// 本标签此刻是否可见（切走标签 / 被浮层盖住都算不可见）——直通
  /// CanvasScreen → CanvasShortcuts.isActive，让不可见画布不再吞 Delete 键。
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId == null) {
      final l = context.l10n;
      return ShellEmptyState(
        icon: Icons.account_tree_outlined,
        title: l.shellCanvasEmptyTitle,
        body: l.shellCanvasEmptyBody,
        ctaLabel: l.shellGoToStudio,
        onCta: () =>
            ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
      );
    }
    return CanvasScreen(isVisible: isVisible);
  }
}
