// CanvasCapsuleHost：画布轻提示胶囊在舞台上的宿主（GapsCanvas 稿 ›「画布轻提示胶囊」）。
//
// 只管「画在哪、什么时候画、怎么换」：内容与计时在 providers/canvas_capsule.dart，长相在 theme 层的 InkCanvasCapsule。
// 它是舞台 Stack 的直接孩子（build 返回 Positioned），挂在 canvas_screen.dart 的提示词条之后、浮动工具条之前。
//
// - 位置：提示词条显示（量得高 h > 0）时底边离舞台底 h + barGap（= 条子上方 8），收起时离舞台底 16；h 变了跟着动。
//   水平方向：条子显示时与条子同轴——中心取 promptBarPlacement 算出的条子中心（条子居中会压到左下那一簇时整条
//   往右让，胶囊跟着让，不另抄一份让位数字）；条子收起时在舞台正中。以中心左右对称伸展：左侧不越过 sideReserve
//   （缩放条 + 16），右侧离舞台右沿留 InkSpacing.md（与条子右侧的边距同一档）；超长文字省略号。
//   条子收起时中心在舞台正中、左侧先顶到，可用宽度与「两侧各让 sideReserve」一样。
//   让位后剩下的宽度不到 minWidth 就不画（计时照走）。查找条在顶部，互不避让。
// - 换卡：AnimatedSwitcher 120ms 交叉淡入；卡的 key 是控制器的 serial——同 dedupeKey 原地改字时 serial 不变，
//   不重放淡入，读屏也不新增节点。
// - 悬停停表：MouseRegion 只包胶囊本身（空白处照样点得到画布），进出报给控制器。
// - visible = false（换到别的标签）：当帧画空，帧后 dismiss——不在 build / didUpdateWidget 里同步改 provider
//   （Riverpod 不许在 widget 树构建中改 provider）。回来时状态已经清了，不重放。
// - 动作按钮只给鼠标（InkCanvasCapsule 里包了 ExcludeFocus）；点了先调 onAction 再收起。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_canvas_capsule.dart';
import '../../../theme/tokens.dart';
import '../providers/canvas_capsule.dart';
import '../providers/canvas_prompt_bar_height.dart';
import '../util/prompt_bar_width.dart';

/// 胶囊在宽 [stageWidth] 的舞台里能占的水平跨度：中心 center、向左右各能伸出 half（都相对舞台左沿）。
///
/// [barShown]（提示词条显示）时 center 取提示词条的中心——直接用条子自己的 [promptBarPlacement]，
/// 条子为左下那一簇让位、往右挪多少，胶囊就跟着挪多少；不显示时取舞台中心。
/// half = min(center − sideReserve，舞台宽 − InkSpacing.md − center)：左边不压缩放条，右边不出舞台。
/// 让完剩下的宽度（2 × half）不到 minWidth ⇒ null（不画）。舞台不限宽 ⇒ null（Positioned 左右都钉住时不会发生）。
({double center, double half})? _capsuleSpan(double stageWidth, {required bool barShown}) {
  if (!stageWidth.isFinite) return null;
  final double center;
  if (barShown) {
    final ({double left, double width}) bar = promptBarPlacement(stageWidth);
    center = bar.left + bar.width / 2;
  } else {
    center = stageWidth / 2;
  }
  final double half = math.min(
    center - InkCanvasCapsuleSize.sideReserve,
    stageWidth - InkSpacing.md - center,
  );
  if (2 * half < InkCanvasCapsuleSize.minWidth) return null;
  return (center: center, half: half);
}

class CanvasCapsuleHost extends ConsumerStatefulWidget {
  const CanvasCapsuleHost({super.key, required this.canvasId, this.visible = true});

  final String canvasId;

  /// 本画布页此刻是不是外壳里可见的那一标签（CanvasScreen.isVisible）。false ⇒ 立即收起。
  final bool visible;

  @override
  ConsumerState<CanvasCapsuleHost> createState() => _CanvasCapsuleHostState();
}

class _CanvasCapsuleHostState extends ConsumerState<CanvasCapsuleHost> {
  @override
  void didUpdateWidget(CanvasCapsuleHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible && !widget.visible) {
      // 当帧已按 visible 画空；改 provider 排到帧后。鼠标区域随之卸下、收不到移出，悬停一并清掉。
      final String canvasId = widget.canvasId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final CanvasCapsuleController controller =
            ref.read(canvasCapsuleProvider(canvasId).notifier);
        controller.dismiss();
        controller.setHovered(false);
      });
    }
  }

  CanvasCapsuleController get _controller =>
      ref.read(canvasCapsuleProvider(widget.canvasId).notifier);

  @override
  Widget build(BuildContext context) {
    final CanvasCapsuleMessage? message = ref.watch(canvasCapsuleProvider(widget.canvasId));
    final double barHeight = ref.watch(canvasPromptBarHeightProvider(widget.canvasId));

    // 左右都钉在舞台边上：LayoutBuilder 读到的 maxWidth 就是舞台宽——与提示词条自己的 LayoutBuilder 同一个输入，
    // 算出来的条子中心与条子实际画的位置一致。
    return Positioned(
      left: 0,
      right: 0,
      bottom: barHeight > 0 ? barHeight + InkCanvasCapsuleSize.barGap : InkCanvasCapsuleSize.stageBottom,
      child: widget.visible
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final ({double center, double half})? span =
                    _capsuleSpan(constraints.maxWidth, barShown: barHeight > 0);
                if (span == null) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: span.center - span.half),
                    child: SizedBox(
                      width: 2 * span.half,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: MouseRegion(
                          onEnter: (_) => _controller.setHovered(true),
                          onExit: (_) => _controller.setHovered(false),
                          child: AnimatedSwitcher(
                            duration: InkMotion.fast,
                            child: message == null ? null : _capsule(context, message),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _capsule(BuildContext context, CanvasCapsuleMessage m) {
    final int? percent = m.zoomPercent;
    final VoidCallback? onAction = m.onAction;
    return InkCanvasCapsule(
      key: ValueKey<int>(_controller.serial),
      text: percent != null ? context.l10n.canvasCapsuleZoom(percent) : m.text,
      actionLabel: m.actionLabel,
      actionHint: m.actionHint,
      onAction: onAction == null
          ? null
          : () {
              onAction();
              _controller.dismiss();
            },
    );
  }
}
