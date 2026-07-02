// ImageResultInspector：单选 image result 节点时展示的结果面板（批量/变体网格）。
//
// 读侧：batchResultsControllerProvider(node.id)。无 slot（单张生成）时不占面板空间。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';
import 'batch_results_grid.dart';

class ImageResultInspector extends ConsumerWidget {
  const ImageResultInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots =
        ref.watch(batchResultsControllerProvider(node.id)).valueOrNull ??
        const <BatchResult>[];
    if (slots.isEmpty) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(InkSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inspectorResultTitle,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.lg),
            BatchResultsGrid(resultNode: node),
          ],
        ),
      ),
    );
  }
}
