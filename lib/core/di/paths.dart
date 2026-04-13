// AppPaths provider：app-scoped，启动时完成目录初始化。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../paths/app_paths.dart';

/// App 生命周期内唯一的 AppPaths 实例。启动引导前必须 overrideWith 实现
/// （main.dart 在 runApp 前预创建并注入）——此 provider 默认抛出，强迫配置。
final appPathsProvider = Provider<AppPaths>(
  (ref) {
    throw StateError(
      'appPathsProvider was not overridden. '
      'Wire it in main.dart before runApp().',
    );
  },
  name: 'appPathsProvider',
);
