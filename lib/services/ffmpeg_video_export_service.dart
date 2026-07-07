// FfmpegVideoExportService：concat demuxer 顺序拼接（流拷贝，不转码）。
//
// 命令形态：ffmpeg -f concat -safe 0 -i <list> -c copy -y <out>
// list 文件逐行 `file '<abs>'`，单引号按 concat demuxer 规则转义为 '\''；
// 写入系统临时目录（可注入覆盖），成功/失败路径都在 finally 删除。
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
    required ProcessRunner processRunner,
    Clock clock = const SystemClock(),
    Directory? tempRoot,
  })  : _fileResolver = fileResolver,
        _ffmpegLocator = ffmpegLocator,
        _processRunner = processRunner,
        _clock = clock,
        _tempRoot = tempRoot;

  static const String _kExportsDir = 'exports';
  static const int _kStderrCap = 4000;

  final FileResolverService _fileResolver;
  final FfmpegLocator _ffmpegLocator;
  final ProcessRunner _processRunner;
  final Clock _clock;
  final Directory? _tempRoot;

  @override
  Future<String> concat({
    required String projectId,
    required List<String> inputRelativePaths,
    String? outputBaseName,
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

      final result = await _runFfmpeg(ffmpeg, listFile, outputFile);
      if (result.exitCode != 0) {
        // `-y` 可能已写出半截产物,失败时不留损坏文件。
        _deleteIfExists(outputFile);
        throw LocalIOError(
          extra: <String, Object?>{
            'reason': 'ffmpeg_failed',
            'exit_code': result.exitCode,
            'stderr': _tail(result.stderr.toString()),
          },
        );
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

  Future<ProcessResult> _runFfmpeg(
    String ffmpeg,
    File listFile,
    File outputFile,
  ) async {
    try {
      return await _processRunner.run(ffmpeg, <String>[
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy',
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
