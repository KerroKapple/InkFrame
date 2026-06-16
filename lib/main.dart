// InkFrame 应用入口：
//   1) 绑定 Flutter binding + MediaKit + window_manager
//   2) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录）
//   3) 显式构造 ProviderContainer + AppTeardown，并【在显示窗口之前】注册退出路径
//      （窗口关闭监听 + macOS lifecycle channel）——窗口一旦可见即可被 Cmd+Q，
//      handler 必须先就位，否则 AppDelegate 立即 reply 终止、teardown 从未执行 → PG 孤儿
//   4) setPreventClose + 显示窗口
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

  // 先把 DI 容器与退出路径准备好，再显示窗口（见文件头说明：防早退竞态）。
  final AppPaths paths = await DefaultAppPaths.create();
  await paths.ensureInitialized();

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appPathsProvider.overrideWithValue(paths),
    ],
  );
  final AppTeardown teardown = AppTeardown();
  windowManager.addListener(_TeardownWindowListener(container, teardown));

  // macOS Cmd+Q / 菜单 Quit / Dock Quit 走 NSApp.terminate，绕过 window_manager 的
  // windowShouldClose（setPreventClose 在此路径不生效）。AppDelegate 经此 channel
  // 在 native terminate 前请求 Dart 完成 teardown，避免嵌入式 PG 孤儿化。
  // 必须在窗口可见前注册；与窗口关闭路径共享同一个 AppTeardown 实例，回收至多一次。
  const MethodChannel('inkframe/lifecycle')
      .setMethodCallHandler((MethodCall call) async {
    if (call.method == 'requestTerminate') {
      await teardown.run(container);
    }
    return null;
  });

  // 拦截系统/标题栏关闭：必须先完成 teardown 再 destroy，否则 PG 孤儿化。
  const WindowOptions winOpts = WindowOptions(
    size: Size(1536, 984),
    minimumSize: Size(960, 600),
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: InkPalette.surfaceCanvasDark,
  );
  await windowManager.setPreventClose(true);
  await windowManager.waitUntilReadyToShow(winOpts, () async {
    await windowManager.show();
    await windowManager.focus();
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
