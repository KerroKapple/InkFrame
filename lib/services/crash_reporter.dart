// FileCrashReporter：未捕获错误落盘。
//
// 位置：`<root>/crashes/inkframe.crash.{ts}.log`（与 logs 平级，见 AppPaths.crashes）。
// 内容：仅 应用版本 + 时间戳 + 错误 + 栈；无 extra、无任意键值上下文——
//       结构性杜绝敏感数据（prompt / key / token 等）混入崩溃文件。
// 轮转：只保留最近 [maxFiles] 个；写第 N+1 个时删最旧（按文件名=时间戳定序）。
// 落盘：同步 writeAsStringSync(flush: true)——崩溃时刻优先保证写入落盘而非吞吐
//       （与 FileLoggerService 同款理由：同步 write 跨越 dart 调度）。
// report 不吞异常：写盘失败（磁盘满/权限）向上抛，由 error_hooks 的最后一道防线兜底。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/crash_reporter.dart';
import '../core/logging/log_sanitizer.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';

class FileCrashReporter implements CrashReporter {
  FileCrashReporter({
    required AppPaths paths,
    required Clock clock,
    required String appVersion,
    int maxFiles = 3,
  })  : _paths = paths,
        _clock = clock,
        _appVersion = appVersion,
        _maxFiles = maxFiles;

  final AppPaths _paths;
  final Clock _clock;
  final String _appVersion;
  final int _maxFiles;

  static const String _prefix = 'inkframe.crash.';
  static const String _suffix = '.log';

  @override
  void report(Object error, StackTrace? stackTrace) {
    final Directory dir = _paths.crashes;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final DateTime now = _clock.nowUtc();
    // flush: true 强制 fsync，崩溃时刻确保内容真正落盘。
    _uniqueFile(dir, _stamp(now))
        .writeAsStringSync(_render(now, error, stackTrace), flush: true);
    _rotate(dir);
  }

  // 文件名时间戳：定宽 YYYYMMDDThhmmss + 6 位微秒 + Z——字典序严格等于时间序，供轮转
  // 判定"最旧"。绝不能用 toIso8601String：micro==0 时它省略到 3 位小数、否则 6 位，
  // 宽度不定 → compareTo 反转（较早的 `…123Z` 会排在较晚的 `…123456Z` 之后）→ 误删较新崩溃。
  String _stamp(DateTime now) {
    String pad(int v, int width) => v.toString().padLeft(width, '0');
    final int frac = now.millisecond * 1000 + now.microsecond; // 0..999999
    return '${pad(now.year, 4)}${pad(now.month, 2)}${pad(now.day, 2)}'
        'T${pad(now.hour, 2)}${pad(now.minute, 2)}${pad(now.second, 2)}'
        '${pad(frac, 6)}Z';
  }

  // 同一时钟刻度内多次崩溃 → 追加 -$n 序号避免同名覆盖（丢崩溃），同 FileLoggerService。
  File _uniqueFile(Directory dir, String stamp) {
    File target = File(p.join(dir.path, '$_prefix$stamp$_suffix'));
    var n = 0;
    while (target.existsSync()) {
      n += 1;
      target = File(p.join(dir.path, '$_prefix$stamp-$n$_suffix'));
    }
    return target;
  }

  String _render(DateTime now, Object error, StackTrace? stackTrace) {
    // 防御性脱敏：error/stack 可能夹带凭证（LB-07 起 PG 口令流经连接层，其失败是未捕获
    // 崩溃高发点）→ 与日志共用 LogSanitizer 打码后再落盘，杜绝明文密钥写盘。
    final String maskedError = LogSanitizer.maskString(error.toString());
    final String maskedStack = stackTrace == null
        ? '<no stack>'
        : LogSanitizer.maskString(stackTrace.toString());
    return (StringBuffer()
          ..writeln('InkFrame crash report')
          ..writeln('timestamp: ${now.toIso8601String()}')
          ..writeln('version: $_appVersion')
          ..writeln('error: $maskedError')
          ..writeln('stack:')
          ..writeln(maskedStack))
        .toString();
  }

  // 轮转：按文件名（=时间戳）升序，超过 maxFiles 时删最旧的若干个。
  void _rotate(Directory dir) {
    final List<File> files = <File>[
      for (final FileSystemEntity e in dir.listSync())
        if (e is File &&
            p.basename(e.path).startsWith(_prefix) &&
            p.basename(e.path).endsWith(_suffix))
          e,
    ]..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    if (files.length <= _maxFiles) {
      return;
    }
    for (final File f in files.take(files.length - _maxFiles)) {
      try {
        f.deleteSync();
      } on FileSystemException {
        // 删除失败（锁定/权限）→ 跳过，下次轮转再试（与 FileLoggerService 同款处理）。
        continue;
      }
    }
  }
}
