// ZipProjectArchiveService：ProjectArchiveService 的 zip 落地（LB-11）。
//
// 流程：读全保真行 → manifest/data.json → 递归打包 projects/{id} 全量 →
// .partial 原子 rename（镜像 LB-10 落盘纪律）。失败清 partial 抛 LocalIOError。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/project_archive_reader.dart';
import '../core/interfaces/project_archive_service.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';

/// 日志 module 名（内部标识，English-only）。
const String kArchiveModule = 'project.archive';

/// zip 格式版本——LB-12 导入端按此显式拒绝不认识的包（Zero-BC）。
const int kArchiveFormatVersion = 1;

/// 纯函数：项目名 → 建议保存文件名（剥非法字符，空兜底 project）。
String suggestedArchiveName(String projectName) {
  final safe = projectName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .trim();
  return '${safe.isEmpty ? 'project' : safe}.zip';
}

/// 纯函数：行值 JSON 安全化（DateTime → ISO8601 UTC，容器递归）。
Object? jsonSafe(Object? v) {
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key.toString(): jsonSafe(e.value),
    };
  }
  if (v is List) return <Object?>[for (final e in v) jsonSafe(e)];
  return v;
}

class ZipProjectArchiveService implements ProjectArchiveService {
  ZipProjectArchiveService({
    required ProjectArchiveReader reader,
    required AppPaths paths,
    required Clock clock,
    required String appVersion,
    LoggerService? logger,
  })  : _reader = reader,
        _paths = paths,
        _clock = clock,
        _appVersion = appVersion,
        _logger = logger;

  final ProjectArchiveReader _reader;
  final AppPaths _paths;
  final Clock _clock;
  final String _appVersion;
  final LoggerService? _logger;

  @override
  Future<void> exportProject({
    required String projectId,
    required String targetPath,
  }) async {
    final File partial = File('$targetPath.partial');
    final encoder = ZipFileEncoder();
    // encoder 持有 partial 的文件句柄；失败路径必须先 closeSync 再删，
    // 否则 Windows 上句柄未释放 delete 会失败。
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
      _deleteQuietly(partial);
    }

    try {
      final project = await _reader.projectRow(projectId);
      if (project == null) {
        throw LocalIOError(
          extra: <String, Object?>{'reason': 'project_not_found'},
        );
      }

      final Map<String, Object?> data = <String, Object?>{
        'project': jsonSafe(project),
        'canvases': jsonSafe(await _reader.canvasRows(projectId)),
        'nodes': jsonSafe(await _reader.nodeRows(projectId)),
        'edges': jsonSafe(await _reader.edgeRows(projectId)),
        'lanes': jsonSafe(await _reader.laneRows(projectId)),
        'characters': jsonSafe(await _reader.characterRows(projectId)),
        'prompt_presets': jsonSafe(await _reader.presetRows(projectId)),
        'jobs': jsonSafe(await _reader.successJobRows(projectId)),
        'batch_results': jsonSafe(await _reader.batchResultRows(projectId)),
      };
      final Map<String, Object?> manifest = <String, Object?>{
        'formatVersion': kArchiveFormatVersion,
        'schemaVersion': kAppMigrations.last.version,
        'appVersion': _appVersion,
        'exportedAt': _clock.nowUtc().toIso8601String(),
      };

      encoder.create(partial.path);
      encoderOpen = true;
      encoder.addArchiveFile(
        ArchiveFile.string('manifest.json', jsonEncode(manifest)),
      );
      encoder.addArchiveFile(
        ArchiveFile.string('data.json', jsonEncode(data)),
      );

      final Directory projectDir =
          Directory(p.join(_paths.projects.path, projectId));
      if (projectDir.existsSync()) {
        final List<File> entries = projectDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)); // 确定序，可复现。
        for (final File f in entries) {
          final String rel = p
              .relative(f.path, from: projectDir.path)
              .replaceAll(r'\', '/');
          await encoder.addFile(f, 'files/$rel');
        }
      }
      await encoder.close();
      encoderOpen = false;

      // 原子发布：同名旧文件先删（用户在保存对话框已确认覆盖）。
      final File target = File(targetPath);
      if (target.existsSync()) target.deleteSync();
      partial.renameSync(targetPath);
      _logger?.info(kArchiveModule, 'export.done', extra: <String, Object?>{
        'project_id': projectId,
        'file': p.basename(targetPath),
      });
    } on InkError {
      cleanup();
      rethrow;
    } on FileSystemException catch (e, st) {
      cleanup();
      throw LocalIOError(
        extra: <String, Object?>{'reason': 'export_io', 'detail': e.message},
        cause: e,
        stackTrace: st,
      );
    }
  }

  void _deleteQuietly(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // 清理失败不影响主错误（下次导出覆盖 .partial）。
    }
  }
}
