// 窗口状态记忆 DI（PL-6）——app-scoped。
//
// windowController / displayQuery 为真实插件适配器（可在测试中 override 成假实现）；
// windowStateService 编排二者 + 偏好 + 日志。main.dart 启动恢复、AppTeardown 退出捕获
// 均通过 windowStateServiceProvider 取实例。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/window_manager_adapters.dart';
import '../../services/window_state_service.dart';
import '../interfaces/window_state.dart';
import 'logger.dart';
import 'preferences.dart';

final windowControllerProvider = Provider<WindowController>(
  (ref) => const WindowManagerWindowController(),
  name: 'windowControllerProvider',
);

final displayQueryProvider = Provider<DisplayQuery>(
  (ref) => const ScreenRetrieverDisplayQuery(),
  name: 'displayQueryProvider',
);

final windowStateServiceProvider = Provider<WindowStateService>(
  (ref) => DefaultWindowStateService(
    prefs: ref.watch(preferencesServiceProvider),
    controller: ref.watch(windowControllerProvider),
    displays: ref.watch(displayQueryProvider),
    logger: ref.watch(loggerProvider),
  ),
  name: 'windowStateServiceProvider',
);
