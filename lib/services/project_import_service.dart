// ZipProjectImportService：项目包导入落地（LB-12 拍板全集）。
//
// 流程：raw 头重名检测 + 解码（guard 与提取共用同一 Archive，杜绝验一份解另一份）
// → 条目安全门 → manifest 门 → data.json（计数 sink 限额）→ 重映射 →
// staging 提取（canvases/{旧} 段按映射改名 + 实测字节限额 + 界内二次校验）→
// rename 落位 → 单事务写库 → 失败补偿删目录（零残留）。
// 失败以 ImportResult 返回（不抛）；启动/每次导入前清扫 .import-* 残留。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/project_import_service.dart';
import '../core/interfaces/project_import_writer.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';
import 'import/archive_import_guard.dart';
import 'import/import_remapper.dart';

/// 日志 module 名（内部标识，English-only）。
const String kImportModule = 'project.import';

/// staging 目录前缀（projects/ 下；崩溃残留由 sweep 清扫）。
const String kImportStagingPrefix = '.import-';

/// manifest 条目的解压上限（1 MiB——正常几百字节）。
const int kImportMaxManifestBytes = 1024 * 1024;

class ZipProjectImportService implements ProjectImportService {
  ZipProjectImportService({
    required AppPaths paths,
    required ProjectImportWriter writer,
    LoggerService? logger,
    String Function()? newIdFactory,
    int entryLimitBytes = kImportMaxEntryBytes,
    int totalLimitBytes = kImportMaxTotalBytes,
    int dataJsonLimitBytes = kImportMaxDataJsonBytes,
  })  : _paths = paths,
        _writer = writer,
        _logger = logger,
        _newId = newIdFactory ?? const Uuid().v4,
        _entryLimit = entryLimitBytes,
        _totalLimit = totalLimitBytes,
        _dataJsonLimit = dataJsonLimitBytes;

  final AppPaths _paths;
  final ProjectImportWriter _writer;
  final LoggerService? _logger;
  final String Function() _newId;
  final int _entryLimit;
  final int _totalLimit;
  final int _dataJsonLimit;

  @override
  Future<ImportResult> importArchive({required String zipPath}) async {
    _sweepStaleStaging();
    Directory? staging;
    Directory? placed;
    var succeeded = false;
    try {
      // 0) raw 中央目录重名检测（deduped Archive 看不见重名——内容取首个、
      // 元数据取末个的分裂来源，整包拒，安全评审 P2）。
      final rawInput = InputFileStream(zipPath);
      final directory = ZipDirectory();
      try {
        directory.read(rawInput);
      } finally {
        await rawInput.close();
      }
      final rawNames =
          directory.fileHeaders.map((h) => h.filename).toList(growable: false);
      if (rawNames.toSet().length != rawNames.length) {
        return _reject(ImportOutcome.failedCorrupt, 'duplicate_entry');
      }

      // 1) 解码（guard 与提取共用同一 Archive）。
      final input = InputFileStream(zipPath);
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } finally {
        // Archive 惰性引用 input——条目内容在 writeContent 时才读；
        // 此处不 close，交由 archive.clear 生命周期（方法尾 finally）。
      }
      try {
        // 2) 条目安全门。
        final metas = <ArchiveEntryMeta>[
          for (final f in archive.files)
            ArchiveEntryMeta(
              name: f.name,
              declaredSize: f.size,
              isSymlink: f.isSymbolicLink,
            ),
        ];
        final String? entryReason = validateArchiveEntries(metas);
        if (entryReason != null) {
          return _reject(ImportOutcome.failedCorrupt, entryReason);
        }

        // 3) manifest 门。
        final Map<String, Object?>? manifest =
            _readJsonEntry(archive, kImportManifestEntry, kImportMaxManifestBytes);
        if (manifest == null) {
          return _reject(ImportOutcome.failedCorrupt, 'manifest_unreadable');
        }
        final String? manifestReason = validateManifest(
          manifest,
          currentSchemaVersion: kAppMigrations.last.version,
        );
        if (manifestReason != null) {
          if (manifestReason == 'format_version') {
            return _reject(ImportOutcome.failedFormat, manifestReason);
          }
          if (manifestReason == 'schema_version_newer') {
            return _reject(ImportOutcome.failedVersionNewer, manifestReason);
          }
          return _reject(ImportOutcome.failedCorrupt, manifestReason);
        }

        // 4) data.json（计数 sink 限额）。
        final Map<String, Object?>? data =
            _readJsonEntry(archive, kImportDataEntry, _dataJsonLimit);
        if (data == null) {
          return _reject(ImportOutcome.failedCorrupt, 'data_unreadable');
        }

        // 5) 重映射。
        final ImportPlanData plan = remapArchiveData(data, newId: _newId);
        if (plan.droppedColumnCount + plan.nulledRefCount +
                plan.droppedRowCount >
            0) {
          _logger?.warn(kImportModule, 'import.lenient_repairs',
              extra: <String, Object?>{
                'dropped_columns': plan.droppedColumnCount,
                'nulled_refs': plan.nulledRefCount,
                'dropped_rows': plan.droppedRowCount,
              });
        }

        // 6) staging 提取（canvases/{旧} 段必须命中映射；实测限额；界内校验）。
        staging = Directory(p.join(
          _paths.projects.path,
          '$kImportStagingPrefix${_newId()}',
        ));
        staging.createSync(recursive: true);
        final String stagingRoot = p.canonicalize(staging.path);
        final budget = ImportByteBudget(limit: _totalLimit);
        for (final f in archive.files) {
          if (!f.name.startsWith(kImportFilesPrefix) || !f.isFile) continue;
          String rel = f.name.substring(kImportFilesPrefix.length);
          final segs = rel.split('/');
          if (segs.length >= 2 && segs.first == 'canvases') {
            final String? mapped = plan.canvasIdMap[segs[1]];
            if (mapped == null) {
              // UUID 形但不在 data.json 画布集内——孤儿目录注入，整包拒。
              return _reject(ImportOutcome.failedCorrupt, 'unknown_canvas_dir');
            }
            rel = (<String>['canvases', mapped, ...segs.sublist(2)]).join('/');
          }
          final File target = File(p.join(staging.path, rel));
          // 纵深防御：改名发生在 guard 之后，join 点必须重验界内。
          final String abs = p.canonicalize(target.path);
          if (!p.isWithin(stagingRoot, abs)) {
            return _reject(ImportOutcome.failedCorrupt, 'path_escape');
          }
          target.parent.createSync(recursive: true);
          final out = CountingLimitOutputStream(
            OutputFileStream(target.path),
            entryLimit: _entryLimit,
            totalCounter: budget,
          );
          try {
            f.writeContent(out);
          } finally {
            out.closeSync();
          }
        }

        // 7) rename 落位（单次目录改名；此后失败补偿删落位目录）。
        placed = Directory(p.join(_paths.projects.path, plan.newProjectId));
        staging.renameSync(placed.path);
        staging = null;

        // 8) 单事务写库。
        await _writer.writeAll(plan);

        succeeded = true;
        _logger?.info(kImportModule, 'import.done', extra: <String, Object?>{
          'project_id': plan.newProjectId,
        });
        return ImportResult(
          outcome: ImportOutcome.imported,
          newProjectId: plan.newProjectId,
        );
      } finally {
        await archive.clear();
        await input.close();
      }
    } on ImportLimitExceeded catch (e) {
      return _reject(ImportOutcome.failedCorrupt, 'limit_${e.what}');
    } on FormatException catch (e) {
      // zip 结构损坏 / JSON 损坏。
      return _reject(ImportOutcome.failedCorrupt, 'format:${e.message}');
    } on InkError catch (e, st) {
      _logger?.error(kImportModule, 'import.failed', cause: e, stackTrace: st);
      return const ImportResult(outcome: ImportOutcome.failed);
    } on FileSystemException catch (e, st) {
      _logger?.error(kImportModule, 'import.io_failed',
          cause: e, stackTrace: st);
      return const ImportResult(outcome: ImportOutcome.failed);
    } catch (e, st) {
      // 放行点：不受控输入的解析边界——任何逃逸收成 failed，绝不崩 UI。
      _logger?.error(kImportModule, 'import.unexpected',
          cause: e, stackTrace: st);
      return const ImportResult(outcome: ImportOutcome.failed);
    } finally {
      // 补偿（拍板 5）：staging 未落位→删 staging；已落位但未成功（写库失败/
      // 任何逃逸）→删落位目录——零残留。成功路径二者均不删。
      _deleteQuietly(staging);
      if (!succeeded) _deleteQuietly(placed);
    }
  }

  ImportResult _reject(ImportOutcome outcome, String reason) {
    _logger?.warn(kImportModule, 'import.rejected',
        extra: <String, Object?>{'reason': reason});
    return ImportResult(outcome: outcome, reason: reason);
  }

  Map<String, Object?>? _readJsonEntry(
    Archive archive,
    String name,
    int limit,
  ) {
    final ArchiveFile? f = archive.find(name);
    if (f == null) return null;
    final mem = OutputMemoryStream();
    final out = CountingLimitOutputStream(
      mem,
      entryLimit: limit,
      totalCounter: ImportByteBudget(limit: limit),
    );
    f.writeContent(out);
    final Object? parsed = jsonDecode(utf8.decode(mem.getBytes()));
    if (parsed is! Map) return null;
    return parsed.cast<String, Object?>();
  }

  void _sweepStaleStaging() {
    try {
      for (final e in _paths.projects.listSync(followLinks: false)) {
        if (e is Directory &&
            p.basename(e.path).startsWith(kImportStagingPrefix)) {
          e.deleteSync(recursive: true);
          _logger?.warn(kImportModule, 'import.stale_staging_swept',
              extra: <String, Object?>{'dir': p.basename(e.path)});
        }
      }
    } on FileSystemException {
      // 清扫失败不阻断导入。
    }
  }

  void _deleteQuietly(Directory? dir) {
    if (dir == null) return;
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      _logger?.error(kImportModule, 'import.compensation_failed',
          extra: <String, Object?>{'dir': dir.path, 'reason': e.message});
    }
  }
}
