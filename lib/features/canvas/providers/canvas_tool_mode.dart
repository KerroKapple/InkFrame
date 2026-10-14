// 画布工具态：选择 / 平移（浮动工具条的两个模式键 + V / H），外加「按住空格临时平移」。
// 纯 UI 态，不落库。
//
// 两个来源分开记：工具态是用户点出来 / 按 H 切出来的，会一直保持；空格是按住才算，
// 松开即回。实际是否在平移 = 二者取或（[canvasPanActiveProvider]）——分开记，松开空格
// 才回得到「按下之前的那个工具」，而不是一律打回选择。
//
// 平移生效时舞台上的节点卡片 / 泳道标题栏 / 连线命中层都不收指针，拖哪儿都是拖画布
// （见 canvas_view.dart 的 _PanGate）。
//
// autoDispose + 按画布分族：画布关掉（没人 watch 了）即回收，下次打开从「选择」开始。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 画布当前工具。
enum CanvasToolMode { select, pan }

/// 当前工具（工具条模式键 / V / H / Esc 写，工具条与舞台读）。
final canvasToolModeProvider = AutoDisposeNotifierProviderFamily<
    CanvasToolModeController, CanvasToolMode, String>(
  CanvasToolModeController.new,
  name: 'canvasToolModeProvider',
);

class CanvasToolModeController
    extends AutoDisposeFamilyNotifier<CanvasToolMode, String> {
  @override
  CanvasToolMode build(String canvasId) => CanvasToolMode.select;

  /// 回到选择工具。
  void select() {
    if (state == CanvasToolMode.select) return;
    state = CanvasToolMode.select;
  }

  /// 切到平移工具。
  void pan() {
    if (state == CanvasToolMode.pan) return;
    state = CanvasToolMode.pan;
  }

  /// 平移开 / 关（H）：在平移就回选择，否则切到平移。
  void togglePan() => state =
      state == CanvasToolMode.pan ? CanvasToolMode.select : CanvasToolMode.pan;
}

/// 空格是否按住（CanvasShortcuts 按下置 true、松开 / 画布失焦置 false）。
final canvasSpacePanProvider =
    AutoDisposeNotifierProviderFamily<CanvasSpacePanController, bool, String>(
  CanvasSpacePanController.new,
  name: 'canvasSpacePanProvider',
);

class CanvasSpacePanController extends AutoDisposeFamilyNotifier<bool, String> {
  @override
  bool build(String canvasId) => false;

  /// 按下（含按住时的自动重复）：已在按住就不再通知，免得每个重复事件都重建一遍。
  void hold() {
    if (state) return;
    state = true;
  }

  /// 松开。
  void release() {
    if (!state) return;
    state = false;
  }
}

/// 实际是否在平移：工具 = 平移，或空格按住。舞台的指针闸、手形光标、工具条的
/// 「平移」高亮都读这一份——三处同一个判据，不会一处在平移、一处以为没在。
final canvasPanActiveProvider = Provider.autoDispose.family<bool, String>(
  (ref, canvasId) =>
      ref.watch(canvasToolModeProvider(canvasId)) == CanvasToolMode.pan ||
      ref.watch(canvasSpacePanProvider(canvasId)),
  name: 'canvasPanActiveProvider',
);
