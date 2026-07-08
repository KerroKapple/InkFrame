// InkFrame 应用入口：
//   0) 【最外层】runZonedGuarded 包裹整个 bootstrap + runApp——捕获 zone 内一切未捕获
//      错误（LB-17）。WidgetsFlutterBinding.ensureInitialized 必须与 runApp 处于【同一
//      zone】，否则触发 Flutter 的 zone-mismatch 断言——故绑定初始化也放进 zone body。
//      配合 FlutterError.onError / PlatformDispatcher.onError（installErrorHooks）与
//      CrashReporter 落盘，三条路径统一汇入 reportUncaught，任何未处理错误都不丢失。
//   1) 绑定 Flutter binding
//   2) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录，含 crashes/）
//   3) 尽早装配 Logger + CrashReporter 并安装全局错误钩子——覆盖其后整段 bootstrap
//   4) MediaKit + 许可补册 + window_manager
//   5) bootstrap 期预加载：偏好 + 自定义 Provider 配置（custom_providers.json，
//      启动期一次性注册——registry 构建前必须就绪且会话内不变，PROVIDER-API §13.5）
//   6) 显式构造 ProviderContainer + AppTeardown，并【在显示窗口之前】注册退出路径
//      （窗口关闭监听 + macOS lifecycle channel）——窗口一旦可见即可被 Cmd+Q，
//      handler 必须先就位，否则 AppDelegate 立即 reply 终止、teardown 从未执行 → PG 孤儿
//   7) setPreventClose + 显示窗口
//   8) runApp(UncontrolledProviderScope + InkFrameApp)
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/crash_reporter.dart';
import 'core/di/custom_providers.dart';
import 'core/di/logger.dart';
import 'core/di/paths.dart';
import 'core/di/preferences.dart';
import 'core/di/providers.dart';
import 'core/interfaces/crash_reporter.dart';
import 'core/licenses.dart';
import 'core/logging/logger_service.dart';
import 'core/paths/app_paths.dart';
import 'services/app_teardown.dart';
import 'services/crash_reporter.dart';
import 'services/custom_providers_file_service.dart';
import 'services/error_hooks.dart';
import 'services/file_preferences_service.dart';
import 'theme/tokens.dart';

void main() {
  // logger / reporter 提升到 zone 外的函数作用域（非全局），供 onError 回退复用；
  // 二者在 bootstrap 早期赋值前为 null（极早期错误走 runZonedGuarded 默认 stderr 上报）。
  LoggerService? logger;
  CrashReporter? reporter;

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 崩溃钩子所需最小依赖尽早就绪，最大化未捕获错误覆盖面（覆盖其后整段 bootstrap）。
      final AppPaths paths = await DefaultAppPaths.create();
      await paths.ensureInitialized();

      // Logger 在容器前构造（bootstrap 期加载即可写 WARN），随后 overrideWithValue
      // 保持全 app 单实例；参数与 di/logger.dart 默认装配一致（SystemClock + 默认配置）。
      final FileLoggerService fileLogger =
          FileLoggerService(paths: paths, clock: const SystemClock());
      logger = fileLogger;

      // app 版本从平台读一次，注入 CrashReporter（崩溃文件含版本，便于事后归因）。
      final PackageInfo pkg = await PackageInfo.fromPlatform();
      final String appVersion =
          pkg.version.isEmpty ? 'unknown' : '${pkg.version}+${pkg.buildNumber}';
      final FileCrashReporter crashReporter = FileCrashReporter(
        paths: paths,
        clock: const SystemClock(),
        appVersion: appVersion,
      );
      reporter = crashReporter;

      // 立即安装框架错误 + 平台异步错误钩子（zone 错误由本函数 onError 接入）。
      installErrorHooks(logger: fileLogger, reporter: crashReporter);

      MediaKit.ensureInitialized();

      // 第三方许可补册：随发布分发的 libmpv/FFmpeg(LGPL-2.1)、内嵌 PostgreSQL、
      // 打包字体(OFL-1.1)不在 pub 自动聚合内，入册后经关于页 showLicensePage 呈现。
      registerThirdPartyLicenses();

      await windowManager.ensureInitialized();

      // 启动即加载持久化偏好（主题/语言/对比度/缩放），供控制器 build 期 seed。
      final FilePreferencesService prefsService = FilePreferencesService(paths);
      await prefsService.load();

      // 自定义 Provider 配置：容器构建前完成加载（providerRegistryProvider /
      // providerCapabilitiesListProvider 构建时同步读取；会话内不变，改 json 重启生效）。
      final CustomProvidersFileService customProviders =
          CustomProvidersFileService(
        paths: paths,
        logger: fileLogger,
        reservedProviderIds: <String>{
          for (final c in kAllProviderCapabilities) c.providerId,
        },
      );
      await customProviders.load();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          preferencesServiceProvider.overrideWithValue(prefsService),
          loggerProvider.overrideWithValue(fileLogger),
          crashReporterProvider.overrideWithValue(crashReporter),
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
    },
    (Object error, StackTrace stack) {
      // zone 未捕获错误：钩子就绪后走完整落盘；就绪前（极早期）默认已上报 stderr。
      final LoggerService? l = logger;
      final CrashReporter? r = reporter;
      if (l != null && r != null) {
        reportUncaught(logger: l, reporter: r, error: error, stack: stack);
      }
    },
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
