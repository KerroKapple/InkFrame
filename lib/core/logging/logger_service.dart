// LoggerService：单行 JSON 结构化日志 + 轮转 + 限流 + 脱敏。
//
// 对齐 PRD §20 可观测性 & §20.2 日志轮转强化：
// - 字段固定 ts / level / module / msg / extra
// - 单文件 10MB 触发当天即轮转
// - 总磁盘 > 200MB 进入紧急模式，删最旧直到 < 150MB
// - DEBUG 限流 100 行/秒，超限丢弃 + 1 条 WARN 汇总
// - prompt / key / token / authorization 字段打码为 "***"
//
// 实现选择：写入走同步 File API（writeAsStringSync + append），理由：
//   1) 日志行与调用顺序严格一致（async IOSink 无法保证顺序）
//   2) 测试可确定性断言（异步 sink 会和 flush 竞争）
//   3) 日志吞吐在本应用规模下（< 1000 行/秒）远未逼近同步 write 上限
// 崩溃时保证落盘（同步 write 跨越 dart 调度）。
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../paths/app_paths.dart';

enum InkLogLevel { debug, info, warn, error }

extension _LevelWire on InkLogLevel {
  String get wire => switch (this) {
        InkLogLevel.debug => 'DEBUG',
        InkLogLevel.info => 'INFO',
        InkLogLevel.warn => 'WARN',
        InkLogLevel.error => 'ERROR',
      };
}

/// 日志配置（默认来自 PRD，测试可覆盖）。
class LoggerConfig {
  const LoggerConfig({
    this.maxFileBytes = 10 * 1024 * 1024,
    this.totalDiskBudgetBytes = 200 * 1024 * 1024,
    this.emergencyReclaimTargetBytes = 150 * 1024 * 1024,
    this.debugPerSecondLimit = 100,
    this.minLevel = InkLogLevel.info,
  });

  final int maxFileBytes;
  final int totalDiskBudgetBytes;
  final int emergencyReclaimTargetBytes;
  final int debugPerSecondLimit;
  final InkLogLevel minLevel;
}

/// Clock 注入点——单测用 fake clock 驱动轮转/限流窗口。
abstract class Clock {
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// LoggerService 接口：service / repository / provider 层通过 DI 获取实例。
abstract class LoggerService {
  void debug(String module, String msg, {Map<String, Object?>? extra});
  void info(String module, String msg, {Map<String, Object?>? extra});
  void warn(String module, String msg, {Map<String, Object?>? extra});
  void error(
    String module,
    String msg, {
    Map<String, Object?>? extra,
    Object? cause,
    StackTrace? stackTrace,
  });

  /// 等待缓冲写盘（同步实现下为 no-op，保留接口以便未来异步实现）。
  Future<void> flush();

  /// 关闭日志文件句柄。
  Future<void> close();
}

/// 文件落盘实现（同步写入，保证顺序一致）。
class FileLoggerService implements LoggerService {
  FileLoggerService({
    required AppPaths paths,
    required Clock clock,
    LoggerConfig config = const LoggerConfig(),
  })  : _paths = paths,
        _clock = clock,
        _config = config;

  final AppPaths _paths;
  final Clock _clock;
  final LoggerConfig _config;

  // 限流窗口状态（秒级）。
  int _windowEpochSeconds = 0;
  int _debugCountInWindow = 0;
  int _debugDroppedInWindow = 0;

  static const Set<String> _redactKeys = <String>{
    'key',
    'api_key',
    'apikey',
    'token',
    'authorization',
    'authorisation',
    'prompt',
    'password',
    'proxy_password',
    'proxypassword',
    'secret',
  };

  File get _activeFile => File(p.join(_paths.logs.path, 'inkframe.log'));

  void _ensureDir() {
    final dir = _paths.logs;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  Map<String, Object?> _redact(Map<String, Object?>? extra) {
    if (extra == null || extra.isEmpty) {
      return const <String, Object?>{};
    }
    final out = <String, Object?>{};
    for (final entry in extra.entries) {
      final k = entry.key.toLowerCase();
      if (_redactKeys.contains(k)) {
        out[entry.key] = '***';
      } else {
        out[entry.key] = entry.value;
      }
    }
    return out;
  }

  String _serialize(
    InkLogLevel level,
    String module,
    String msg,
    Map<String, Object?> extra,
  ) {
    final payload = <String, Object?>{
      'ts': _clock.nowUtc().toIso8601String(),
      'level': level.wire,
      'module': module,
      'msg': msg,
      'extra': extra,
    };
    return jsonEncode(payload);
  }

  void _writeLine(String line) {
    _ensureDir();
    _activeFile.writeAsStringSync('$line\n',
        mode: FileMode.append, flush: false);
  }

  bool _debugWithinLimit() {
    final nowSec = _clock.nowUtc().millisecondsSinceEpoch ~/ 1000;
    if (nowSec != _windowEpochSeconds) {
      if (_debugDroppedInWindow > 0) {
        final summary = _serialize(
          InkLogLevel.warn,
          'logger.throttle',
          'debug messages dropped',
          <String, Object?>{'dropped': _debugDroppedInWindow},
        );
        _writeLine(summary);
        _debugDroppedInWindow = 0;
      }
      _windowEpochSeconds = nowSec;
      _debugCountInWindow = 0;
    }
    if (_debugCountInWindow >= _config.debugPerSecondLimit) {
      _debugDroppedInWindow += 1;
      return false;
    }
    _debugCountInWindow += 1;
    return true;
  }

  bool _levelAllowed(InkLogLevel level) {
    return level.index >= _config.minLevel.index;
  }

  void _log(
    InkLogLevel level,
    String module,
    String msg,
    Map<String, Object?>? extra,
  ) {
    if (!_levelAllowed(level)) {
      return;
    }
    if (level == InkLogLevel.debug && !_debugWithinLimit()) {
      return;
    }
    final line = _serialize(level, module, msg, _redact(extra));
    _writeLine(line);
    _maybeRotate();
  }

  void _maybeRotate() {
    final file = _activeFile;
    if (!file.existsSync()) {
      return;
    }
    final length = file.lengthSync();
    if (length >= _config.maxFileBytes) {
      _rotateActiveFile();
    }
    _enforceDiskBudget();
  }

  void _rotateActiveFile() {
    final active = _activeFile;
    if (!active.existsSync()) {
      return;
    }
    final ts = _clock
        .nowUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final rotated = File(p.join(_paths.logs.path, 'inkframe.$ts.log'));
    // 如果目标已存在，追加微秒序列避免冲突。
    var target = rotated;
    var suffix = 0;
    while (target.existsSync()) {
      suffix += 1;
      target = File(p.join(_paths.logs.path, 'inkframe.$ts-$suffix.log'));
    }
    active.renameSync(target.path);
  }

  void _enforceDiskBudget() {
    final files = _logFilesByAge();
    int totalBytes = 0;
    for (final f in files) {
      totalBytes += f.lengthSync();
    }
    if (totalBytes <= _config.totalDiskBudgetBytes) {
      return;
    }
    for (final f in files) {
      if (totalBytes <= _config.emergencyReclaimTargetBytes) {
        break;
      }
      if (f.path == _activeFile.path) {
        continue;
      }
      final size = f.lengthSync();
      try {
        f.deleteSync();
        totalBytes -= size;
      } on FileSystemException {
        // 删除失败（锁定/权限）→ 跳过，下次重试。
        continue;
      }
    }
  }

  List<File> _logFilesByAge() {
    if (!_paths.logs.existsSync()) {
      return const <File>[];
    }
    final entries = <File>[];
    for (final e in _paths.logs.listSync()) {
      if (e is File) {
        final name = p.basename(e.path);
        if (!name.startsWith('inkframe.')) {
          continue;
        }
        if (name.startsWith('inkframe.crash.')) {
          continue;
        }
        entries.add(e);
      }
    }
    entries.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    return entries;
  }

  @override
  void debug(String module, String msg, {Map<String, Object?>? extra}) =>
      _log(InkLogLevel.debug, module, msg, extra);

  @override
  void info(String module, String msg, {Map<String, Object?>? extra}) =>
      _log(InkLogLevel.info, module, msg, extra);

  @override
  void warn(String module, String msg, {Map<String, Object?>? extra}) =>
      _log(InkLogLevel.warn, module, msg, extra);

  @override
  void error(
    String module,
    String msg, {
    Map<String, Object?>? extra,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final enriched = <String, Object?>{
      ...?extra,
      if (cause != null) 'cause': cause.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    _log(InkLogLevel.error, module, msg, enriched);
  }

  @override
  Future<void> flush() async {
    // 同步 writeAsStringSync 已经落盘，flush 为 no-op。
  }

  @override
  Future<void> close() async {
    // 无持有资源，留作兼容接口。
  }
}
