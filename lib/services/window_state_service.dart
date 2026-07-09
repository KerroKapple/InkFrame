// DefaultWindowStateService：窗口状态记忆的编排（PL-6）。
//
// restore：读记忆边界 → clamp 到可见显示器 → setBounds（+ 按标志 maximize）。
// capture：一次性读 getBounds + isMaximized → 落盘。
// 全流程尽力而为：任何失败（无插件 / 显示器查询异常 / IO）都吞掉退默认窗口，绝不阻断启动。
//
// clamp 数学是纯函数（clampBoundsToVisible），可用假坐标做 headless 多显示器单测。
import 'dart:math' as math;

import '../core/interfaces/preferences_service.dart';
import '../core/interfaces/window_state.dart';
import '../core/logging/logger_service.dart';
import '../core/models/window_bounds.dart';

const String _kModule = 'window.state';

/// 默认窗口边界——尺寸与 main.dart 的 WindowOptions.size 一致；记忆失效时的兜底。
const WindowBounds kDefaultWindowBounds =
    WindowBounds(x: 0, y: 0, width: 1536, height: 984);

/// 把 [saved] clamp 进当前可见显示器。纯函数——无副作用、无插件依赖，供单测直接验证。
///
/// 规则：
///   - [frames] 为空 → null（无可见显示器，交调用方退默认）。
///   - [saved] 与任何显示器都不相交（off-screen / 显示器已拔）→ null（退默认）。
///   - 否则取「相交面积最大」的显示器为落点：宽/高不超过其工作区，位置夹在工作区内。
///     [saved] 本就完整落在该显示器内 → 原样返回（不动尺寸/位置）。
WindowBounds? clampBoundsToVisible(
  WindowBounds saved,
  List<WindowBounds> frames,
) {
  if (frames.isEmpty) return null;
  WindowBounds? best;
  double bestArea = 0;
  for (final f in frames) {
    final area = _intersectionArea(saved, f);
    if (area > bestArea) {
      bestArea = area;
      best = f;
    }
  }
  if (best == null || bestArea <= 0) return null;
  return _clampInto(saved, best);
}

double _intersectionArea(WindowBounds a, WindowBounds b) {
  final w = math.min(a.right, b.right) - math.max(a.left, b.left);
  final h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  if (w <= 0 || h <= 0) return 0;
  return w * h;
}

WindowBounds _clampInto(WindowBounds r, WindowBounds frame) {
  final w = math.min(r.width, frame.width);
  final h = math.min(r.height, frame.height);
  final x = r.x.clamp(frame.left, frame.right - w).toDouble();
  final y = r.y.clamp(frame.top, frame.bottom - h).toDouble();
  return WindowBounds(x: x, y: y, width: w, height: h);
}

class DefaultWindowStateService implements WindowStateService {
  DefaultWindowStateService({
    required PreferencesService prefs,
    required WindowController controller,
    required DisplayQuery displays,
    required LoggerService logger,
    WindowBounds defaultBounds = kDefaultWindowBounds,
  })  : _prefs = prefs,
        _controller = controller,
        _displays = displays,
        _logger = logger,
        _defaultBounds = defaultBounds;

  final PreferencesService _prefs;
  final WindowController _controller;
  final DisplayQuery _displays;
  final LoggerService _logger;
  final WindowBounds _defaultBounds;

  @override
  Future<void> restore() async {
    final saved = _prefs.current.windowBounds;
    final maximized = _prefs.current.windowMaximized;
    // 首次启动（无任何记忆）→ 保持 WindowOptions 默认窗口，不碰边界。
    if (saved == null && !maximized) return;
    try {
      if (saved != null) {
        final frames = await _displays.visibleFrames();
        // 记忆边界不可见 → 退默认；默认再 clamp 一次确保落在可见工作区内。
        final target = clampBoundsToVisible(saved, frames) ??
            clampBoundsToVisible(_defaultBounds, frames) ??
            _defaultBounds;
        await _controller.setBounds(target);
      }
      if (maximized) await _controller.maximize();
    } on Object catch (e) {
      // 尽力而为：查询显示器 / 设窗任何失败都退默认窗口，绝不阻断启动。
      _logger.warn(_kModule, 'window restore failed',
          extra: <String, Object?>{'error': e.toString()});
    }
  }

  @override
  Future<void> capture() async {
    try {
      final bounds = await _controller.getBounds();
      final maximized = await _controller.isMaximized();
      await _prefs.update((p) => p.copyWith(
            windowBounds: bounds,
            windowMaximized: maximized,
          ));
    } on Object catch (e) {
      // 尽力而为：读边界 / 落盘失败不影响退出回收。
      _logger.warn(_kModule, 'window capture failed',
          extra: <String, Object?>{'error': e.toString()});
    }
  }
}
