// PgDumpBackupService：DatabaseBackupService 的 pg_dump 落地（LB-10）。
//
// 流程：定位 pg_dump → 当日已有则跳过 → 建 backups 目录 → pg_dump -Fc 落盘
// （PGPASSWORD 经 env 传 SCRAM 口令；trust 集群不设）→ 成功后按日期序保留 7 份。
// 失败仅 warn：非零退出 / 无法启动 / 无二进制均不抛，交启动触发器决定后续。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/database_backup_service.dart';
import '../core/interfaces/process_runner.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/pg_binary_locator.dart';

/// 日志 module 名（内部标识，English-only）。
const String kBackupModule = 'db.backup';

/// 备份文件名前缀 / 后缀（-Fc 自定义格式）。
const String kBackupFilePrefix = 'inkframe-';
const String kBackupFileSuffix = '.dump';

/// 保留份数（按日期序）。
const int kBackupRetainCount = 7;

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

  /// 纯函数：当日备份文件名（UTC 日期，与仓库其它启动 housekeeping 同口径）。
  static String backupFileName(DateTime utc) {
    final String y = utc.year.toString().padLeft(4, '0');
    final String m = utc.month.toString().padLeft(2, '0');
    final String d = utc.day.toString().padLeft(2, '0');
    return '$kBackupFilePrefix$y-$m-$d$kBackupFileSuffix';
  }

  /// 纯函数：给定 backups 目录现有文件名，返回超出保留份数应删除的（最旧优先）。
  /// 仅识别 `inkframe-YYYY-MM-DD.dump`；文件名 ISO 日期段字典序即时间序。
  static List<String> backupsToPrune(
    List<String> names, {
    int keep = kBackupRetainCount,
  }) {
    final List<String> matches = names.where(_isDatedBackupName).toList()
      ..sort(); // 升序=旧→新。
    if (matches.length <= keep) return const <String>[];
    return matches.sublist(0, matches.length - keep);
  }

  static final RegExp _datedName = RegExp(
    '^${RegExp.escape(kBackupFilePrefix)}\\d{4}-\\d{2}-\\d{2}'
    '${RegExp.escape(kBackupFileSuffix)}\$',
  );

  static bool _isDatedBackupName(String name) => _datedName.hasMatch(name);

  @override
  Future<BackupOutcome> backup(BackupConnection connection) async {
    // 1) 定位 pg_dump——开发机无打包 PG（PgBinaryNotFoundError）视为跳过，非失败。
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

    // 2) 当日已有 → 跳过（每日一份）。
    final DateTime now = _clock.nowUtc();
    final Directory dir = _paths.backups;
    final File target = File(p.join(dir.path, backupFileName(now)));
    if (target.existsSync()) {
      return BackupOutcome.skippedAlreadyToday;
    }

    // 3) 建目录（首启 ensureInitialized 已建，此处防御）。
    try {
      dir.createSync(recursive: true);
    } on FileSystemException catch (e) {
      _logger?.warn(kBackupModule, 'backup.mkdir_failed',
          extra: <String, Object?>{'reason': e.message});
      return BackupOutcome.failed;
    }

    // 4) pg_dump -Fc 先写 `.partial` 临时文件，成功后原子 rename 到最终名——
    // 这样进程被 SIGKILL/断电中途夭折只会留下 .partial（不匹配备份命名、不占保留位、
    // 不会被「当日已有」误判为完整备份），下次启动照常重试。PGPASSWORD 经 env
    // （trust 集群 password=null 不设）。先清同名残留 .partial（上次同日崩溃遗留）。
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

    // 5) 保留策略：删最旧、留 7 份（顺带清跨日崩溃遗留的 .partial 碎片）。
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
    for (final String name in backupsToPrune(names)) {
      if (_deleteQuietly(File(p.join(dir.path, name)))) pruned++;
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
