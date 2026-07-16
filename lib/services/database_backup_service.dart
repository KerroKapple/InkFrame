// PgDumpBackupService：DatabaseBackupService 的 pg_dump 落地（LB-10 / LB-22）。
//
// 三族命名分池（LB-22 设计评审 P1-3）：
//   daily      inkframe-YYYY-MM-DD.dump                （每日一份，keep 7）
//   manual     inkframe-manual-YYYY-MM-DD-HHMMSS.dump  （立即备份，keep 3）
//   preRestore inkframe-prerestore-YYYY-MM-DD-HHMMSS.dump（还原前兜底，keep 3）
// 剪枝按族独立——预备份/手动永不挤占每日历史，也永不剪掉还原目标。
// 每份成功发布的备份带 `<name>.meta.json` sidecar：{sha256, schemaVersion,
// createdAtUtc}，还原前校验完整性与版本（拒绝降级循环）。
//
// 流程：定位 pg_dump → （daily 当日已有跳过）→ pg_dump -Fc 写 .partial →
// 原子 rename → 写 sidecar → 分族保留。失败仅以返回值表达（housekeeping），
// **不抛**——调用方必须查返回值（评审 P1-4）。
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/interfaces/database_backup_service.dart';
import '../core/interfaces/process_runner.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';
import '../storage/pg_binary_locator.dart';

/// 日志 module 名（内部标识，English-only）。
const String kBackupModule = 'db.backup';

/// 备份文件名前缀 / 后缀（-Fc 自定义格式）。
const String kBackupFilePrefix = 'inkframe-';
const String kBackupFileSuffix = '.dump';

/// sidecar 后缀。
const String kBackupMetaSuffix = '.meta.json';

/// 各族保留份数。
const int kBackupRetainCount = 7;
const int kManualRetainCount = 3;
const int kPreRestoreRetainCount = 3;

final RegExp _dailyName = RegExp(
  '^${RegExp.escape(kBackupFilePrefix)}\\d{4}-\\d{2}-\\d{2}'
  '${RegExp.escape(kBackupFileSuffix)}\$',
);
final RegExp _manualName = RegExp(
  '^${RegExp.escape(kBackupFilePrefix)}manual-\\d{4}-\\d{2}-\\d{2}-\\d{6}'
  '${RegExp.escape(kBackupFileSuffix)}\$',
);
final RegExp _preRestoreName = RegExp(
  '^${RegExp.escape(kBackupFilePrefix)}prerestore-\\d{4}-\\d{2}-\\d{2}-\\d{6}'
  '${RegExp.escape(kBackupFileSuffix)}\$',
);

/// 纯函数：识别名 → 备份族；非法（穿越/杂名/sidecar）→ null。
BackupKind? backupKindOf(String name) {
  if (_dailyName.hasMatch(name)) return BackupKind.daily;
  if (_manualName.hasMatch(name)) return BackupKind.manual;
  if (_preRestoreName.hasMatch(name)) return BackupKind.preRestore;
  return null;
}

/// 纯函数：排序键（date + time，daily 视为当天最早 000000）。
/// 仅对识别名有意义；调用方先经 [backupKindOf] 过滤。
String backupSortKey(String name) {
  final m = RegExp(r'(\d{4}-\d{2}-\d{2})(?:-(\d{6}))?').firstMatch(name);
  if (m == null) return name;
  return '${m.group(1)}-${m.group(2) ?? '000000'}';
}

class PgDumpBackupService implements DatabaseBackupService {
  PgDumpBackupService({
    required AppPaths paths,
    required PgBinaryLocator locator,
    required ProcessRunner runner,
    required Clock clock,
    LoggerService? logger,
  })  : _paths = paths,
        _locator = locator,
        _runner = runner,
        _clock = clock,
        _logger = logger;

  final AppPaths _paths;
  final PgBinaryLocator _locator;
  final ProcessRunner _runner;
  final Clock _clock;
  final LoggerService? _logger;

  /// 纯函数：当日每日备份文件名（UTC 日期，与仓库其它启动 housekeeping 同口径）。
  static String backupFileName(DateTime utc) {
    return '$kBackupFilePrefix${_datePart(utc)}$kBackupFileSuffix';
  }

  /// 纯函数：时间戳备份文件名（manual / preRestore 族）。
  static String timestampedBackupFileName(DateTime utc, BackupKind kind) {
    final String infix = switch (kind) {
      BackupKind.manual => 'manual-',
      BackupKind.preRestore => 'prerestore-',
      BackupKind.daily =>
        throw ArgumentError('daily uses backupFileName'), // 契约防误用
    };
    final String h = utc.hour.toString().padLeft(2, '0');
    final String m = utc.minute.toString().padLeft(2, '0');
    final String s = utc.second.toString().padLeft(2, '0');
    return '$kBackupFilePrefix$infix${_datePart(utc)}-$h$m$s$kBackupFileSuffix';
  }

  static String _datePart(DateTime utc) {
    final String y = utc.year.toString().padLeft(4, '0');
    final String m = utc.month.toString().padLeft(2, '0');
    final String d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 纯函数：给定目录现有文件名，返回 [kind] 族超出保留份数应删除的（最旧优先）。
  static List<String> backupsToPrune(
    List<String> names, {
    BackupKind kind = BackupKind.daily,
    int? keep,
  }) {
    final int cap = keep ??
        switch (kind) {
          BackupKind.daily => kBackupRetainCount,
          BackupKind.manual => kManualRetainCount,
          BackupKind.preRestore => kPreRestoreRetainCount,
        };
    final List<String> matches =
        names.where((n) => backupKindOf(n) == kind).toList()
          ..sort((a, b) => backupSortKey(a).compareTo(backupSortKey(b)));
    if (matches.length <= cap) return const <String>[];
    return matches.sublist(0, matches.length - cap);
  }

  @override
  Future<BackupOutcome> backup(BackupConnection connection) async {
    final DateTime now = _clock.nowUtc();
    final File target =
        File(p.join(_paths.backups.path, backupFileName(now)));
    // 当日已有 → 跳过（每日一份）。
    if (target.existsSync()) {
      return BackupOutcome.skippedAlreadyToday;
    }
    return _publish(target, connection);
  }

  @override
  Future<BackupNowResult> backupNow(
    BackupConnection connection, {
    required BackupKind kind,
  }) async {
    final File target = File(p.join(
      _paths.backups.path,
      timestampedBackupFileName(_clock.nowUtc(), kind),
    ));
    final BackupOutcome outcome = await _publish(target, connection);
    return BackupNowResult(
      outcome: outcome,
      fileName:
          outcome == BackupOutcome.created ? p.basename(target.path) : null,
    );
  }

  @override
  List<BackupFileInfo> listBackups() {
    final List<BackupFileInfo> out = <BackupFileInfo>[];
    try {
      for (final FileSystemEntity e
          in _paths.backups.listSync(followLinks: false)) {
        if (e is! File) continue;
        final String name = p.basename(e.path);
        final BackupKind? kind = backupKindOf(name);
        if (kind == null) continue;
        final FileStat stat = e.statSync();
        out.add(BackupFileInfo(
          name: name,
          kind: kind,
          sizeBytes: stat.size,
          modified: stat.modified.toUtc(),
        ));
      }
    } on FileSystemException {
      // 目录不存在/不可读 → 空清单（UI 空态兜底）。
      return const <BackupFileInfo>[];
    }
    out.sort((a, b) => backupSortKey(b.name).compareTo(backupSortKey(a.name)));
    return out;
  }

  /// 共享发布主体：定位 → .partial → pg_dump → rename → sidecar → 分族保留。
  Future<BackupOutcome> _publish(
    File target,
    BackupConnection connection,
  ) async {
    // 1) 定位 pg_dump——开发机无打包 PG 视为跳过，非失败。
    final File pgDump;
    try {
      pgDump = _locator.locate().pgDump;
    } on PgBinaryNotFoundError {
      _logger?.warn(kBackupModule, 'backup.skipped.no_binaries');
      return BackupOutcome.skippedNoBinaries;
    }
    if (!pgDump.existsSync()) {
      _logger?.warn(kBackupModule, 'backup.skipped.no_binaries');
      return BackupOutcome.skippedNoBinaries;
    }

    // 2) 建目录（首启 ensureInitialized 已建，此处防御）。
    final Directory dir = target.parent;
    try {
      dir.createSync(recursive: true);
    } on FileSystemException catch (e) {
      _logger?.warn(kBackupModule, 'backup.mkdir_failed',
          extra: <String, Object?>{'reason': e.message});
      return BackupOutcome.failed;
    }

    // 3) pg_dump -Fc 先写 `.partial` 临时文件，成功后原子 rename 到最终名——
    // 中途夭折只会留下 .partial（不匹配识别命名、不占保留位、不被「当日已有」
    // 误判），下次照常重试。PGPASSWORD 经 env（trust 集群 password=null 不设）。
    final File partial = File('${target.path}.partial');
    _deleteQuietly(partial);
    final List<String> args = <String>[
      '-h', connection.host,
      '-p', '${connection.port}',
      '-U', connection.username,
      '-d', connection.database,
      '-Fc',
      '-f', partial.path,
    ];
    final Map<String, String>? env = connection.password == null
        ? null
        : <String, String>{'PGPASSWORD': connection.password!};

    final ProcessResult result;
    try {
      result = await _runner.run(pgDump.path, args, environment: env);
    } on ProcessException catch (e) {
      _logger?.warn(kBackupModule, 'backup.spawn_failed',
          extra: <String, Object?>{'reason': e.message});
      _deleteQuietly(partial);
      return BackupOutcome.failed;
    }

    if (result.exitCode != 0) {
      _logger?.warn(kBackupModule, 'backup.failed', extra: <String, Object?>{
        'exit_code': result.exitCode,
        'stderr': result.stderr.toString().trim(),
      });
      _deleteQuietly(partial); // 清半成品，免占保留位。
      return BackupOutcome.failed;
    }

    // 原子发布：rename 到最终名。失败清 .partial（未发布=下次重试）。
    try {
      partial.renameSync(target.path);
    } on FileSystemException catch (e) {
      _logger?.warn(kBackupModule, 'backup.publish_failed',
          extra: <String, Object?>{'reason': e.message});
      _deleteQuietly(partial);
      return BackupOutcome.failed;
    }

    // 4) sidecar：sha256 + schemaVersion + 创建时刻（还原前校验用；LB-22）。
    // sidecar 写失败不推翻已发布的备份（还原侧按「无 sidecar 存量备份」跳过校验）。
    try {
      final String digest =
          sha256.convert(target.readAsBytesSync()).toString();
      File('${target.path}$kBackupMetaSuffix').writeAsStringSync(jsonEncode(
        <String, Object?>{
          'sha256': digest,
          'schemaVersion': kAppMigrations.last.version,
          'createdAtUtc': _clock.nowUtc().toIso8601String(),
        },
      ));
    } on FileSystemException catch (e) {
      _logger?.warn(kBackupModule, 'backup.meta_failed',
          extra: <String, Object?>{'reason': e.message});
    }

    // 5) 分族保留：各族按各自 cap 剪最旧（顺带清跨日崩溃遗留的 .partial 碎片）。
    final int pruned = _applyRetention(dir);
    _logger?.info(kBackupModule, 'backup.done', extra: <String, Object?>{
      'file': p.basename(target.path),
      'pruned': pruned,
    });
    return BackupOutcome.created;
  }

  int _applyRetention(Directory dir) {
    final List<String> names;
    try {
      names = dir
          .listSync(followLinks: false)
          .whereType<File>()
          .map((File f) => p.basename(f.path))
          .toList();
    } on FileSystemException {
      return 0;
    }
    int pruned = 0;
    for (final BackupKind kind in BackupKind.values) {
      for (final String name in backupsToPrune(names, kind: kind)) {
        if (_deleteQuietly(File(p.join(dir.path, name)))) pruned++;
        // sidecar 连带删（孤儿 sidecar 不占保留位但属垃圾）。
        _deleteQuietly(File(p.join(dir.path, '$name$kBackupMetaSuffix')));
      }
    }
    // 清跨日崩溃遗留的 .partial 碎片（当前 run 已 rename 走，剩下的都是残骸）。
    for (final String name in names.where((n) => n.endsWith('.partial'))) {
      _deleteQuietly(File(p.join(dir.path, name)));
    }
    return pruned;
  }

  bool _deleteQuietly(File f) {
    try {
      if (f.existsSync()) {
        f.deleteSync();
        return true;
      }
    } on FileSystemException {
      // 删不掉不影响正确性（下次重试）。
    }
    return false;
  }
}
