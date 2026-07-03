// LoggerService provider：app-scoped，ref.onDispose 调用 close 释放文件句柄。
//
// 注意：生产路径 main.dart 以同参实例 overrideWithValue（bootstrap 期需先于容器
// 写日志）；改动此处默认装配（config/clock）时同步 main.dart。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/logger_service.dart';
import 'clock.dart';
import 'paths.dart';

final loggerConfigProvider = Provider<LoggerConfig>(
  (ref) => const LoggerConfig(),
  name: 'loggerConfigProvider',
);

final loggerProvider = Provider<LoggerService>(
  (ref) {
    final logger = FileLoggerService(
      paths: ref.watch(appPathsProvider),
      clock: ref.watch(clockProvider),
      config: ref.watch(loggerConfigProvider),
    );
    ref.onDispose(() async {
      await logger.close();
    });
    return logger;
  },
  name: 'loggerProvider',
);
