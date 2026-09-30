// 导出标签体。三态说明见 sequence_tab.dart 头注。
//
// 可用性判据走 shell/util/tab_availability.dart 的 canExportVideo——从
// canvas_top_chrome.dart 原样搬运，不重写。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/primitives/ink_ghost_button.dart';
import '../../../canvas/providers/canvas_edges_controller.dart';
import '../../../canvas/providers/canvas_nodes_controller.dart';
import '../../../canvas/providers/current_canvas_id.dart';
import '../../../export/open_export_dialog.dart';
import '../../models/shell_state.dart';
import '../../providers/shell_controller.dart';
import '../../util/tab_availability.dart';
import '../shell_empty_state.dart';

class ExportTab extends ConsumerWidget {
  const ExportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId == null) {
      return ShellEmptyState(
        icon: Icons.account_tree_outlined,
        title: l.shellCanvasEmptyTitle,
        // 正文不复用 shellCanvasEmptyBody，理由同 sequence_tab。
        body: l.shellExportEmptyBody,
        ctaLabel: l.shellGoToStudio,
        onCta: () =>
            ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
      );
    }
    // BOARD 210：可用性 = 有可导出的 video result【且】外壳有项目上下文——与 _open 里
    // projectId 的来源同源，不再从节点数据摸 project_id。
    final bool enabled = ref.watch(
          canvasNodesControllerProvider(canvasId).select(canExportVideo),
        ) &&
        ref.watch(shellControllerProvider.select((ShellState s) => s.project != null));
    // 【必须显式订阅边控制器】同 sequence_tab 的理由，症状不同且更阴：边是
    // autoDispose family，无人订阅时 _open 里 ref.read 拿到 AsyncLoading →
    // edges 落空 → orderVideoNodesForExport 静默退化成非叙事链序（EX-1′ 失效），
    // 对话框照开、导出照跑，只是顺序悄悄变了，没有任何东西会报错。
    // 旧 CanvasTopChrome 里是隔壁的序列按钮 watch 着边才没暴露。
    ref.watch(canvasEdgesControllerProvider(canvasId).select((_) => true));
    return Center(
      child: Tooltip(
        message: enabled ? l.exportVideoTooltip : l.exportVideoDisabledTooltip,
        child: InkGhostButton(
          label: l.exportVideoTooltip,
          icon: Icons.movie_outlined,
          onPressed: enabled ? () => _open(context, ref, canvasId) : null,
        ),
      ),
    );
  }

  /// 打开对话框走 export/open_export_dialog.dart 的唯一路径（序列标签的「导出 mp4」同源）。
  void _open(BuildContext context, WidgetRef ref, String canvasId) =>
      openExportVideoDialogForCanvas(context, ref, canvasId);
}
