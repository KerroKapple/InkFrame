// InkFrame 应用入口：
//   1) 绑定 Flutter widgets binding
//   2) 解析 AppPaths 并 ensureInitialized（首次启动创建 ~/InkFrame 目录）
//   3) 构造 ProviderContainer override，注入 appPathsProvider
//   4) runApp(InkFrameApp)
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/di/paths.dart';
import 'core/paths/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

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
