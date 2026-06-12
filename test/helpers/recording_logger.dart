// 测试用 LoggerService：把所有日志调用录到内存，供断言注入点是否被触达。
import 'package:inkframe/core/logging/logger_service.dart';

class LogRecord {
  LogRecord({
    required this.level,
    required this.module,
    required this.msg,
    this.extra,
    this.cause,
    this.stackTrace,
  });

  final InkLogLevel level;
  final String module;
  final String msg;
  final Map<String, Object?>? extra;
  final Object? cause;
  final StackTrace? stackTrace;
}

class RecordingLogger implements LoggerService {
  final List<LogRecord> records = <LogRecord>[];

  List<LogRecord> byLevel(InkLogLevel level) =>
      records.where((r) => r.level == level).toList();

  List<LogRecord> byModule(String module) =>
      records.where((r) => r.module == module).toList();

  @override
  void debug(String module, String msg, {Map<String, Object?>? extra}) =>
      records.add(LogRecord(
        level: InkLogLevel.debug,
        module: module,
        msg: msg,
        extra: extra,
      ));

  @override
  void info(String module, String msg, {Map<String, Object?>? extra}) =>
      records.add(LogRecord(
        level: InkLogLevel.info,
        module: module,
        msg: msg,
        extra: extra,
      ));

  @override
  void warn(String module, String msg, {Map<String, Object?>? extra}) =>
      records.add(LogRecord(
        level: InkLogLevel.warn,
        module: module,
        msg: msg,
        extra: extra,
      ));

  @override
  void error(
    String module,
    String msg, {
    Map<String, Object?>? extra,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      records.add(LogRecord(
        level: InkLogLevel.error,
        module: module,
        msg: msg,
        extra: extra,
        cause: cause,
        stackTrace: stackTrace,
      ));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
