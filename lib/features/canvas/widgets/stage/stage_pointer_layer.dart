// 舞台的指针层（从 canvas_view.dart 原样搬出）：
//   - StagePanGate：平移生效（H / 按住空格，canvas_tool_mode.dart）时舞台内容与泳道标题栏层整层不收指针，
//     拖哪儿都是拖画布；StagePanCursor 换手形光标
//   - StageSpace / RenderStageSpace：舞台坐标系的锚，卡片插槽（node_card_slot.dart）往上找它换算拖线坐标
//   - BlankPointerDetector：空白处的双击 / 右键；SecondaryClickDetector：右键单击（空白处与卡片上共用）——
//     抬起时开、按下到抬起没挪出点击容差才开，锚点用按下点：按住右键拖动是拖画布，不开菜单

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/canvas_tool_mode.dart';
import '../canvas_shortcuts.dart';

/// 平移闸：平移生效（工具 = 平移，或按住空格）时 [child] 整层不收指针。
///
/// IgnorePointer 恒在树上、只拨 ignoring——平移开关一拨就增删包装层的话，舞台整棵子树
/// 会被卸载重挂。watch 收在这一小层：开关只重建它自己，[child] 是上游传进来的同一个
/// 实例，舞台不跟着重建。
class StagePanGate extends ConsumerWidget {
  const StagePanGate({super.key, required this.canvasId, required this.child});

  final String canvasId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IgnorePointer(
        ignoring: ref.watch(canvasPanActiveProvider(canvasId)),
        child: child,
      );
}

/// 平移时的手形光标：平移生效 = grab，按住拖动中 = grabbing；不在平移时 defer
/// （交给卡片 / 分界线自己的光标）。理由同 [StagePanGate]：MouseRegion / Listener 恒在树上，
/// 只换参数。平移时卡片与标题栏都被 [StagePanGate] 挡掉命中，它们的光标不会盖过这里。
class StagePanCursor extends ConsumerStatefulWidget {
  const StagePanCursor({super.key, required this.canvasId, required this.child});

  final String canvasId;
  final Widget child;

  @override
  ConsumerState<StagePanCursor> createState() => _StagePanCursorState();
}

class _StagePanCursorState extends ConsumerState<StagePanCursor> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool panning = ref.watch(canvasPanActiveProvider(widget.canvasId));
    final MouseCursor cursor = !panning
        ? MouseCursor.defer
        : (_pressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab);
    return Listener(
      onPointerDown: (_) {
        _setPressed(true);
        CanvasShortcuts.reclaimFocus(context);
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: MouseRegion(cursor: cursor, child: widget.child),
    );
  }
}

/// 舞台坐标系的锚：拖线时卡片插槽沿渲染树往上找它，把指针的全局坐标换成舞台坐标
/// （globalToLocal 把 InteractiveViewer 的相机一并逆掉）。本身只透传：不画、不改布局、不改命中。
class StageSpace extends SingleChildRenderObjectWidget {
  const StageSpace({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderStageSpace();
}

class RenderStageSpace extends RenderProxyBox {}

/// 空白处的双击与右键：包在连线层上——卡片盖着的地方到不了这一层，收到的就是空白处的指针。
///
/// 不用 GestureDetector 的 onDoubleTap：双击识别器一进手势竞技场，连线层原来的单击（选连线 / 点空白
/// 清选中）就得等它放弃，每一次单击都慢 300ms。这里只听原始指针事件、自己数两下，不进竞技场，单击照旧即时生效：
///   - 第一下得真是一次点击：按下到抬起没挪出点击容差（[_withinClickSlop]）——拖画布那一下不算第一下；按下时这一层上
///     没有别的指针按着——双指捏合不算；
///   - 第二下在 [kDoubleTapTimeout] 之内（从第一下按下起算）、离第一下 [kDoubleTapSlop] 之内、同一个设备落下才算，
///     落下当场报。
/// 右键单击交给 [SecondaryClickDetector]（抬起时报按下点）。回调给的是本层的局部坐标 = 舞台坐标。
class BlankPointerDetector extends StatefulWidget {
  const BlankPointerDetector({
    super.key,
    required this.onDoubleDown,
    required this.onSecondaryClick,
    required this.child,
  });

  final ValueChanged<Offset> onDoubleDown;

  /// 右键单击：给的是按下点（本层局部坐标 = 舞台坐标）。
  final ValueChanged<Offset> onSecondaryClick;
  final Widget child;

  @override
  State<BlankPointerDetector> createState() => _BlankPointerDetectorState();
}

class _BlankPointerDetectorState extends State<BlankPointerDetector> {
  /// 这一层上此刻按着的指针（双指捏合的第二根手指落下时，第一根还在这里面）。
  final Set<int> _pressed = <int>{};

  /// 候选的第一下（主键按下那一下的事件）；双击窗口一过、挪出点击容差、被别的指针打断就清掉。
  PointerDownEvent? _first;

  /// 第一下已经在点击容差内抬起——它是一次单击。没抬起之前落下的第二下不算。
  bool _firstReleased = false;

  Timer? _window;

  @override
  void dispose() {
    _window?.cancel();
    super.dispose();
  }

  void _reset() {
    _window?.cancel();
    _window = null;
    _first = null;
    _firstReleased = false;
  }

  bool _withinTapSlop(PointerDownEvent down, Offset position) => _withinClickSlop(context, down, position);

  void _onPointerDown(PointerDownEvent event) {
    final bool othersPressed = _pressed.isNotEmpty;
    _pressed.add(event.pointer);
    // 另有指针按着（双指捏合）、或不是主键（右键菜单归外面那层 SecondaryClickDetector）：都不是双击的一下，
    // 还打断候选。
    if (othersPressed || event.buttons != kPrimaryButton) {
      _reset();
      return;
    }
    final PointerDownEvent? first = _first;
    if (first != null &&
        first.device == event.device &&
        (event.position - first.position).distance <= kDoubleTapSlop) {
      _reset();
      widget.onDoubleDown(event.localPosition);
      return;
    }
    _window?.cancel();
    _first = event;
    _firstReleased = false;
    _window = Timer(kDoubleTapTimeout, _reset);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final PointerDownEvent? first = _first;
    if (first == null || _firstReleased || event.pointer != first.pointer) return;
    if (!mounted) return;
    // 第一下按着挪出了点击容差：这是在拖画布，不是单击。
    if (!_withinTapSlop(first, event.position)) _reset();
  }

  void _onPointerUp(PointerUpEvent event) {
    _pressed.remove(event.pointer);
    final PointerDownEvent? first = _first;
    if (first == null || _firstReleased || event.pointer != first.pointer) return;
    if (!mounted) return;
    if (_withinTapSlop(first, event.position)) {
      _firstReleased = true;
    } else {
      _reset();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pressed.remove(event.pointer);
    if (event.pointer == _first?.pointer) _reset();
  }

  @override
  Widget build(BuildContext context) => SecondaryClickDetector(
        onSecondaryClick: (PointerDownEvent down) =>
            widget.onSecondaryClick(down.localPosition),
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: widget.child,
        ),
      );
}

/// 一次按下到 [position] 还算不算「点」：挪过的距离没超过平移阈值（computePanSlop：鼠标 2px、触摸 kPanSlop，带上
/// 设备的手势设置）——主键在画布上真被拖起来的就是这个距离。不用单击识别器的 1px（computeHitSlop）：鼠标点一下
/// 手抖 1.5px 是常事，画布没动、用户也没在拖，双击 / 右键菜单不该因此失灵。
bool _withinClickSlop(BuildContext context, PointerDownEvent down, Offset position) =>
    (position - down.position).distance <=
        computePanSlop(down.kind, MediaQuery.maybeGestureSettingsOf(context));

/// 右键单击：次键按下 → 抬起，中间没挪出点击容差才算，**抬起时**报，交回的是按下那一下的事件（菜单锚在按下点）。
///
/// 原来按下就开菜单：按住右键拖会把画布拖走（InteractiveViewer 的缩放 / 平移识别器不挑键），菜单还钉在原处（B4）。
/// 容差见 [_withinClickSlop]——挪出去就是在拖，不是单击。
/// 只听原始指针事件、不进手势竞技场：卡片的单击 / 拖动、连线层的单击都不受影响。
class SecondaryClickDetector extends StatefulWidget {
  const SecondaryClickDetector({
    super.key,
    required this.onSecondaryClick,
    required this.child,
  });

  /// 右键单击成立。给的是按下那一下的事件：要局部坐标取 localPosition，要全局坐标取 position。
  final ValueChanged<PointerDownEvent> onSecondaryClick;
  final Widget child;

  @override
  State<SecondaryClickDetector> createState() => _SecondaryClickDetectorState();
}

class _SecondaryClickDetectorState extends State<SecondaryClickDetector> {
  /// 还没抬起的那一下右键按下；挪出容差、换了键、被取消就清掉。
  PointerDownEvent? _down;

  bool _withinSlop(PointerDownEvent down, Offset position) => _withinClickSlop(context, down, position);

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryButton) _down = event;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final PointerDownEvent? down = _down;
    if (down == null || event.pointer != down.pointer) return;
    // 拆了之后命中路径照样把这根指针的事件送来：不再判（判容差要读 context）。
    if (!mounted) return;
    if (event.buttons != kSecondaryButton || !_withinSlop(down, event.position)) {
      _down = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final PointerDownEvent? down = _down;
    if (down == null || event.pointer != down.pointer) return;
    _down = null;
    // 按着右键时这一层被拆了（卡片被删）：命中路径按指针缓存着，抬起照样送到这里，但卡片已经不在了——不开菜单。
    if (!mounted) return;
    if (_withinSlop(down, event.position)) widget.onSecondaryClick(down);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _down?.pointer) _down = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: widget.child,
      );
}
