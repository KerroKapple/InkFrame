// 画布轻提示胶囊（GapsCanvas 稿 ›「画布轻提示胶囊」）：舞台底部居中的一枚小胶囊，说「我刚做了什么」。
//
// 只在本画布（按 canvasId 分族）、一次一条、自己消失；不进铃铛（不走 ToastService）、不出声、不进 Esc 链和 Tab 序。
// 不用于错误（那是通知卡）和删除撤销（8 秒撤销卡）。
//
// 规则：
//   - 最多一条：新的立刻顶掉旧的（宿主交叉淡入 120ms）。
//   - 同 dedupeKey（如缩放）且旧的还在：原地改字、计时从头算，不换卡——宿主按 [CanvasCapsuleController.serial]
//     认卡，serial 不变就不重放淡入。连按三次 Ctrl + ⇒ 最后一次之后 1.2 s 才收。
//   - 停留按类型：纯文字 2 s、带动作 4 s、缩放 1.2 s；鼠标悬停停表，移出后按剩余时间续跑。不跟通知的停留设置。
//
// 计时与通知卡（notifications/providers/toast_center.dart）同一种做法：一个周期 Timer 按 [_kTick] 扣剩余时间，
// 只在「有胶囊、没悬停」时跑，否则停掉；ref.onDispose 里取消。不用墙钟量经过时间——测试的假时钟
// （fakeAsync）只接管 Timer，量不到墙钟。每次 show / 移出都重起计时器，相位对齐到那一刻，停留时长是准的；
// 悬停那一下最多少算不到一拍（100ms），胶囊至多多留这么一会儿。
//
// 缩放比例的文案（「缩放 80%」）在宿主里按 [CanvasCapsuleMessage.zoomPercent] 渲染：出胶囊的调用方
// （fitAllNodes / zoomCanvasBy）手里只有 ref、没有 l10n。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/canvas_zoom.dart';
import 'canvas_transform_controller.dart';

/// 胶囊的类型，决定停留时长。
enum CanvasCapsuleKind {
  /// 纯文字：停 [kCanvasCapsuleTextDwell]。
  text,

  /// 带动作按钮（如「重做」）：停 [kCanvasCapsuleActionDwell]。
  action,

  /// 缩放比例：停 [kCanvasCapsuleZoomDwell]（从最后一次变化算起）。
  zoom,
}

const Duration kCanvasCapsuleTextDwell = Duration(seconds: 2);
const Duration kCanvasCapsuleActionDwell = Duration(seconds: 4);
const Duration kCanvasCapsuleZoomDwell = Duration(milliseconds: 1200);

/// 缩放胶囊的 dedupeKey：连续缩放原地改字，不一张张换。
const String kCanvasCapsuleZoomKey = 'zoom';

/// 计时器一拍。三档停留都是它的整数倍。
const Duration _kTick = Duration(milliseconds: 100);

Duration _dwellOf(CanvasCapsuleKind kind) => switch (kind) {
      CanvasCapsuleKind.text => kCanvasCapsuleTextDwell,
      CanvasCapsuleKind.action => kCanvasCapsuleActionDwell,
      CanvasCapsuleKind.zoom => kCanvasCapsuleZoomDwell,
    };

/// 一条胶囊消息（不可变）。文案由调用方用 l10n 拼好传进来；缩放比例例外，见 [CanvasCapsuleMessage.zoom]。
@immutable
class CanvasCapsuleMessage {
  const CanvasCapsuleMessage({
    required this.text,
    this.kind = CanvasCapsuleKind.text,
    this.dedupeKey,
    this.actionLabel,
    this.actionHint,
    this.onAction,
  }) : zoomPercent = null;

  /// 缩放比例胶囊：文案由宿主按 [zoomPercent] 渲染（「缩放 N%」），[text] 留空。
  const CanvasCapsuleMessage.zoom(int this.zoomPercent)
      : text = '',
        kind = CanvasCapsuleKind.zoom,
        dedupeKey = kCanvasCapsuleZoomKey,
        actionLabel = null,
        actionHint = null,
        onAction = null;

  final String text;
  final CanvasCapsuleKind kind;

  /// 非空且与在场那条相同 ⇒ 原地改字、重新计时，不换卡。
  final String? dedupeKey;

  /// 动作按钮的字（如「重做」）。给了就该是 [CanvasCapsuleKind.action]（debug 断言）。
  final String? actionLabel;

  /// 动作旁的键位提示（如 mac「⌘⇧Z」/ Windows「Ctrl Y」），由调用方按平台给。
  final String? actionHint;

  /// 点动作的回调；宿主调完它就收起胶囊。动作按钮只给鼠标（不进 Tab 序），键盘走该动作的快捷键。
  final VoidCallback? onAction;

  /// 非空 ⇒ 缩放比例胶囊，宿主用 l10n.canvasCapsuleZoom(zoomPercent) 渲染，忽略 [text]。
  final int? zoomPercent;
}

final canvasCapsuleProvider = AutoDisposeNotifierProviderFamily<
    CanvasCapsuleController, CanvasCapsuleMessage?, String>(
  CanvasCapsuleController.new,
  name: 'canvasCapsuleProvider',
);

/// 一张画布的胶囊：state = 在场的那条，null = 没有。
class CanvasCapsuleController
    extends AutoDisposeFamilyNotifier<CanvasCapsuleMessage?, String> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _hovered = false;
  int _serial = 0;

  /// 在场那张卡的编号：换一张卡（新消息、不同 dedupeKey、收掉后再来）就变，同 dedupeKey 原地改字不变。
  /// 宿主拿它当卡的 key——变了才交叉淡入。
  int get serial => _serial;

  @override
  CanvasCapsuleMessage? build(String canvasId) {
    ref.onDispose(_stopTicker);
    return null;
  }

  /// 出一条胶囊：顶掉在场的；与在场那条同 dedupeKey ⇒ 原地改字、计时从头算。
  void show(CanvasCapsuleMessage message) {
    assert(
      message.actionLabel == null || message.kind == CanvasCapsuleKind.action,
      '带动作的胶囊停 4 s：kind 要传 CanvasCapsuleKind.action',
    );
    final CanvasCapsuleMessage? current = state;
    final String? key = message.dedupeKey;
    if (current != null && key != null && key == current.dedupeKey) {
      // 原地：不换卡（serial 不变），只换字；计时从这一次算起。
      state = message;
      _remaining = _dwellOf(message.kind);
      _restartTicker();
      return;
    }
    _serial++;
    state = message;
    _remaining = _dwellOf(message.kind);
    _restartTicker();
  }

  /// 缩放比例胶囊：[scale] 取整成百分比。
  void showZoom(double scale) =>
      show(CanvasCapsuleMessage.zoom((scale * 100).round()));

  /// 立即收起。
  void dismiss() {
    _stopTicker();
    _remaining = Duration.zero;
    if (state != null) state = null;
  }

  /// 鼠标在胶囊上：true 停表（剩余时间留着），false 按剩余时间续跑（不是从头算）。
  void setHovered(bool hovered) {
    if (hovered == _hovered) return;
    _hovered = hovered;
    _restartTicker();
  }

  /// 有胶囊且没悬停 ⇒ 从此刻重起计时器；否则停掉。
  void _restartTicker() {
    _stopTicker();
    if (state == null || _hovered) return;
    _ticker = Timer.periodic(_kTick, (_) => _tick());
  }

  void _tick() {
    _remaining -= _kTick;
    if (_remaining <= Duration.zero) dismiss();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

/// 键盘缩放（Ctrl/⌘ + / − / 0）与「适应全部 / 适应选中」改完相机后调：按相机此刻的比例出「缩放 N%」。
/// 滚轮 / 捏合 / 缩放条 +、− 不调（缩放条上一直显示着比例）。
void showZoomCapsule(WidgetRef ref, {required String canvasId}) {
  final double scale =
      scaleOf(ref.read(canvasTransformControllerProvider(canvasId)).value);
  ref.read(canvasCapsuleProvider(canvasId).notifier).showZoom(scale);
}
