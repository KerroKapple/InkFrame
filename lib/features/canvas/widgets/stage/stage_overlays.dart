// 舞台外围的浮层（从 canvas_view.dart 原样搬出）：挂起定位请求的落地（PendingFocusApplier）、
// 多选计数 chip、连线模式提示条、节点加载失败整屏。各插槽只 watch 自己那一小份状态。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_focus_request.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/canvas_transform_controller.dart';
import '../../providers/link_mode_controller.dart';
import '../left_rail/left_rail_actions.dart';

/// 挂起的定位请求（canvas_focus_request.dart）在本画布落地：节点已载入（本层只在 data 分支里）、
/// 视口已上报尺寸之后，帧后单选 + 移到视口中心，并消费掉请求。
///
/// 跨画布定位时本画布是切过去才挂上来的；直接在切换那一刻写选中会被 autoDispose 回收。
/// 请求的节点不在本画布（已删）时只消费、不定位。
class PendingFocusApplier extends ConsumerStatefulWidget {
  const PendingFocusApplier({
    super.key,
    required this.canvasId,
    required this.nodes,
    required this.child,
  });

  final String canvasId;
  final List<CanvasNode> nodes;
  final Widget child;

  @override
  ConsumerState<PendingFocusApplier> createState() => _PendingFocusApplierState();
}

class _PendingFocusApplierState extends ConsumerState<PendingFocusApplier> {
  @override
  Widget build(BuildContext context) {
    final CanvasFocusRequest? request = ref.watch(canvasFocusRequestProvider);
    // 视口尺寸恒 watch：本层自己给这个 autoDispose provider 保活，不指望外层碰巧有人订阅
    // （生产里 CanvasShortcuts 也 watch 着，但落地不该依赖它）。重建只到本层——返回的是
    // 同一个 child 实例，舞台不跟着重建。
    final Size viewport = ref.watch(canvasViewportSizeProvider(widget.canvasId));
    if (request != null && request.canvasId == widget.canvasId && !viewport.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _land(request));
    }
    return widget.child;
  }

  void _land(CanvasFocusRequest request) {
    if (!mounted || ref.read(canvasFocusRequestProvider) != request) return;
    ref.read(canvasFocusRequestProvider.notifier).consume(request);
    for (final CanvasNode node in widget.nodes) {
      if (node.id == request.nodeId) {
        if (request.center) {
          focusNodeOnCanvas(ref, canvasId: widget.canvasId, node: node);
        } else {
          ref.read(canvasSelectionControllerProvider(widget.canvasId).notifier).select(node.id);
        }
        return;
      }
    }
  }
}

class SelectionCountChip extends StatelessWidget {
  const SelectionCountChip({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Material(
      color: colors.surface3,
      borderRadius: BorderRadius.circular(InkRadius.pill),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md,
          vertical: InkSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline, size: 14, color: colors.accent),
            const SizedBox(width: InkSpacing.xs),
            Text(
              context.l10n.canvasSelectionCount(count),
              style: typo.meta.copyWith(color: colors.fg1),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkHintBanner extends StatelessWidget {
  const LinkHintBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Material(
      color: colors.surface3,
      borderRadius: BorderRadius.circular(InkRadius.md),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md,
          vertical: InkSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 16, color: colors.accent),
            const SizedBox(width: InkSpacing.sm),
            Flexible(
              child: Text(
                context.l10n.linkModeHint,
                style: typo.body.copyWith(color: colors.fg1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasLoadError extends StatelessWidget {
  const CanvasLoadError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      color: colors.surface1,
      padding: const EdgeInsets.all(InkSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.canvasLoadFailed,
              style: typo.body.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.sm),
            Text(
              message,
              style: typo.meta.copyWith(color: colors.fg3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 链接提示条插槽：仅随 linkMode 变化重建。
class LinkHintSlot extends ConsumerWidget {
  const LinkHintSlot({super.key, required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(linkModeControllerProvider(canvasId)) != null;
    return active ? const LinkHintBanner() : const SizedBox.shrink();
  }
}

/// 多选计数 chip 插槽：仅随选中数量变化重建。
class SelectionCountSlot extends ConsumerWidget {
  const SelectionCountSlot({super.key, required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      canvasSelectionControllerProvider(canvasId).select((s) => s.length),
    );
    if (count < 2) return const SizedBox.shrink();
    return SelectionCountChip(count: count);
  }
}
