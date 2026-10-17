// CanvasCapsuleHost：画布轻提示胶囊在舞台上的宿主（GapsCanvas 稿 ›「画布轻提示胶囊」）。
//
// 只管「画在哪、什么时候画、怎么换」：内容与计时在 providers/canvas_capsule.dart，长相在 theme 层的 InkCanvasCapsule。
// 它是舞台 Stack 的直接孩子（build 返回 Positioned），挂在 canvas_screen.dart 的提示词条之后、浮动工具条之前。
//
// - 位置：舞台水平居中；提示词条显示（量得高 h > 0）时底边离舞台底 h + barGap（= 条子上方 8），收起时离舞台底 16；
//   h 变了跟着动。两侧各让出 sideReserve（缩放条 + 16），左右对称所以仍居中；超长文字省略号。
//   让位后剩下的宽度不到 minWidth 就不画（计时照走）。查找条在顶部，互不避让。
// - 换卡：AnimatedSwitcher 120ms 交叉淡入；卡的 key 是控制器的 serial——同 dedupeKey 原地改字时 serial 不变，
//   不重放淡入，读屏也不新增节点。
// - 悬停停表：MouseRegion 只包胶囊本身（空白处照样点得到画布），进出报给控制器。
// - visible = false（换到别的标签）：当帧画空，帧后 dismiss——不在 build / didUpdateWidget 里同步改 provider
//   （Riverpod 不许在 widget 树构建中改 provider）。回来时状态已经清了，不重放。
// - 动作按钮只给鼠标（InkCanvasCapsule 里包了 ExcludeFocus）；点了先调 onAction 再收起。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_canvas_capsule.dart';
import '../../../theme/tokens.dart';
import '../providers/canvas_capsule.dart';
import '../providers/canvas_prompt_bar_height.dart';

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

    return Positioned(
      left: InkCanvasCapsuleSize.sideReserve,
      right: InkCanvasCapsuleSize.sideReserve,
      bottom: barHeight > 0 ? barHeight + InkCanvasCapsuleSize.barGap : InkCanvasCapsuleSize.stageBottom,
      child: widget.visible
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < InkCanvasCapsuleSize.minWidth) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: MouseRegion(
                    onEnter: (_) => _controller.setHovered(true),
                    onExit: (_) => _controller.setHovered(false),
                    child: AnimatedSwitcher(
                      duration: InkMotion.fast,
                      child: message == null ? null : _capsule(context, message),
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
