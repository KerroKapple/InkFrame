// 窗口状态记忆的真实插件适配器（PL-6）——把 window_manager / screen_retriever
// 收在 WindowController / DisplayQuery 缝之后，使编排层（DefaultWindowStateService）
// 及其 clamp 数学可脱离插件做 headless 单测。本文件是纯透传，不含逻辑，故无单测。
import 'dart:ui' show Offset, Rect, Size;

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/interfaces/window_state.dart';
import '../core/models/window_bounds.dart';

/// WindowController 真实实现：包裹全局 windowManager。
class WindowManagerWindowController implements WindowController {
  const WindowManagerWindowController();

  @override
  Future<WindowBounds> getBounds() async {
    final Rect r = await windowManager.getBounds();
    return WindowBounds(
      x: r.left,
      y: r.top,
      width: r.width,
      height: r.height,
    );
  }

  @override
  Future<void> setBounds(WindowBounds bounds) => windowManager.setBounds(
        Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height),
      );

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();
}

/// DisplayQuery 真实实现：包裹全局 screenRetriever。
class ScreenRetrieverDisplayQuery implements DisplayQuery {
  const ScreenRetrieverDisplayQuery();

  @override
  Future<List<WindowBounds>> visibleFrames() async {
    final List<Display> displays = await screenRetriever.getAllDisplays();
    return <WindowBounds>[for (final Display d in displays) _frameOf(d)];
  }

  // 可见工作区：优先 visiblePosition/visibleSize（已扣任务栏），缺失退整屏 size。
  WindowBounds _frameOf(Display d) {
    final Offset pos = d.visiblePosition ?? Offset.zero;
    final Size size = d.visibleSize ?? d.size;
    return WindowBounds(
      x: pos.dx,
      y: pos.dy,
      width: size.width,
      height: size.height,
    );
  }
}
