// BatchCompareOverlay：批量结果的足尺并排对比浮层。
//
// 稿（Batch and Characters §02）：1080 content 宽 + 1px 边 ×2 = 1082 外框；
// 头 39（38 content + 1px 下沿）/ 体 padding 14 / 脚 1px 上沿。窗口窄于 1082 时
// 按可用宽收缩——稿是在 2600px 长图上量的，真实窗口没有这个保证。
//
// 键盘：←→ 切换选中格、↵ 转正当前格、Esc 关闭（Esc 由 showDialog 的 DismissIntent
// 处理，本组件刻意不吞它）。
//
// 「叠加对比」在不做清单里：画成禁用标签（不是可点按钮）+ tooltip 说明，
// 不留空回调。「全部存入画廊」也不做——slot 本来就在画廊里，那个按钮是空操作。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../generation/providers/batch_job_progress.dart';
import '../../generation/providers/batch_results_controller.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';
import '../util/batch_slot_view.dart';
import 'batch_slot_parts.dart';

/// 稿上的外框宽（1080 content + 1px 边 ×2）。窗口更窄时取可用宽。
const double kBatchCompareOverlayWidth = 1082;

/// 选中格的高亮环。挂 Key 纯为可测：浮层里同形状的 DecoratedBox 满地都是，
/// 没有稳定锚点就没法断言「←→ 之后环落在哪一格」。
const Key kBatchSlotSelectedRingKey = ValueKey<String>('batchSlotSelectedRing');

Future<void> showBatchCompareOverlay(
  BuildContext context, {
  required CanvasNode resultNode,
}) => showDialog<void>(
  context: context,
  barrierColor: context.inkColors.scrim,
  builder: (_) => Dialog(
    insetPadding: const EdgeInsets.all(InkSpacing.xl),
    backgroundColor: Colors.transparent,
    // 浮层高度随 slot 数与产物比例走；窗口矮时让它滚，不要溢出报错。
    child: SingleChildScrollView(
      child: BatchCompareOverlay(resultNode: resultNode),
    ),
  ),
);

class BatchCompareOverlay extends ConsumerStatefulWidget {
  const BatchCompareOverlay({super.key, required this.resultNode});

  final CanvasNode resultNode;

  @override
  ConsumerState<BatchCompareOverlay> createState() =>
      _BatchCompareOverlayState();
}

class _BatchCompareOverlayState extends ConsumerState<BatchCompareOverlay> {
  /// ←→ 的落点。开着的时候 slot 数可能变（生成推进/重跑），读的时候一律 clamp。
  int _selected = 0;

  String? get _configNodeId => widget.resultNode.sourceNodeId;

  BatchResultsController get _controller =>
      ref.read(batchResultsControllerProvider(widget.resultNode.id).notifier);

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final async = ref.watch(
      batchResultsControllerProvider(widget.resultNode.id),
    );
    final slots = async.valueOrNull ?? const <BatchResult>[];
    // 收敛只落在本次渲染的局部量上：slot 数量会随刷新变化，但 build 里改 state 是
    // 一条会自己发散的路（clamp 后的值再被按键逻辑读到，顺序就说不清了）。
    final int selected = slots.isEmpty
        ? 0
        : _selected.clamp(0, slots.length - 1);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double width = box.maxWidth.isFinite
            ? math.min(kBatchCompareOverlayWidth, box.maxWidth)
            : kBatchCompareOverlayWidth;
        return Focus(
          autofocus: true,
          onKeyEvent: (_, KeyEvent event) => _onKey(event, slots),
          child: SizedBox(
            width: width,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface3,
                border: Border.all(color: c.control),
                borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
                boxShadow: InkShadow.overlay,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _header(context, slots),
                  Padding(
                    padding: const EdgeInsets.all(InkSpacing.s14),
                    child: async.hasError
                        ? InkErrorBanner(
                            message: l10nAsyncError(context, async.error!),
                          )
                        : _slotRow(slots, selected),
                  ),
                  _footer(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ 键盘

  KeyEventResult _onKey(KeyEvent event, List<BatchResult> slots) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (slots.isEmpty) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _selected = (_selected - 1 + slots.length) % slots.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _selected = (_selected + 1) % slots.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final BatchResult slot = slots[_selected.clamp(0, slots.length - 1)];
      // 只有「可转正」的格才响应 ↵；已是当前产物 / 失败 / 生成中都不该被回车误触。
      if (!batchSlotCanPromote(slot)) return KeyEventResult.handled;
      unawaited(
        runBatchSlotAction(context, ref, () => _controller.promote(slot)),
      );
      return KeyEventResult.handled;
    }
    // Esc 交给 showDialog 的 DismissIntent，本组件不吞。
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------------ 头/脚

  Widget _header(BuildContext context, List<BatchResult> slots) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String? meta = _metaLine(slots);
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              l.batchOverlayTitle(widget.resultNode.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(color: c.fg1),
            ),
          ),
          if (meta != null) ...<Widget>[
            const SizedBox(width: InkSpacing.s12),
            Flexible(
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.mono.copyWith(color: c.fg5),
              ),
            ),
          ],
          const Spacer(),
          // 并排 = 当前模式（选中态）；叠加对比 = 未实现（禁用态标签，非按钮）。
          Text(l.batchModeSideBySide, style: t.body.copyWith(color: c.fg1)),
          const SizedBox(width: InkSpacing.s12),
          Tooltip(
            message: l.batchModeStackedUnavailable,
            child: Text(l.batchModeStacked, style: t.body.copyWith(color: c.fg6)),
          ),
          const SizedBox(width: InkSpacing.s12),
          Text(l.settingsEscHint, style: t.monoSmall.copyWith(color: c.fg6)),
        ],
      ),
    );
  }

  /// 头部元信息：产物真实像素尺寸。稿上还有 provider 与 job 短号——
  /// result 节点身上没有 provider id，「job」这个词也没有对应 ARB 键，故只留尺寸。
  String? _metaLine(List<BatchResult> slots) {
    for (final BatchResult s in slots) {
      final int? w = s.width;
      final int? h = s.height;
      if (w != null && h != null && w > 0 && h > 0) return '$w×$h';
    }
    return null;
  }

  Widget _footer(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s14,
        vertical: InkSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              l.batchOverlayHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.meta.copyWith(color: c.fg6),
            ),
          ),
          const Spacer(),
          BatchTappable(
            semanticLabel: l.batchDone,
            onTap: () => Navigator.of(context).pop(),
            child: WsPrimaryButton(
              l.batchDone,
              height: 26,
              horizontalPadding: InkSpacing.s14,
              bordered: false,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 格

  Widget _slotRow(List<BatchResult> slots, int selected) {
    if (slots.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      if (i > 0) children.add(const SizedBox(width: InkSpacing.s12));
      children.add(
        Expanded(
          child: _OverlaySlot(
            slot: slots[i],
            node: widget.resultNode,
            selected: i == selected,
            configNodeId: _configNodeId,
          ),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _OverlaySlot extends ConsumerWidget {
  const _OverlaySlot({
    required this.slot,
    required this.node,
    required this.selected,
    required this.configNodeId,
  });

  final BatchResult slot;
  final CanvasNode node;
  final bool selected;
  final String? configNodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final BatchSlotView view = batchSlotViewOf(slot);
    final bool promoted = view == BatchSlotView.promoted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: batchSlotAspectRatio(slot),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.thumbFill,
              borderRadius: BorderRadius.circular(InkRadius.sm),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: promoted ? c.accent : c.outline,
                width: promoted ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(InkRadius.sm),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (view == BatchSlotView.success ||
                    view == BatchSlotView.promoted)
                  BatchSlotImage(slot: slot, node: node, decodeWidth: 540),
                // 选中环画在转正环里侧（内缩 2），两者同时出现时互不遮挡。
                // 稿是静态图、没有选中概念；←→ 需要一个看得见的落点，这里补上。
                if (selected)
                  Padding(
                    key: kBatchSlotSelectedRingKey,
                    padding: const EdgeInsets.all(InkSpacing.s2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: c.fg1),
                        borderRadius: BorderRadius.circular(InkRadius.xs),
                      ),
                    ),
                  ),
                Positioned(
                  left: InkSpacing.sm,
                  top: InkSpacing.s6,
                  // 稿上浮层写全「slot #1」，检查器内联格才是短的「#1」——浮层里
                  // 一屏只有两格，写全比省两个词更清楚。
                  child: Text(
                    l.batchSlotBadge(slot.slotIndex + 1),
                    style: t.monoSmall.copyWith(
                      color: c.fg1.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (promoted)
                  Positioned(
                    right: InkSpacing.sm,
                    top: InkSpacing.s6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: InkSpacing.s7,
                        vertical: InkSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(InkRadius.xs),
                      ),
                      child: Text(
                        l.batchCurrentArtifact,
                        style: t.micro.copyWith(color: c.onAccent),
                      ),
                    ),
                  ),
                if (view == BatchSlotView.generating) _generating(context, ref),
                if (view == BatchSlotView.error) _error(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(l.inspectorSeedLabel, style: t.meta.copyWith(color: c.fg4)),
            const SizedBox(width: InkSpacing.sm),
            Text(
              slot.seed?.toString() ?? kBatchSeedPlaceholder,
              style: t.mono.copyWith(color: c.fg2),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        _actions(context, ref, view),
      ],
    );
  }

  /// 每次动作现取 notifier：provider 被 invalidate 后旧实例是死的，不能缓存在字段上。
  BatchResultsController _controller(WidgetRef ref) =>
      ref.read(batchResultsControllerProvider(node.id).notifier);

  /// 生成中：细进度条 + 百分比。进度取自 jobsRegistry；注册表里没有这条 job
  /// （进程重启后读库的历史 slot）时不画条，只留「生成中」。
  Widget _generating(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final double? progress = ref.watch(batchJobProgressProvider(slot.jobId));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (progress != null) ...<Widget>[
          SizedBox(
            width: 60,
            height: 3,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.control,
                      borderRadius: BorderRadius.circular(InkRadius.xs),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 60 * progress.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(InkRadius.xs),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s6),
        ],
        Text(
          progress == null
              ? context.l10n.batchStateGenerating
              : context.l10n.batchGeneratingPercent((progress * 100).round()),
          style: t.meta.copyWith(color: c.fg5),
        ),
      ],
    );
  }

  /// 失败：✕ + 本地化文案 + errorCode 原串。原串**只在浮层露出**——
  /// 检查器格宽不到 140，塞不下且没有诊断场景；这里是用户找支持时要报的那一串。
  Widget _error(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final code = InkErrorCode.fromWire(slot.errorCode ?? '');
    final String? raw = slot.errorCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '✕',
            style: t.sectionTitle.copyWith(
              color: c.danger,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: InkSpacing.s6),
          Text(
            l10nErrorCode(context, code),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.meta.copyWith(color: c.danger),
          ),
          if (raw != null && raw.isNotEmpty) ...<Widget>[
            const SizedBox(height: InkSpacing.s6),
            // 稿这行是 sans 不是 mono（不是 errorCode 就反射性上等宽）。
            Text(
              raw,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.micro.copyWith(color: c.fg6),
            ),
          ],
        ],
      ),
    );
  }

  /// 主按钮（整宽）+ ⎘ 以该种子重跑。
  Widget _actions(BuildContext context, WidgetRef ref, BatchSlotView view) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    // 溯源 config 节点不在（孤儿 result）时重跑整条路都走不通：不画，不留死控件。
    final String? cfg = configNodeId;
    final bool canRerun = cfg != null;
    final bool canRerunSeed = canRerun && slot.seed != null;

    final Widget main = switch (view) {
      // 已是当前产物：状态徽标，不是按钮。
      BatchSlotView.promoted => Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accentWash,
          border: Border.all(color: c.accent),
          borderRadius: BorderRadius.circular(InkRadius.s3),
        ),
        child: Text(
          l.batchCurrentArtifact,
          style: t.bodyStrong.copyWith(color: c.fg1),
        ),
      ),
      BatchSlotView.success => BatchTappable(
        semanticLabel: l.batchSetArtifact,
        onTap: () => unawaited(
          runBatchSlotAction(context, ref, () => _controller(ref).promote(slot)),
        ),
        child: WsSecondaryButton(l.batchSetArtifact, height: 26),
      ),
      BatchSlotView.error when canRerun => BatchTappable(
        semanticLabel: l.batchRerunThisSlot,
        // 稿上的字是「重跑此 slot」，可 provider 一次调用返 N 张，没有「只补第 3 张」
        // 这种请求：点下去是整批重来、产物落新节点。字照稿不动，代价由 tooltip 说清，
        // 与「取消」那颗同例。
        tooltip: l.batchRerunWholeBatchHint,
        onTap: () => unawaited(
          runBatchSlotAction(
            context,
            ref,
            () => _controller(ref).rerun(configNodeId: cfg),
          ),
        ),
        child: WsSecondaryButton(l.batchRerunThisSlot, height: 26),
      ),
      BatchSlotView.error => const SizedBox.shrink(),
      BatchSlotView.generating => BatchTappable(
        semanticLabel: l.batchActionCancel,
        // per-slot 取消不成立：一次 provider 调用返 N 张，只能整批取消。
        tooltip: l.batchCancelWholeBatch,
        onTap: () => unawaited(
          runBatchSlotAction(
            context,
            ref,
            () => _controller(ref).cancelBatch(slot.jobId),
          ),
        ),
        child: WsSecondaryButton(l.batchActionCancel, height: 26),
      ),
    };

    return Row(
      children: <Widget>[
        Expanded(child: main),
        if (canRerun) ...<Widget>[
          const SizedBox(width: InkSpacing.s6),
          BatchTappable(
            semanticLabel: l.batchRerunWithSeed,
            tooltip: canRerunSeed
                ? l.batchRerunWholeBatchHint
                : l.batchRerunWithSeedUnavailable,
            onTap: canRerunSeed
                ? () => unawaited(
                    runBatchSlotAction(
                      context,
                      ref,
                      () => _controller(ref).rerun(
                        configNodeId: cfg,
                        seedOverride: slot.seed,
                      ),
                    ),
                  )
                : null,
            child: Container(
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: canRerunSeed ? c.controlStrong : c.outline,
                ),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Text(
                '⎘',
                // 置灰前景稿上是 #4A4A4A，前景槽位里没有这档；overlayBorder 恰为该值，借槽。
                style: t.body.copyWith(
                  color: canRerunSeed ? c.fg4 : c.overlayBorder,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
