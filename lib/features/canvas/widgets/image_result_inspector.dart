// ImageResultInspector：单选 image result 节点时的结果面板。
//
// 三段（共用件在 result_inspector_parts.dart，与 VideoResultInspector 同一套）：
//   1. 顶部：有批量 slot（或批量读失败）⇒ 批量 / 变体网格 BatchResultsGrid；
//      单张生成（没有 slot）⇒ 16:9 预览图。slot 还在加载、不知道是哪种时两样都不画，免得先闪一下预览。
//   2. 「生成参数」组（来源 config + 产物自己的尺寸 / 种子）。
//   3. 动作行：定位来源节点 / 在序列中定位。
//
// 读侧：batchResultsControllerProvider(node.id)。以前单张生成时整个面板返回空——检查器选中一张成片
// 却什么都看不到（演示里的 F2），现在单张也有预览、参数与动作。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/canvas_node.dart';
import 'batch_results_grid.dart';
import 'result_inspector_parts.dart';

class ImageResultInspector extends ConsumerWidget {
  const ImageResultInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchResultsControllerProvider(node.id));
    // 错误态与有数据态才出网格——错误文案交由 BatchResultsGrid 渲染，避免面板与网格重复横幅。
    final bool hasBatch = async.hasError || (async.valueOrNull?.isNotEmpty ?? false);
    final bool batchUnknown = async.isLoading && !async.hasValue && !async.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasBatch)
          // 几何照 Batch 稿：本件是**面板内的一段**，不是第二块面板——宽度交给面板，内边距 s12，
          // 不带底色与竖线；「结果」标题也不画，节点头已由 CanvasInspectorPanel._NodeSummary 画过。
          Padding(
            padding: const EdgeInsets.all(InkSpacing.s12),
            child: BatchResultsGrid(resultNode: node),
          )
        else if (!batchUnknown)
          ResultPreviewFrame(child: _preview(context)),
        ResultParamsGroup(node: node),
        ResultActions(node: node),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final String? url = node.imageUrl;
    if (url == null) {
      return ResultPreviewPlaceholder(icon: Icons.hourglass_empty_outlined, text: context.l10n.resultNodePending);
    }
    return ResultFileImage(node: node, relativePath: url);
  }
}
