// FileCrashReporter：未捕获错误落盘。
//
// 位置：`~/InkFrame/crashes/inkframe.crash.{ts}.log`（与 logs 平级，见 AppPaths.crashes）。
// 内容：仅 应用版本 + 时间戳 + 错误 + 栈；无 extra、无任意键值上下文——
//       结构性杜绝敏感数据（prompt / key / token 等）混入崩溃文件。
// 轮转：只保留最近 [maxFiles] 个；写第 N+1 个时删最旧（按文件名=时间戳定序）。
// 落盘：同步 writeAsStringSync(flush: true)——崩溃时刻优先保证写入落盘而非吞吐
//       （与 FileLoggerService 同款理由：同步 write 跨越 dart 调度）。
// report 不吞异常：写盘失败（磁盘满/权限）向上抛，由 error_hooks 的最后一道防线兜底。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/crash_reporter.dart';
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
    final File file =
        File(p.join(dir.path, '$_prefix${_stamp(now)}$_suffix'));
    // flush: true 强制 fsync，崩溃时刻确保内容真正落盘。
    file.writeAsStringSync(_render(now, error, stackTrace), flush: true);
    _rotate(dir);
  }

  // 文件名时间戳：紧凑、定宽（毫秒恒 3 位）、字典序即时间序——供轮转判定最旧。
  String _stamp(DateTime now) =>
      now.toIso8601String().replaceAll(RegExp(r'[:.\-]'), '');

  String _render(DateTime now, Object error, StackTrace? stackTrace) {
    return (StringBuffer()
          ..writeln('InkFrame crash report')
          ..writeln('timestamp: ${now.toIso8601String()}')
          ..writeln('version: $_appVersion')
          ..writeln('error: $error')
          ..writeln('stack:')
          ..writeln(stackTrace?.toString() ?? '<no stack>'))
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
