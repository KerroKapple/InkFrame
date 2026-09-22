// CanvasHeaderBar：画布头 29px（稿 28 + 1px 下沿）——画布名 | 竖线 | 泳道名 | 撑开 | 缩放 %。
// 稿右侧还有「自动保存 · 2 秒前」：仓库没有自动保存状态，不画（缺什么问用户）。
//
// CanvasZoomBar：右下浮动缩放条（− / % / + / 适应），绑定 canvasTransformController。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_name.dart';
import '../util/canvas_zoom.dart';

class CanvasHeaderBar extends ConsumerWidget {
  const CanvasHeaderBar({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：height 28 + border-bottom 1。
  static const double height = 29;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String name = ref.watch(currentCanvasNameProvider).valueOrNull ?? l.canvasDefaultName;
    final List<StyleLane> lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ?? const <StyleLane>[];
    final TransformationController transform = ref.watch(canvasTransformControllerProvider(canvasId));

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          // 画布名 + 泳道列表放在自己的子行里按内容分宽、超长各自省略——
          // 不能把它们直接做成外层 Row 的 Flexible：那会和右侧的 Spacer 均分剩余宽度，
          // 把缩放读数往左推（画布 golden 抓到过这一刀）。
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.fg1)),
                ),
                if (lanes.isNotEmpty) ...<Widget>[
                  const SizedBox(width: InkSpacing.s12),
                  Container(width: 1, height: 12, color: c.control),
                  const SizedBox(width: InkSpacing.s12),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        style: t.body.copyWith(color: c.fg5),
                        children: <InlineSpan>[
                          TextSpan(text: l.canvasHeaderLanes),
                          for (int i = 0; i < lanes.length; i++) ...<InlineSpan>[
                            if (i > 0) const TextSpan(text: ' · '),
                            TextSpan(
                              text: lanes[i].label.isEmpty ? l.laneUntitled : lanes[i].label,
                              style: TextStyle(color: c.fg3),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<Matrix4>(
            valueListenable: transform,
            builder: (BuildContext context, Matrix4 m, _) => Text(
              '${(scaleOf(m) * 100).round()}%',
              style: t.mono.copyWith(color: c.fg5),
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasZoomBar extends ConsumerWidget {
  const CanvasZoomBar({super.key, required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final TransformationController transform = ref.watch(canvasTransformControllerProvider(canvasId));

    void zoom(double factor) {
      transform.value = zoomedTransform(
        current: transform.value,
        factor: factor,
        viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ZoomCell(width: 27, onTap: () => zoom(1 / kCanvasZoomStep), borderRight: true,
              child: Text('−', style: t.body.copyWith(color: c.fg3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: transform,
              builder: (BuildContext context, Matrix4 m, _) =>
                  Text('${(scaleOf(m) * 100).round()}%', style: t.mono.copyWith(color: c.fg3)),
            ),
          ),
          _ZoomCell(width: 27, onTap: () => zoom(kCanvasZoomStep), borderLeft: true,
              child: Text('+', style: t.body.copyWith(color: c.fg3))),
          _ZoomCell(width: 41, onTap: () => transform.value = initialCanvasTransform(), borderLeft: true,
              child: Text(context.l10n.canvasZoomFit, style: t.meta.copyWith(color: c.fg3))),
        ],
      ),
    );
  }
}

class _ZoomCell extends StatelessWidget {
  const _ZoomCell({
    required this.width,
    required this.onTap,
    required this.child,
    this.borderLeft = false,
    this.borderRight = false,
  });
  final double width;
  final VoidCallback onTap;
  final Widget child;
  final bool borderLeft;
  final bool borderRight;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            left: borderLeft ? BorderSide(color: c.control) : BorderSide.none,
            right: borderRight ? BorderSide(color: c.control) : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}
