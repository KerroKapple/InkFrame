// InkFrame 应用入口：
//   1) 绑定 Flutter widgets binding
//   2) 初始化 window_manager，隐藏系统标题栏（自定义 InkWindowChrome 接管），
//      并 setPreventClose：关闭事件改走 onWindowClose → AppTeardown → destroy
//   3) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录）
//   4) 显式构造 ProviderContainer（退出时需要有序回收，不能交给隐式容器）
//   5) runApp(UncontrolledProviderScope + InkFrameApp)
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/paths.dart';
import 'core/paths/app_paths.dart';
import 'services/app_teardown.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await windowManager.ensureInitialized();
  const WindowOptions winOpts = WindowOptions(
    size: Size(1536, 984),
    minimumSize: Size(960, 600),
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: InkPalette.surfaceCanvasDark,
  );
  // 拦截系统/标题栏关闭：必须先完成 teardown 再 destroy，否则 PG 孤儿化。
  await windowManager.setPreventClose(true);
  await windowManager.waitUntilReadyToShow(winOpts, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final AppPaths paths = await DefaultAppPaths.create();
  await paths.ensureInitialized();

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appPathsProvider.overrideWithValue(paths),
    ],
  );
  final AppTeardown teardown = AppTeardown();
  windowManager.addListener(_TeardownWindowListener(container, teardown));

  // macOS Cmd+Q / 菜单 Quit 走 NSApp.terminate，绕过 window_manager 的
  // windowShouldClose（setPreventClose 在此路径不生效）。AppDelegate 经此 channel
  // 在 native terminate 前请求 Dart 完成 teardown，避免嵌入式 PG 孤儿化。
  // 与窗口关闭路径共享同一个 AppTeardown 实例，回收至多执行一次。
  const MethodChannel('inkframe/lifecycle')
      .setMethodCallHandler((MethodCall call) async {
    if (call.method == 'requestTerminate') {
      await teardown.run(container);
    }
    return null;
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const InkFrameApp(),
    ),
  );
}

/// 关闭事件监听：JobQueue → Connection → PG 有序回收后 destroy 真正退出。
/// 回收逻辑全部在 AppTeardown（有单测）；本类只做事件桥接与重入保护。
class _TeardownWindowListener with WindowListener {
  _TeardownWindowListener(this._container, this._teardown);

  final ProviderContainer _container;
  final AppTeardown _teardown;
  bool _closing = false;

  @override
  Future<void> onWindowClose() async {
    if (_closing) return; // teardown 进行中再次点关闭 → 忽略
    _closing = true;
    await _teardown.run(_container);
    await windowManager.destroy();
  }
}
