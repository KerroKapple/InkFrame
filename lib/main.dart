// InkFrame 应用入口：
//   1) 绑定 Flutter binding + MediaKit + window_manager
//   2) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录）
//   3) bootstrap 期预加载：偏好 + 自定义 Provider 配置（custom_providers.json，
//      启动期一次性注册——registry 构建前必须就绪且会话内不变，PROVIDER-API §13.5）
//   4) 显式构造 ProviderContainer + AppTeardown，并【在显示窗口之前】注册退出路径
//      （窗口关闭监听 + macOS lifecycle channel）——窗口一旦可见即可被 Cmd+Q，
//      handler 必须先就位，否则 AppDelegate 立即 reply 终止、teardown 从未执行 → PG 孤儿
//   5) setPreventClose + 显示窗口
//   6) runApp(UncontrolledProviderScope + InkFrameApp)
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/custom_providers.dart';
import 'core/di/logger.dart';
import 'core/di/paths.dart';
import 'core/di/preferences.dart';
import 'core/di/providers.dart';
import 'core/logging/logger_service.dart';
import 'core/paths/app_paths.dart';
import 'services/app_teardown.dart';
import 'services/custom_providers_file_service.dart';
import 'services/file_preferences_service.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await windowManager.ensureInitialized();

  // 先把 DI 容器与退出路径准备好，再显示窗口（见文件头说明：防早退竞态）。
  final AppPaths paths = await DefaultAppPaths.create();
  await paths.ensureInitialized();

  // 启动即加载持久化偏好（主题/语言/对比度/缩放），供控制器 build 期 seed。
  final FilePreferencesService prefsService = FilePreferencesService(paths);
  await prefsService.load();

  // Logger 在容器前构造（bootstrap 期加载即可写 WARN），随后 overrideWithValue
  // 保持全 app 单实例；参数与 di/logger.dart 默认装配一致（SystemClock + 默认配置）。
  final FileLoggerService logger =
      FileLoggerService(paths: paths, clock: const SystemClock());

  // 自定义 Provider 配置：容器构建前完成加载（providerRegistryProvider /
  // providerCapabilitiesListProvider 构建时同步读取；会话内不变，改 json 重启生效）。
  final CustomProvidersFileService customProviders = CustomProvidersFileService(
    paths: paths,
    logger: logger,
    reservedProviderIds: <String>{
      for (final c in kAllProviderCapabilities) c.providerId,
    },
  );
  await customProviders.load();

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appPathsProvider.overrideWithValue(paths),
      preferencesServiceProvider.overrideWithValue(prefsService),
      loggerProvider.overrideWithValue(logger),
      customProviderSourceProvider.overrideWithValue(customProviders),
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
