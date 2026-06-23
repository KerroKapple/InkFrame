// 泳道工具栏：添加泳道 + 方向切换，紧凑 token 化容器。
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dir = ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
        LaneDirection.horizontal;
    final colors = context.inkColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.xs,
        vertical: InkSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(InkRadius.md),
        boxShadow: InkShadow.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 添加泳道
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.laneAdd,
            color: colors.fg1,
            onPressed: () => _onAdd(context, ref),
          ),
          // 方向切换
          IconButton(
            icon: Icon(
              dir == LaneDirection.horizontal
                  ? Icons.swap_horiz
                  : Icons.swap_vert,
            ),
            tooltip: context.l10n.laneDirectionToggle,
            color: colors.fg1,
            onPressed: () => _onToggleDirection(context, ref, dir),
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
