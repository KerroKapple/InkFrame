// BatchResultsGrid：批量/变体结果网格——展示某结果节点下所有 slot。
//
// 读侧组件（batchResultsControllerProvider）；挂载在 ImageResultInspector，
// 生产侧落 slot 行见 JobQueueService。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';

class BatchResultsGrid extends ConsumerWidget {
  const BatchResultsGrid({super.key, required this.resultNode});

  final CanvasNode resultNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchResultsControllerProvider(resultNode.id));
    // 加载态维持原样（不占面板）；错误态渲染错误横幅，不再静默吞错。
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => _labeled(
        context,
        InkErrorBanner(message: l10nAsyncError(context, error)),
      ),
      data: (slots) {
        if (slots.isEmpty) return const SizedBox.shrink();
        return _labeled(
          context,
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
        );
      },
    );
  }

  /// 标题（批量结果标签）+ 内容体的统一列布局。
  Widget _labeled(BuildContext context, Widget body) {
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
        body,
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
        child: AspectRatio(
          aspectRatio: 1,
          child: _content(context, ref, colors),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, InkColors colors) {
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
      } on PathSecurityError catch (_) {
        // 越权相对路径按坏图占位处理，不崩网格。
        return _placeholder(colors, Icons.broken_image_outlined);
      }
    }
    if (slot.isError) {
      return _errorTile(context, colors);
    }
    return _placeholder(colors, Icons.hourglass_empty);
  }

  /// 失败 slot：errorCode（wire 串）→ InkErrorCode.fromWire（容错，未知回退
  /// unknown）→ 本地化文案。整块套 Tooltip（悬停看全文），底部叠一行 danger 摘要。
  Widget _errorTile(BuildContext context, InkColors colors) {
    final typo = context.inkTypography;
    final code = InkErrorCode.fromWire(slot.errorCode ?? '');
    final text = l10nErrorCode(context, code);
    return Tooltip(
      message: text,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _placeholder(colors, Icons.error_outline),
          Positioned(
            left: InkSpacing.xs,
            right: InkSpacing.xs,
            bottom: InkSpacing.xs,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: typo.caption.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(InkColors colors, IconData icon) =>
      Center(child: Icon(icon, color: colors.fg3, size: 20));
}
