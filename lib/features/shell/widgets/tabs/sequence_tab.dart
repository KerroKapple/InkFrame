// 序列标签体（P2：只读序列 lens 常驻在标签里，不再是「空态 + 拉起对话框」）。
//
// 两态：
// ① canvasId == null → 去 Studio 的引导空态。**此分支不 watch 任何仓储**
//    ——硬约束：boot 级 widget test 只密封了一部分仓储，序列/导出标签一旦
//    eager 碰 canvas/node/edge 仓储就会去起真内嵌 PG（覆盖率收集会永挂）。
// ② 有画布 → SequenceScreen（链表 / 监视器 / 只读轨）。没有 narrative 边时链表位置显示
//    既有的 sequencePreviewDisabledTooltip 文案（不是灰按钮）。
//
// isVisible（外壳按 isTabVisible(sequence) 逐帧下传）：false 时监视器立刻 pause，回来不续播。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.dart';
import '../../../canvas/providers/canvas_edges_controller.dart';
import '../../../canvas/providers/canvas_nodes_controller.dart';
import '../../../canvas/providers/current_canvas_id.dart';
import '../../../sequence/widgets/sequence_screen.dart';
import '../../models/shell_state.dart';
import '../../providers/shell_controller.dart';
import '../../util/tab_availability.dart';
import '../shell_empty_state.dart';

class SequenceTab extends ConsumerWidget {
  const SequenceTab({super.key, required this.isVisible});

  /// 序列标签当前是否在台上（没被切走、没被浮层盖住）。
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId == null) {
      return ShellEmptyState(
        icon: Icons.account_tree_outlined,
        title: l.shellCanvasEmptyTitle,
        body: l.shellSequenceEmptyBody,
        ctaLabel: l.shellGoToStudio,
        onCta: () => ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
      );
    }
    // 门控只看【边】（hasNarrativeEdges，原样沿用）：没有叙事链就没有"序列"可言——画布上一堆
    // 互不相连的节点是常态，orderByNarrativeChain 会把它们全追加成"镜"，那不是序列。
    final bool hasChain = ref.watch(canvasEdgesControllerProvider(canvasId).select(hasNarrativeEdges));
    // 节点控制器保持订阅（autoDispose family），两支都要：lens 那支 watch 它，空态这支也别让它回收。
    ref.watch(canvasNodesControllerProvider(canvasId).select((_) => true));
    if (!hasChain) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.lg),
          child: Text(
            l.sequencePreviewDisabledTooltip,
            textAlign: TextAlign.center,
            style: context.inkTypography.body.copyWith(color: context.inkColors.fg5),
          ),
        ),
      );
    }
    // projectId 走外壳的项目上下文（BOARD 210 同源）；没有项目上下文时缩略 / 视频都解析不了，
    // 仍然画 lens（链表照出），只是文件都当缺失。
    final String projectId = ref.watch(shellControllerProvider.select((ShellState s) => s.project?.id)) ?? '';
    return SequenceScreen(canvasId: canvasId, projectId: projectId, isVisible: isVisible);
  }
}
