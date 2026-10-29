// 框选的视口层（Selection 稿「框选与加减选」）：画框与「已选 N」芯片，外加三件跟框选同生共死的事——
//   - 修饰键实时监听：拖到一半按 / 松 Shift、Ctrl、⌘ 立即重算（不等指针再动；KeyMap「拖到一半按修饰键即时生效」）；
//   - 贴边自动平移：指针离视口任一边不到 InkMarquee.autoPanZone 时每帧挪相机，越靠边越快，最多
//     InkMarquee.autoPanMaxStep；离开触发区 / 松手 / Esc 即停；
//   - Esc 阶梯的 marquee 档：框选中按 Esc 只收框并恢复按下前的选中，不再往下清空选中。
// 相机一变（自动平移、滚轮缩放）就按指针的全局坐标把框的当前角换回舞台坐标、重算命中——框的起点钉在世界里，
// 当前角始终在指针下。
//
// 本层在视口坐标系（舞台 LayoutBuilder 的 Stack 末尾，IgnorePointer 包着，不收指针），只有它 watch
// canvasMarqueeProvider：拖框只重建这一层与选中翻转的那几张卡。命中判据不在这里，在 CanvasMarqueeController。
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/canvas_escape_ladder.dart';
import '../providers/canvas_marquee.dart';
import '../util/escape_ladder.dart';

class MarqueeLayer extends ConsumerStatefulWidget {
  const MarqueeLayer({
    super.key,
    required this.canvasId,
    required this.transform,
    required this.viewport,
  });

  /// 测试锚点：框。
  static const Key frameKey = ValueKey<String>('marquee-frame');

  /// 测试锚点：「已选 N」芯片。
  static const Key chipKey = ValueKey<String>('marquee-chip');

  final String canvasId;
  final TransformationController transform;

  /// 视口尺寸（= 本层尺寸）：芯片右对齐与贴边判距用。
  final Size viewport;

  @override
  ConsumerState<MarqueeLayer> createState() => _MarqueeLayerState();
}

class _MarqueeLayerState extends ConsumerState<MarqueeLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _autoPan;

  /// 登记了 marquee 档的那一张画布的阶梯。dispose 里对它注销（不在 dispose 里用 ref）。
  CanvasEscapeLadder? _ladder;

  @override
  void initState() {
    super.initState();
    _autoPan = createTicker(_onAutoPanTick);
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.transform.addListener(_onTransform);
    _attachLadder(widget.canvasId);
  }

  @override
  void didUpdateWidget(MarqueeLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transform != widget.transform) {
      oldWidget.transform.removeListener(_onTransform);
      widget.transform.addListener(_onTransform);
    }
    if (oldWidget.canvasId != widget.canvasId) {
      _ladder?.unregister(EscapeRungId.marquee);
      _attachLadder(widget.canvasId);
    }
  }

  @override
  void dispose() {
    _ladder?.unregister(EscapeRungId.marquee);
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.transform.removeListener(_onTransform);
    _autoPan.dispose();
    super.dispose();
  }

  /// 往画布 [canvasId] 的 Esc 阶梯登记 marquee 档（层序在拖线之后、连线模式之前，见 util/escape_ladder.dart）。
  /// 阶梯是 autoDispose，保活锚在 CanvasShortcuts.build；实例存进字段，注销时不必再经 ref。
  void _attachLadder(String canvasId) {
    final CanvasEscapeLadder ladder = ref.read(canvasEscapeLadderProvider(canvasId));
    ladder.register(EscapeRungId.marquee, (
      isActive: () => mounted && ref.read(canvasMarqueeProvider(canvasId)) != null,
      dismiss: () => ref.read(canvasMarqueeProvider(canvasId).notifier).cancel(),
    ));
    _ladder = ladder;
  }

  CanvasMarqueeController get _controller =>
      ref.read(canvasMarqueeProvider(widget.canvasId).notifier);

  MarqueeState? get _state => ref.read(canvasMarqueeProvider(widget.canvasId));

  /// 修饰键按下 / 松开：框选中就按新的修饰键重算。不吞键（返回 false），别处照常收到。
  bool _onKey(KeyEvent event) {
    if (!mounted || _state == null) return false;
    _controller.setMode(currentMarqueeMode());
    return false;
  }

  /// 全局坐标 → 本层（视口）局部坐标；还没布局 ⇒ null。
  Offset? _toViewport(Offset global) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  /// 相机变了：框的当前角按指针此刻的位置换回舞台坐标，重算命中。
  void _onTransform() {
    if (!mounted) return;
    final MarqueeState? s = _state;
    final Offset? pointer = s?.pointerGlobal;
    if (pointer == null) return;
    final Offset? viewportPoint = _toViewport(pointer);
    if (viewportPoint == null) return;
    _controller.update(
      widget.transform.toScene(viewportPoint),
      pointerGlobal: pointer,
    );
  }

  /// 指针在 [s] 的位置这一帧该把内容往哪挪（屏幕 px）；不在触发区 ⇒ Offset.zero。
  ///
  /// 离某条边的距离 d < autoPanZone：步长 = autoPanMaxStep × (1 − d / autoPanZone)，至少 1；指针已出视口
  /// （d < 0）按最大步长。指针在右缘 ⇒ 内容往左挪（看右边），其余三边同理。
  Offset _autoPanDelta(MarqueeState? s) {
    final Offset? pointer = s?.pointerGlobal;
    if (pointer == null) return Offset.zero;
    final Offset? p = _toViewport(pointer);
    if (p == null) return Offset.zero;
    final Size size = widget.viewport;
    double step(double distance) {
      final double d = distance < 0 ? 0 : distance;
      final double s =
          InkMarquee.autoPanMaxStep * (1 - d / InkMarquee.autoPanZone);
      return s < 1 ? 1 : s;
    }

    double axis(double toStart, double toEnd) {
      if (toStart < InkMarquee.autoPanZone) return step(toStart);
      if (toEnd < InkMarquee.autoPanZone) return -step(toEnd);
      return 0;
    }

    return Offset(
      axis(p.dx, size.width - p.dx),
      axis(p.dy, size.height - p.dy),
    );
  }

  /// 框选状态变了：该自动平移就开 Ticker，不该了就停。
  void _syncAutoPan(MarqueeState? next) {
    final bool want = next != null && _autoPanDelta(next) != Offset.zero;
    if (want && !_autoPan.isActive) {
      _autoPan.start();
    } else if (!want && _autoPan.isActive) {
      _autoPan.stop();
    }
  }

  void _onAutoPanTick(Duration _) {
    if (!mounted) return;
    final Offset delta = _autoPanDelta(_state);
    if (delta == Offset.zero) {
      _autoPan.stop();
      return;
    }
    // 屏幕空间平移：左乘。改完相机，_onTransform 把框的当前角重新换算并重算命中。
    widget.transform.value =
        Matrix4.translationValues(delta.dx, delta.dy, 0)..multiply(widget.transform.value);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MarqueeState?>(
      canvasMarqueeProvider(widget.canvasId),
      (_, MarqueeState? next) => _syncAutoPan(next),
    );
    final MarqueeState? s = ref.watch(canvasMarqueeProvider(widget.canvasId));
    if (s == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: widget.transform,
        builder: (BuildContext context, Matrix4 m, _) {
          final Rect r = MatrixUtils.transformRect(m, s.stageRect);
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fromRect(
                rect: r,
                child: const _MarqueeFrame(key: MarqueeLayer.frameKey),
              ),
              // 芯片压在框右下角：右沿对齐框右沿，下沿比框下沿低 chipOverlap。
              Positioned(
                right: widget.viewport.width - r.right,
                top: r.bottom + InkMarquee.chipOverlap - InkMarquee.chipHeight,
                height: InkMarquee.chipHeight,
                child: _MarqueeChip(key: MarqueeLayer.chipKey, count: s.selectedCount),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 框：1px accent 边 + accent 8% 底、圆角 1。
class _MarqueeFrame extends StatelessWidget {
  const _MarqueeFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: InkMarquee.fillAlpha),
        border: Border.all(color: colors.accent, width: InkMarquee.borderWidth),
        borderRadius: BorderRadius.circular(InkMarquee.radius),
      ),
    );
  }
}

/// 「已选 N」芯片：胶囊、surface4 底 + overlayBorder 边、fg2 等宽 10 号。
class _MarqueeChip extends StatelessWidget {
  const _MarqueeChip({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface4,
        border: Border.all(color: colors.overlayBorder, width: InkMarquee.borderWidth),
        borderRadius: BorderRadius.circular(InkRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkMarquee.chipPaddingH),
        child: Center(
          widthFactor: 1,
          child: Text(
            context.l10n.canvasMarqueeCount(count),
            maxLines: 1,
            style: typo.monoSmall.copyWith(color: colors.fg2),
          ),
        ),
      ),
    );
  }
}
