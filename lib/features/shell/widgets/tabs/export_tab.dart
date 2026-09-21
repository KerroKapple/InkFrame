// 导出标签体（T7 过渡形状；真身在 T10）。三态说明见 sequence_tab.dart 头注。
//
// 可用性判据走 shell/util/tab_availability.dart 的 canExportVideo——从
// canvas_top_chrome.dart 原样搬运，不重写。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/primitives/ink_ghost_button.dart';
import '../../../canvas/models/canvas_edge.dart';
import '../../../canvas/models/canvas_node.dart';
import '../../../canvas/providers/canvas_edges_controller.dart';
import '../../../canvas/providers/canvas_nodes_controller.dart';
import '../../../canvas/providers/current_canvas_id.dart';
import '../../../export/util/export_order.dart';
import '../../../export/widgets/export_video_dialog.dart';
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
        body: l.shellCanvasEmptyBody,
        ctaLabel: l.shellGoToStudio,
        onCta: () =>
            ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
      );
    }
    final bool enabled = ref.watch(
      canvasNodesControllerProvider(canvasId).select(canExportVideo),
    );
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

  void _open(BuildContext context, WidgetRef ref, String canvasId) {
    // EX-1′：默认序是 narrative 链序，需要全量节点 + 边（result 节点自己不在
    // 链上，挂在 config 节点下）。
    final videoNodes = orderVideoNodesForExport(
      allNodes: ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[],
      edges: ref.read(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasEdge>[],
    );
    final projectId = videoNodes.isEmpty ? null : videoNodes.first.projectId;
    if (projectId == null) return; // 按压瞬间节点已变化：静默不弹
    showExportVideoDialog(context, projectId: projectId, videoNodes: videoNodes);
  }
}
