// 序列标签体（T7 过渡形状；真身在 T10）。
//
// 三态，都必须真实可点进入，不是灰按钮一片：
// ① canvasId == null → 去 Studio 的引导空态。**此分支不 watch 任何仓储**
//    ——硬约束：boot 级 widget test 只密封了一部分仓储，序列/导出标签一旦
//    eager 碰 canvas/node/edge 仓储就会去起真内嵌 PG（覆盖率收集会永挂）。
//    懒物化挡住大半，本分支的提前 return 挡住其余。
// ② 有画布但无 narrative 边 → 按钮禁用 + 既有的 sequencePreviewDisabledTooltip。
// ③ 满足条件 → 可点 → 弹既有对话框（对话框一个字符都不改，见 spec §8.2 / D3）。
//
// 可用性判据走 shell/util/tab_availability.dart 的 hasNarrativeEdges——从
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
import '../../../storyboard/util/sequence_builder.dart';
import '../../../storyboard/widgets/sequence_preview_dialog.dart';
import '../../models/shell_state.dart';
import '../../providers/shell_controller.dart';
import '../../util/tab_availability.dart';
import '../shell_empty_state.dart';

class SequenceTab extends ConsumerWidget {
  const SequenceTab({super.key});

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
      canvasEdgesControllerProvider(canvasId).select(hasNarrativeEdges),
    );
    // 【必须显式订阅节点控制器】它是 autoDispose family：无人订阅时 _open 里的
    // ref.read 只拿得到 AsyncLoading（valueOrNull == null）→ nodes 为空 →
    // projectId 为 null → 静默 return，按钮变哑键。
    // 从 CanvasTopChrome 搬过来时这条极易丢：旧顶栏里是隔壁的导出按钮顺手
    // watch 着节点，序列按钮才一直能用——那是【隐式】依赖，拆成两个标签就断了。
    // select 收窄成常量：保持订阅，但节点变化（拖动等）不重建本标签。
    ref.watch(canvasNodesControllerProvider(canvasId).select((_) => true));
    return Center(
      child: Tooltip(
        message:
            enabled ? l.sequencePreviewTooltip : l.sequencePreviewDisabledTooltip,
        child: InkGhostButton(
          label: l.sequencePreviewTooltip,
          icon: Icons.play_circle_outline,
          onPressed: enabled ? () => _open(context, ref, canvasId) : null,
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, String canvasId) {
    final nodes = ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];
    final edges = ref.read(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    final projectId = nodes.isEmpty ? null : nodes.first.projectId;
    if (projectId == null) return; // 按压瞬间节点已变化：静默不弹
    showSequencePreviewDialog(
      context,
      projectId: projectId,
      shots: buildSequence(nodes: nodes, edges: edges),
    );
  }
}
