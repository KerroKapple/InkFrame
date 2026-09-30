// BatchResultsGrid：批量/变体结果网格——展示某结果节点下所有 slot，并把四个动作
// （转正 / 当前 / 重跑 / 取消）摆到每一格上。
//
// 读侧 batchResultsControllerProvider，写侧也全部经同一个 notifier——本组件不认识
// 仓储、不认识 JobQueue。挂载在 ImageResultInspector；生产侧落 slot 行见 JobQueueService。
//
// 几何来自 Batch and Characters 稿 §01：2 列 / 列间 6 / 图区按产物真实比例（缺尺寸
// 回落 16:9）/ 图下 4 + 13 高的 9px 等宽元信息行（左 seed、右动作词，无按钮盒）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';
import '../util/batch_slot_view.dart';
import 'batch_compare_overlay.dart';
import 'batch_slot_parts.dart';

class BatchResultsGrid extends ConsumerWidget {
  const BatchResultsGrid({super.key, required this.resultNode});

  final CanvasNode resultNode;

  /// LB-23：2 列格宽上限 180 逻辑 px 缩略解码。
  static const double _decodeWidth = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchResultsControllerProvider(resultNode.id));
    // 加载态维持原样（不占面板）；错误态渲染错误横幅，不再静默吞错。
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => _labeled(
        context,
        const <BatchResult>[],
        InkErrorBanner(message: l10nAsyncError(context, error)),
      ),
      data: (slots) {
        if (slots.isEmpty) return const SizedBox.shrink();
        return _labeled(context, slots, _body(context, ref, slots));
      },
    );
  }

  /// 标题行（标签 + slot 数 + 「对比」入口）+ 内容体。
  Widget _labeled(
    BuildContext context,
    List<BatchResult> slots,
    Widget body,
  ) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(l.batchResultsLabel, style: typo.body.copyWith(color: colors.fg4)),
            if (slots.isNotEmpty) ...<Widget>[
              const SizedBox(width: InkSpacing.sm),
              Text(
                l.batchSlotCount(slots.length),
                style: typo.monoSmall.copyWith(color: colors.fg6),
              ),
            ],
            const Spacer(),
            if (slots.isNotEmpty)
              BatchTappable(
                semanticLabel: l.batchCompare,
                tooltip: l.batchOpenCompare,
                onTap: () => unawaited(
                  showBatchCompareOverlay(context, resultNode: resultNode),
                ),
                child: Text(
                  l.batchCompare,
                  style: typo.meta.copyWith(color: colors.accent),
                ),
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.sm),
        body,
      ],
    );
  }

  /// 网格 + 「重跑失败 slot」+ 转正说明。
  ///
  /// 网格不用 GridView：每格高度由产物真实比例决定，GridView.count 只认一个统一
  /// childAspectRatio，竖图与横图混排就会被裁。两列手搭 Row 才能各高各的。
  Widget _body(BuildContext context, WidgetRef ref, List<BatchResult> slots) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final String? configNodeId = resultNode.sourceNodeId;
    final bool hasFailed = slots.any(
      (s) => batchSlotViewOf(s) == BatchSlotView.error,
    );

    final rows = <Widget>[];
    for (var i = 0; i < slots.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: InkSpacing.s6));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _BatchSlotTile(slot: slots[i], node: resultNode),
            ),
            const SizedBox(width: InkSpacing.s6),
            Expanded(
              child: i + 1 < slots.length
                  ? _BatchSlotTile(slot: slots[i + 1], node: resultNode)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...rows,
        // 没有失败格就不画这个按钮——画一个永远点不动的按钮不如不画。
        // 孤儿 result（溯源 config 节点已不在）同理：重跑整条路都走不通。
        if (hasFailed && configNodeId != null) ...<Widget>[
          const SizedBox(height: InkSpacing.s12),
          BatchTappable(
            semanticLabel: l.batchRerunFailed,
            onTap: () => unawaited(
              runBatchSlotAction(
                context,
                ref,
                () => ref
                    .read(
                      batchResultsControllerProvider(resultNode.id).notifier,
                    )
                    .rerunFailed(configNodeId: configNodeId),
              ),
            ),
            child: WsSecondaryButton(l.batchRerunFailed),
          ),
        ],
        const SizedBox(height: InkSpacing.sm),
        Text(
          l.batchPromoteHint,
          style: typo.micro.copyWith(color: colors.fg6, height: 1.5),
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
    final view = batchSlotViewOf(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: batchSlotAspectRatio(slot),
          child: _thumb(context, colors, view),
        ),
        const SizedBox(height: InkSpacing.xs),
        // 稿的元信息行实测 13 高（9px mono 的行盒）——钉死它，否则两行网格会整体
        // 上移，下面的按钮与脚注跟着错位。
        SizedBox(
          height: 13,
          child: Row(
            children: <Widget>[
              Text(
                slot.seed?.toString() ?? kBatchSeedPlaceholder,
                style: context.inkTypography.monoNano.copyWith(
                  color: colors.fg6,
                ),
              ),
              const Spacer(),
              _action(context, ref, view),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(BuildContext context, InkColors colors, BatchSlotView view) {
    final typo = context.inkTypography;
    final l = context.l10n;
    final bool promoted = view == BatchSlotView.promoted;
    final Widget box = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.thumbFill,
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: promoted ? colors.accent : colors.outline),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (view == BatchSlotView.success || promoted)
            BatchSlotImage(
              slot: slot,
              node: node,
              decodeWidth: BatchResultsGrid._decodeWidth,
            ),
          Positioned(
            left: InkSpacing.xs,
            top: InkSpacing.s3,
            child: Text(
              '#${slot.slotIndex + 1}',
              style: typo.monoNano.copyWith(
                color: colors.fg1.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (promoted)
            Positioned(
              right: InkSpacing.xs,
              top: InkSpacing.s3,
              // 稿 padding 1px 5px：竖向 1px 不设档，用固定高 14 的盒子等效。
              child: Container(
                height: 14,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.s5,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(InkRadius.xs),
                ),
                child: Text(
                  l.batchBadgeChosen,
                  style: typo.nano.copyWith(color: colors.onAccent),
                ),
              ),
            ),
          if (view == BatchSlotView.generating)
            Center(
              child: Text(
                l.batchStateGenerating,
                style: typo.micro.copyWith(color: colors.fg6),
              ),
            ),
          if (view == BatchSlotView.error) _errorOverlay(context, colors),
        ],
      ),
    );
    if (view != BatchSlotView.error) return box;
    // 格宽不到 140，失败文案必然被截——整块套 Tooltip 给全文。
    // errorCode 原串不在这里露出（只在对比浮层），格内只放本地化文案。
    return Tooltip(message: _errorText(context), child: box);
  }

  String _errorText(BuildContext context) =>
      l10nErrorCode(context, InkErrorCode.fromWire(slot.errorCode ?? ''));

  Widget _errorOverlay(BuildContext context, InkColors colors) {
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('✕', style: typo.meta.copyWith(color: colors.danger)),
          const SizedBox(height: InkSpacing.s3),
          Text(
            _errorText(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: typo.nano.copyWith(color: colors.danger, height: 1.3),
          ),
        ],
      ),
    );
  }

  /// 元信息行右侧的动作词（9px 等宽，无按钮盒，靠颜色区分）。
  /// 「当前」是状态不是动作——不挂手势，免得点了没反应。
  Widget _action(BuildContext context, WidgetRef ref, BatchSlotView view) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final String? configNodeId = node.sourceNodeId;

    BatchResultsController controller() =>
        ref.read(batchResultsControllerProvider(node.id).notifier);

    Widget word(String label, Color color, {VoidCallback? onTap, String? tip}) =>
        BatchTappable(
          semanticLabel: label,
          tooltip: tip,
          onTap: onTap,
          child: Text(label, style: typo.monoNano.copyWith(color: color)),
        );

    return switch (view) {
      BatchSlotView.promoted => word(l.batchActionCurrent, colors.accent),
      BatchSlotView.success => word(
        l.batchActionPromote,
        colors.fg4,
        onTap: () => unawaited(
          runBatchSlotAction(
            context,
            ref,
            () => controller().promote(slot),
          ),
        ),
      ),
      // 溯源 config 节点不在（孤儿 result）时重跑走不通：整个动作词不画。
      BatchSlotView.error when configNodeId != null => word(
        l.batchActionRerun,
        colors.danger,
        // 「重跑」是整批重来、产物落新节点——单格重跑在架构上不成立，代价（一整批的
        // 额度）得在点之前讲清楚，与「取消」那一格同例。
        tip: l.batchRerunWholeBatchHint,
        onTap: () => unawaited(
          runBatchSlotAction(
            context,
            ref,
            () => controller().rerun(configNodeId: configNodeId),
          ),
        ),
      ),
      BatchSlotView.error => const SizedBox.shrink(),
      BatchSlotView.generating => word(
        l.batchActionCancel,
        colors.fg4,
        // per-slot 取消不成立（一次 provider 调用返 N 张）——tooltip 必须说清是整批。
        tip: l.batchCancelWholeBatch,
        onTap: () => unawaited(
          runBatchSlotAction(
            context,
            ref,
            () => controller().cancelBatch(slot.jobId),
          ),
        ),
      ),
    };
  }
}
