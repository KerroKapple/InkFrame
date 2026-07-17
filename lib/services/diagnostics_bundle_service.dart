// ZipDiagnosticsBundleService：诊断包导出落地（LB-18）。
//
// 内容：info.json + logs/*（含 pg.log）+ crashes/* + config 白名单两文件。
// **config 目录绝不整扫**——macOS Debug 的明文 secrets.dev.json 由白名单
// 结构性排除（红测钉死包内无 api_key）。落盘纪律同 LB-11/22。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/diagnostics_bundle_service.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';

/// 日志 module 名（内部标识，English-only）。
const String kDiagnosticsModule = 'diagnostics';

/// config 目录白名单：只这两个文件进包（按设计均无 key）。
const List<String> kDiagnosticsConfigAllowlist = <String>[
  'preferences.json',
  'custom_providers.json',
];

/// 纯函数：建议保存文件名（时间戳）。
String diagnosticsBundleFileName(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'inkframe-diagnostics-${utc.year}-${two(utc.month)}-${two(utc.day)}'
      '-${two(utc.hour)}${two(utc.minute)}${two(utc.second)}.zip';
}

class ZipDiagnosticsBundleService implements DiagnosticsBundleService {
  ZipDiagnosticsBundleService({
    required AppPaths paths,
    required Clock clock,
    required String appVersion,
    LoggerService? logger,
  })  : _paths = paths,
        _clock = clock,
        _appVersion = appVersion,
        _logger = logger;

  final AppPaths _paths;
  final Clock _clock;
  final String _appVersion;
  final LoggerService? _logger;

  @override
  Future<void> exportBundle({required String targetPath}) async {
    final File partial = File('$targetPath.partial');
    final encoder = ZipFileEncoder();
    var encoderOpen = false;
    void cleanup() {
      if (encoderOpen) {
        try {
          encoder.closeSync();
        } on FileSystemException {
          // 关闭失败不影响主错误。
        }
        encoderOpen = false;
      }
      try {
        if (partial.existsSync()) partial.deleteSync();
      } on FileSystemException {
        // 清理失败不影响主错误。
      }
    }

    try {
      encoder.create(partial.path);
      encoderOpen = true;
      encoder.addArchiveFile(ArchiveFile.string(
        'info.json',
        jsonEncode(<String, Object?>{
          'appVersion': _appVersion,
          'schemaVersion': kAppMigrations.last.version,
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
          'createdAtUtc': _clock.nowUtc().toIso8601String(),
        }),
      ));

      // logs/*（含 pg.log）与 crashes/*：整目录递归。
      await _addDirectory(encoder, _paths.logs, 'logs');
      await _addDirectory(encoder, _paths.crashes, 'crashes');
      // config：白名单两文件，绝不整扫（secrets.dev.json 结构性排除）。
      for (final String name in kDiagnosticsConfigAllowlist) {
        final File f = File(p.join(_paths.config.path, name));
        if (f.existsSync()) {
          await encoder.addFile(f, 'config/$name');
        }
      }

      await encoder.close();
      encoderOpen = false;

      final File target = File(targetPath);
      if (target.existsSync()) target.deleteSync();
      partial.renameSync(targetPath);
      _logger?.info(kDiagnosticsModule, 'diagnostics.exported',
          extra: <String, Object?>{'file': p.basename(targetPath)});
    } on InkError {
      cleanup();
      rethrow;
    } on FileSystemException catch (e, st) {
      cleanup();
      throw LocalIOError(
        extra: <String, Object?>{
          'reason': 'diagnostics_io',
          'detail': e.message,
        },
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      // 兜底豁免：资源清理边界（archive 包可抛 Error 系），统一翻 LocalIOError。
      cleanup();
      throw LocalIOError(
        extra: <String, Object?>{'reason': 'diagnostics_unexpected'},
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _addDirectory(
    ZipFileEncoder encoder,
    Directory dir,
    String prefix,
  ) async {
    if (!dir.existsSync()) return;
    final List<File> files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)); // 确定序，可复现。
    for (final File f in files) {
      final String rel =
          p.relative(f.path, from: dir.path).replaceAll(r'\', '/');
      await encoder.addFile(f, '$prefix/$rel');
    }
  }
}
