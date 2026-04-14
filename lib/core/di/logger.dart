// LoggerService provider：app-scoped，ref.onDispose 调用 close 释放文件句柄。
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
