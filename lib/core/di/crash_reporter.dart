// CrashReporter provider —— app-scoped。
//
// 与 appPathsProvider 同属"bootstrap 期解析"的构件：FileCrashReporter 依赖启动时
// 才 await 到的 app 版本（package_info），无法在纯同步 provider 里装配。故此 provider
// 默认抛出，强迫 main() 在 runApp 前显式构造并 overrideWithValue（与 logger/paths 同款）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/crash_reporter.dart';

final crashReporterProvider = Provider<CrashReporter>(
  (ref) {
    throw StateError(
      'crashReporterProvider was not overridden. '
      'Wire it in main.dart before runApp().',
    );
  },
  name: 'crashReporterProvider',
);
