// 全局错误钩子安装：让任何未捕获错误都不丢失。
//
// 三条捕获路径（main.dart 里 runZonedGuarded 包裹 runApp 提供第 3 条）：
//   1) FlutterError.onError         —— Flutter 框架同步错误
//   2) PlatformDispatcher.onError   —— 平台侧异步错误（返回 true 表示已消费）
//   3) runZonedGuarded.onError      —— zone 内未捕获错误（复用 reportUncaught）
// 三者统一汇入 [reportUncaught]：logger.error + CrashReporter.report + flush。
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/interfaces/crash_reporter.dart';
import '../core/logging/logger_service.dart';

const String _kModule = 'app.uncaught';

/// 安装框架错误 + 平台异步错误钩子。zone 钩子由 main() 在包裹 runApp 时接入。
void installErrorHooks({
  required LoggerService logger,
  required CrashReporter reporter,
}) {
  FlutterError.onError = (FlutterErrorDetails details) {
    reportUncaught(
      logger: logger,
      reporter: reporter,
      error: details.exception,
      stack: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reportUncaught(
      logger: logger,
      reporter: reporter,
      error: error,
      stack: stack,
    );
    // 已消费：返回 true，阻止默认（进程级）上报。
    return true;
  };
}

/// 未捕获错误的统一落点：日志 ERROR + 崩溃文件 + flush。
void reportUncaught({
  required LoggerService logger,
  required CrashReporter reporter,
  required Object error,
  StackTrace? stack,
}) {
  // ┌── 经批准的系统级豁免（唯一） ──────────────────────────────────────────┐
  // │ 这是全仓"只 catch 具体 InkError"铁律的唯一例外：最后一道防线处理器。      │
  // │ 崩溃处理器自身若抛（磁盘满、句柄耗尽、路径不可写），绝不能再把 app 拖垮——  │
  // │ 丢掉一次崩溃记录，远好于让 crash 处理器自己 crash。故此处刻意宽 catch 并吞。│
  // └──────────────────────────────────────────────────────────────────────┘
  try {
    logger.error(_kModule, 'uncaught error', cause: error, stackTrace: stack);
    reporter.report(error, stack);
    // flush 的异步错误也吞掉：否则会逃逸到本 zone 的 onError → 重入死循环
    // （N-2）。当前 flush 为同步 no-op，此 catchError 是对未来 async 实现的护栏。
    unawaited(logger.flush().catchError((Object _) {}));
  } catch (_) {
    // 见上：sanctioned last-resort exemption——刻意吞掉一切（含崩溃写盘失败）。
  }
}
