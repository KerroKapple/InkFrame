// ImageResultInspector：单选 image result 节点时展示的结果面板（批量/变体网格）。
//
// 读侧：batchResultsControllerProvider(node.id)。无 slot（单张生成）时不占面板空间。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/canvas_node.dart';
import 'batch_results_grid.dart';

class ImageResultInspector extends ConsumerWidget {
  const ImageResultInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchResultsControllerProvider(node.id));
    // 加载态 / 空数据态不占面板；错误态与有数据态才浮出面板——
    // 错误文案交由内部 BatchResultsGrid 渲染，避免面板与网格重复横幅。
    final hasContent = async.hasError || (async.valueOrNull?.isNotEmpty ?? false);
    if (!hasContent) return const SizedBox.shrink();
    // 几何照 Batch 稿：本件是**面板内的一段**，不是第二块面板。
    // 原来的 width:320 + surface1 底 + 左竖线是它当独立侧栏时的形态——挂进 301 宽的
    // 检查器后，320 被外层约束压回 300、再吃掉两侧各 24 的内边距，格子只剩 252（稿 276）。
    // 宽度交给面板，内边距收到 s12，底色与竖线去掉；「结果」标题也去掉——节点头
    // 已由 CanvasInspectorPanel._NodeSummary 画过，稿上这里直接就是「批量结果」。
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: BatchResultsGrid(resultNode: node),
    );
  }
}
