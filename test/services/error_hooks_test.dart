// error_hooks 单测：钩子转发到 CrashReporter + 最后一道防线吞掉自身抛错。
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/crash_reporter.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/error_hooks.dart';

import '../helpers/recording_logger.dart';

// 模拟"崩溃写盘时磁盘满"——用于验证最后一道防线会吞掉它。
class _FakeDiskFull implements Exception {
  const _FakeDiskFull();
}

class _RecordingCrashReporter implements CrashReporter {
  final List<(Object, StackTrace?)> calls = <(Object, StackTrace?)>[];
  bool throwOnReport = false;

  @override
  void report(Object error, StackTrace? stackTrace) {
    calls.add((error, stackTrace));
    if (throwOnReport) {
      throw const _FakeDiskFull();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 保存/恢复全局钩子，避免污染其它测试。
  late FlutterExceptionHandler? savedFlutterOnError;
  late ErrorCallback? savedPlatformOnError;

  setUp(() {
    savedFlutterOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
  });

  test('installErrorHooks forwards FlutterError.onError to reporter', () {
    final logger = RecordingLogger();
    final reporter = _RecordingCrashReporter();
    installErrorHooks(logger: logger, reporter: reporter);

    final err = StateError('framework boom');
    FlutterError.onError!(FlutterErrorDetails(exception: err));

    expect(reporter.calls, hasLength(1));
    expect(reporter.calls.single.$1, err);
    expect(logger.byLevel(InkLogLevel.error), hasLength(1));
  });

  test('installErrorHooks wires PlatformDispatcher.onError, returns true', () {
    final logger = RecordingLogger();
    final reporter = _RecordingCrashReporter();
    installErrorHooks(logger: logger, reporter: reporter);

    final err = StateError('async platform boom');
    final handled =
        PlatformDispatcher.instance.onError!(err, StackTrace.empty);

    expect(handled, isTrue);
    expect(reporter.calls, hasLength(1));
    expect(reporter.calls.single.$1, err);
  });

  test('reportUncaught swallows a throwing reporter (last-resort exemption)',
      () {
    final logger = RecordingLogger();
    final reporter = _RecordingCrashReporter()..throwOnReport = true;

    // 崩溃处理器自身抛（磁盘满）时绝不能再冒泡——否则 app 被 crash 处理器拖垮。
    expect(
      () => reportUncaught(
        logger: logger,
        reporter: reporter,
        error: StateError('boom'),
        stack: StackTrace.empty,
      ),
      returnsNormally,
    );
    // 日志仍应记录（error 在 report 之前触达）。
    expect(logger.byLevel(InkLogLevel.error), hasLength(1));
  });
}
