// 序列标签体。
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
        // 标题复用画布标签的（"还没有打开画布"对三个标签一字不差地成立，R65
        // 不许为同一句话开第二个键）；正文【不】复用——canvas 那句是"它就会在
        // 这里打开"，指的是画布本身在画布标签里展开，放到序列标签就是错的。
        body: l.shellSequenceEmptyBody,
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
    // buildSequence 产出空清单 → 对话框照开、只是一镜都没有（T10 把 projectId
    // 改走 ShellState 之后，症状从"按钮变哑键"变成"弹出空对话框"——同样不报错。
    // 钉住它的是「点击打开序列预览对话框」那条用例的 'Not generated yet' 断言，
    // 删掉本行实测即红，见 task-10-report 变异 M3）。
    // 从 CanvasTopChrome 搬过来时这条极易丢：旧顶栏里是隔壁的导出按钮顺手
    // watch 着节点，序列按钮才一直能用——那是【隐式】依赖，拆成两个标签就断了。
    // select 收窄成常量：保持订阅，但节点变化（拖动等）不重建本标签。
    ref.watch(canvasNodesControllerProvider(canvasId).select((_) => true));
    return Center(
      child: Tooltip(
        message:
            enabled ? l.sequencePreviewTooltip : l.sequencePreviewDisabledTooltip,
        child: InkGhostButton(
          // 按钮面上用短标题（既有键 sequencePreviewTitle = "Sequence preview"），
          // 整句 sequencePreviewTooltip 留在 tooltip 里。不新开 shellSequencePlay：
          // 已有一个字面合适的键，R65 不许为同一句话开第二个。
          label: l.sequencePreviewTitle,
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
    // projectId 走外壳的项目上下文，不再从 nodes.first.projectId 摸（spec §8.2）。
    // 旧写法把"能不能弹对话框"绑在了节点数据上：节点列表恰好为空、或首个节点
    // 的 project_id 为空（存量行允许），按钮就变哑键——而按钮的启用判据只看
    // 【边】，两者不同源，于是"看着能点、点了没反应"。外壳态才是项目的真相源
    // （三个 openCanvas 调用点全都带 withProject）。
    final projectId = ref.read(shellControllerProvider).project?.id;
    if (projectId == null) return; // 外壳尚无项目上下文：静默不弹
    showSequencePreviewDialog(
      context,
      projectId: projectId,
      shots: buildSequence(nodes: nodes, edges: edges),
    );
  }
}
