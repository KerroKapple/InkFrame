// 泳道工具栏（Lanes 稿）：画布右下角，surface4 底 + control 边 + 圆角 3；
// 「+」30×26 带右分隔线 | 方向键 = 图标（随当前方向变）+ 「横向 / 竖向」文字标签。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/canvas_lanes_controller.dart';
import '../util/lane_geometry.dart';
import 'lane_edit_dialog.dart';

class LaneToolbar extends ConsumerWidget {
  const LaneToolbar({super.key, required this.canvasId});

  final String canvasId;

  static const double height = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dir = ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
        LaneDirection.horizontal;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l10n = context.l10n;
    final bool horizontal = dir == LaneDirection.horizontal;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.surface4,
        border: Border.all(color: colors.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 添加泳道
          _Key(
            tooltip: l10n.laneAdd,
            onTap: () => _onAdd(context, ref),
            child: Container(
              width: 30,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: colors.control))),
              child: Icon(Icons.add, size: InkSpacing.md, color: colors.fg3),
            ),
          ),
          // 方向切换：图标随当前方向变 + 文字标签（稿）。
          _Key(
            tooltip: l10n.laneDirectionToggle,
            onTap: () => _onToggleDirection(context, ref, dir),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
              child: Row(
                children: <Widget>[
                  Icon(horizontal ? Icons.swap_vert : Icons.swap_horiz, size: InkSpacing.s12, color: colors.fg3),
                  const SizedBox(width: InkSpacing.s6),
                  Text(
                    horizontal ? l10n.laneDirectionHorizontal : l10n.laneDirectionVertical,
                    style: typo.meta.copyWith(color: colors.fg3, height: 1.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAdd(BuildContext context, WidgetRef ref) async {
    final r = await showLaneEditDialog(context);
    if (r == null) return;
    if (!context.mounted) return;
    final ctx = context;
    // 不 await：fire-and-forget，失败走 snackbar。
    unawaited(() async {
      try {
        await ref
            .read(canvasLanesControllerProvider(canvasId).notifier)
            .createLane(
              label: r.label,
              stylePrompt: r.stylePrompt,
              tintColor: r.tintColor,
            );
      } on InkError catch (_) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(ctx.l10n.laneCreateFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }());
  }

  /// 切换方向并持久化；失败走 snackbar（与新增泳道一致的错误反馈）。
  Future<void> _onToggleDirection(
    BuildContext context,
    WidgetRef ref,
    LaneDirection dir,
  ) async {
    final flipped = dir == LaneDirection.horizontal
        ? LaneDirection.vertical
        : LaneDirection.horizontal;
    try {
      await setLaneDirection(ref, canvasId, flipped);
    } on InkError catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.laneUpdateFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 工具栏里的一枚键：tooltip + 语义 + 手型光标。
class _Key extends StatelessWidget {
  const _Key({required this.tooltip, required this.onTap, required this.child});
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
          ),
        ),
      );
}
