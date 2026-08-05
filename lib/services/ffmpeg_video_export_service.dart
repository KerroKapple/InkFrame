// FfmpegVideoExportService：concat demuxer 顺序拼接（流拷贝，不转码）。
//
// 命令形态：ffmpeg -f concat -safe 0 -i <list> -c copy -progress pipe:1
//           -nostats -y <out>
// list 文件逐行 `file '<abs>'`，单引号按 concat demuxer 规则转义为 '\''；
// 写入系统临时目录（可注入覆盖），成功/失败路径都在 finally 删除。
// 进度经 stdout 键值流解析（EX-3）；取消 = kill + 半成品清理 + CancelledError。
// 错误映射见 VideoExportService 接口 doc；不新增 InkErrorCode。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/process_runner.dart';
import '../core/interfaces/video_export_service.dart';
import '../core/logging/logger_service.dart';
import 'ffmpeg_locator.dart';

class FfmpegVideoExportService implements VideoExportService {
  FfmpegVideoExportService({
    required FileResolverService fileResolver,
    required FfmpegLocator ffmpegLocator,
    required ProcessStarter processStarter,
    Clock clock = const SystemClock(),
    Directory? tempRoot,
  })  : _fileResolver = fileResolver,
        _ffmpegLocator = ffmpegLocator,
        _processStarter = processStarter,
        _clock = clock,
        _tempRoot = tempRoot;

  static const String _kExportsDir = 'exports';
  static const int _kStderrCap = 4000;

  final FileResolverService _fileResolver;
  final FfmpegLocator _ffmpegLocator;
  final ProcessStarter _processStarter;
  final Clock _clock;
  final Directory? _tempRoot;

  @override
  Future<String> concat({
    required String projectId,
    required List<String> inputRelativePaths,
    String? outputBaseName,
    int? totalDurationMs,
    void Function(double progress)? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    if (inputRelativePaths.isEmpty) {
      throw const ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: <String, Object?>{'reason': 'empty_input_list'},
      );
    }

    final inputs = <File>[];
    for (final rel in inputRelativePaths) {
      final file = _fileResolver.resolveInProject(
        projectId: projectId,
        relativePath: rel,
      );
      if (!file.existsSync()) {
        throw LocalIOError(
          extra: <String, Object?>{'reason': 'input_not_found', 'path': rel},
        );
      }
      inputs.add(file);
    }

    final baseName = outputBaseName ??
        'export_${_clock.nowUtc().millisecondsSinceEpoch}';
    _assertPlainFileName(baseName);
    final outputRelative = '$_kExportsDir/$baseName.mp4';
    final outputFile = _fileResolver.resolveInProject(
      projectId: projectId,
      relativePath: outputRelative,
    );

    final ffmpeg = await _ffmpegLocator.locate();
    if (ffmpeg == null) {
      throw const LocalIOError(
        extra: <String, Object?>{'reason': 'ffmpeg_not_found'},
      );
    }

    Directory? tempDir;
    try {
      outputFile.parent.createSync(recursive: true);
      tempDir = (_tempRoot ?? Directory.systemTemp)
          .createTempSync('inkframe_concat_');
      final listFile = File(p.join(tempDir.path, 'inputs.txt'))
        ..writeAsStringSync('${inputs.map(_listLine).join('\n')}\n');

      final running = await _startFfmpeg(ffmpeg, listFile, outputFile);
      cancelToken?.attach(running.kill);

      final int? totalUs = (totalDurationMs != null && totalDurationMs > 0)
          ? totalDurationMs * 1000
          : null;
      var last = 0.0;
      await for (final line in running.stdoutLines) {
        if (totalUs == null || onProgress == null) continue;
        final next = parseProgressLine(
          line,
          totalDurationUs: totalUs,
          last: last,
        );
        if (next != null) {
          last = next;
          onProgress(next);
        }
      }

      final code = await running.exitCode;
      if (cancelToken?.isCancelled ?? false) {
        // 取消判定优先于退出码映射：kill 产生的非零码不是失败。
        _deleteIfExists(outputFile);
        throw const CancelledError.byUser(
          extra: <String, Object?>{'reason': 'export_cancelled'},
        );
      }
      if (code != 0) {
        // `-y` 可能已写出半截产物,失败时不留损坏文件。
        _deleteIfExists(outputFile);
        throw LocalIOError(
          extra: <String, Object?>{
            'reason': 'ffmpeg_failed',
            'exit_code': code,
            'stderr': _tail(running.stderrTail),
          },
        );
      }
      // 成功收口到 1.0（分母略大或流末行缺失时补齐终值）。
      if (onProgress != null && totalUs != null && last < 1.0) {
        onProgress(1.0);
      }
      return outputRelative;
    } on FileSystemException catch (e, st) {
      throw LocalIOError(
        cause: e,
        stackTrace: st,
        extra: <String, Object?>{
          'reason': 'export_io_failed',
          'message': e.message,
        },
      );
    } finally {
      if (tempDir != null) {
        try {
          tempDir.deleteSync(recursive: true);
        } on FileSystemException {
          // 临时目录清理失败不掩盖主结果。
        }
      }
    }
  }

  Future<RunningProcess> _startFfmpeg(
    String ffmpeg,
    File listFile,
    File outputFile,
  ) async {
    try {
      return await _processStarter.start(ffmpeg, <String>[
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy',
        '-progress', 'pipe:1',
        '-nostats',
        '-y', outputFile.path,
      ]);
    } on ProcessException catch (e, st) {
      // 探测后到执行前二进制消失（TOCTOU）:失效缓存,下次 locate 重新探测。
      _ffmpegLocator.invalidate();
      throw LocalIOError(
        cause: e,
        stackTrace: st,
        extra: const <String, Object?>{'reason': 'ffmpeg_not_found'},
      );
    }
  }

  /// -progress 键值行解析（static 供单测直击）。
  /// out_time_ms 键名为 ms 实为**微秒**（ffmpeg 已知怪癖）；
  /// 乱码/负值/回退值返回 null（进度单调不回退），超界 clamp 到 1.0。
  static double? parseProgressLine(
    String line, {
    required int totalDurationUs,
    required double last,
  }) {
    final m = _kOutTimePattern.firstMatch(line.trim());
    if (m == null) return null;
    final us = int.tryParse(m.group(1)!);
    if (us == null || us < 0) return null;
    final progress = (us / totalDurationUs).clamp(0.0, 1.0).toDouble();
    return progress > last ? progress : null;
  }

  static final RegExp _kOutTimePattern = RegExp(r'^out_time_ms=(-?\d+)$');

  static void _deleteIfExists(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // 尽力而为,不掩盖主错误。
    }
  }

  /// concat demuxer 列表行：单引号包裹，内嵌 `'` 转义为 `'\''`。
  static String _listLine(File f) =>
      "file '${f.path.replaceAll("'", "'\\''")}'";

  // 保留名按首个点段匹配：`con.backup` 拒绝，`console` 放行。
  static final RegExp _kWinReservedName = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  );
  static final RegExp _kWinIllegalChars = RegExp(r'[*?"<>|]');

  /// 输出文件名必须是单层纯文件名段：拒绝分隔符 / 盘符冒号 / '..' / 控制字符 /
  /// Windows 非法字符 `* ? " < > |` / Windows 保留设备名（含带扩展名形态）。
  /// 契约：与 UI 侧 isValidExportBaseName 逐字等价，改一侧必改另一侧。
  static void _assertPlainFileName(String name) {
    final hasControlChar =
        name.codeUnits.any((u) => u < 0x20 || u == 0x7f);
    if (name.isEmpty ||
        hasControlChar ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name.contains('..') ||
        _kWinIllegalChars.hasMatch(name) ||
        _kWinReservedName.hasMatch(name)) {
      throw PathSecurityError(
        'outputBaseName must be a plain file name segment: $name',
      );
    }
  }

  static String _tail(String s) =>
      s.length <= _kStderrCap ? s : s.substring(s.length - _kStderrCap);
}