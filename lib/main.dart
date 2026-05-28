// InkFrame 应用入口：
//   1) 绑定 Flutter widgets binding
//   2) 初始化 window_manager 并隐藏系统标题栏（自定义 InkWindowChrome 接管）
//   3) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录）
//   4) 构造 ProviderContainer override，注入 appPathsProvider
//   5) runApp(InkFrameApp)
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/paths.dart';
import 'core/paths/app_paths.dart';
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
  await windowManager.waitUntilReadyToShow(winOpts, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final AppPaths paths = await DefaultAppPaths.create();
  await paths.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
      ],
      child: const InkFrameApp(),
    ),
  );
}
