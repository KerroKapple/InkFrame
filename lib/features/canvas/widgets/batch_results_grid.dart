// BatchResultsGrid：批量/变体结果网格——展示某结果节点下所有 slot。
//
// 读侧组件（batchResultsControllerProvider）。挂载点（结果节点 Inspector 槽）与
// 生产侧（JobQueueService 落 slot 行）为后续接入，见 docs/BOARD.md。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';

class BatchResultsGrid extends ConsumerWidget {
  const BatchResultsGrid({super.key, required this.resultNode});

  final CanvasNode resultNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots =
        ref.watch(batchResultsControllerProvider(resultNode.id)).valueOrNull ??
        const <BatchResult>[];
    if (slots.isEmpty) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.batchResultsLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: InkSpacing.xs,
          crossAxisSpacing: InkSpacing.xs,
          children: [
            for (final slot in slots)
              _BatchSlotTile(slot: slot, node: resultNode),
          ],
        ),
      ],
    );
  }
}

class _BatchSlotTile extends ConsumerWidget {
  const _BatchSlotTile({required this.slot, required this.node});

  final BatchResult slot;
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.sm),
        border: Border.all(
          color: slot.promoted ? colors.accent : colors.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadius.sm),
        child: AspectRatio(aspectRatio: 1, child: _content(ref, colors)),
      ),
    );
  }

  Widget _content(WidgetRef ref, InkColors colors) {
    final url = slot.outputUrl;
    final projectId = node.projectId;
    final canvasId = node.canvasId;
    if (slot.isSuccess &&
        url != null &&
        url.isNotEmpty &&
        projectId != null &&
        canvasId != null) {
      try {
        final file = ref
            .read(fileResolverServiceProvider)
            .resolve(
              projectId: projectId,
              canvasId: canvasId,
              relativePath: url,
            );
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _placeholder(colors, Icons.broken_image_outlined),
        );
      } catch (_) {
        return _placeholder(colors, Icons.broken_image_outlined);
      }
    }
    if (slot.isError) {
      return _placeholder(colors, Icons.error_outline);
    }
    return _placeholder(colors, Icons.hourglass_empty);
  }

  Widget _placeholder(InkColors colors, IconData icon) =>
      Center(child: Icon(icon, color: colors.fg3, size: 20));
}
