// 窗口状态记忆的抽象契约（PL-6）。
//
// 三个注入缝，让 clamp/恢复逻辑可脱离真实窗口做 headless 单测：
//   - WindowStateService：对外的 restore（启动）/ capture（退出）门面。
//   - WindowController：包裹 window_manager 的取/设边界 + 最大化（真实实现走插件）。
//   - DisplayQuery：枚举当前连接显示器的「可见工作区」矩形（真实实现走 screen_retriever）。
//
// 失败语义：记忆窗口状态属尽力而为——查询显示器 / 读写偏好 / 设窗任一失败都退默认窗口，
// 绝不阻断启动或崩溃（实现内吞错，见 DefaultWindowStateService）。
import '../models/window_bounds.dart';

/// 窗口状态记忆门面：启动恢复 + 退出捕获。
abstract class WindowStateService {
  /// 读取上次保存的边界，clamp 到当前可见显示器后应用（或按 maximized 标志最大化）。
  /// 无有效记忆 / 任何失败 → 保持默认窗口。
  Future<void> restore();

  /// 一次性读取当前边界 + 最大化状态并落盘。窗口须仍存活（退出路径 destroy 之前）。
  Future<void> capture();
}

/// window_manager 的最小注入缝（真实实现 = WindowManagerWindowController）。
abstract class WindowController {
  Future<WindowBounds> getBounds();
  Future<void> setBounds(WindowBounds bounds);
  Future<bool> isMaximized();
  Future<void> maximize();
}

/// 显示器枚举注入缝（真实实现 = ScreenRetrieverDisplayQuery）。
abstract class DisplayQuery {
  /// 所有已连接显示器的可见工作区（logical px，已扣除任务栏/程序坞）。
  Future<List<WindowBounds>> visibleFrames();
}
