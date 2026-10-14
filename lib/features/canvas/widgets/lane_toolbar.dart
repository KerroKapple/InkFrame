// 泳道工具栏（Lanes 稿）：画布左下角、叠在缩放条之上，surface4 底 + control 边 + 圆角 3；
// 「+」30×26 带右分隔线 | 方向键 = 图标（随当前方向变）+ 「横向 / 竖向」文字标签。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/canvas_lanes_controller.dart';
import '../util/lane_geometry.dart';
import 'lane_edit_dialog.dart';

class LaneToolbar extends ConsumerWidget {
  const LaneToolbar({super.key, required this.canvasId});

  final String canvasId;

  static const double height = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LaneDirection> dirAsync =
        ref.watch(canvasLaneDirectionProvider(canvasId));
    final dir = dirAsync.valueOrNull ?? LaneDirection.horizontal;
    // 【不知道当前方向时，切换键必须不可点】GAP-3 评审 P3①。
    //
    // 读失败时上面那行会回落成 horizontal，切换就恒定写 vertical：如果库里本来
    // 就是 vertical，用户点多少次都是"写 vertical → 读又失败 → 显示 horizontal"，
    // 永远到不了 horizontal。二元域里不会损坏数据，但这个键在撒谎——它按一个
    // 没读到的值决定往哪边翻。所以：拿不到值（加载中或读失败）就禁用。
    // 只在读失败时换 tooltip 说明原因；加载中通常一帧就过去，没人看得到。
    final bool dirKnown = dirAsync.hasValue;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l10n = context.l10n;
    final bool horizontal = dir == LaneDirection.horizontal;
    final Color dirInk = dirKnown ? colors.fg3 : colors.fg6;

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
            tooltip: dirAsync.hasError && !dirKnown
                ? l10n.laneDirectionUnavailable
                : l10n.laneDirectionToggle,
            onTap: dirKnown ? () => _onToggleDirection(context, ref, dir) : null,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
              child: Row(
                children: <Widget>[
                  Icon(horizontal ? Icons.swap_vert : Icons.swap_horiz, size: InkSpacing.s12, color: dirInk),
                  const SizedBox(width: InkSpacing.s6),
                  Text(
                    horizontal ? l10n.laneDirectionHorizontal : l10n.laneDirectionVertical,
                    style: typo.meta.copyWith(color: dirInk, height: 1.0),
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
    // 不 await：fire-and-forget，失败弹错误通知卡。
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
        ref
            .read(toastServiceProvider)
            .show(ctx.l10n.laneCreateFailed, kind: ToastKind.error);
      }
    }());
  }

  /// 切换方向并持久化；失败弹错误通知卡（与新增泳道一致的错误反馈）。
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
      ref
          .read(toastServiceProvider)
          .show(context.l10n.laneUpdateFailed, kind: ToastKind.error);
    }
  }
}

/// 工具栏里的一枚键：tooltip + 语义 + 手型光标。
class _Key extends StatelessWidget {
  const _Key({required this.tooltip, required this.onTap, required this.child});
  final String tooltip;

  /// null ⇒ 禁用：不响应点击、光标不变手形、语义上报 disabled。禁用态给 null，
  /// 不要给空闭包（test/quality/no_dead_interactive_test.dart）。
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: tooltip,
          child: MouseRegion(
            cursor: onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
          ),
        ),
      );
}
