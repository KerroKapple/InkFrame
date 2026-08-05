// PgSwapRestoreService：DatabaseRestoreService 的 scratch 库对换落地（LB-22）。
//
// 为什么不是 pg_restore --clean：--clean 只清 dump 里**有**的对象——旧 schema
// 备份还原到新库会留下 dump 外的残留表，随后前向迁移 42P07 撞表，一次还原把
// app 变砖（设计评审 P1-2）；且默认遇错继续、不回滚（P1-1）。
//
// 对换序（拍板 1）：
//   DROP IF EXISTS tmp → CREATE tmp → pg_restore --single-transaction -d tmp
//   →（失败：DROP tmp，原库分毫未动）→ 探测目标库存在 → RENAME 目标→retired
//   → RENAME tmp→目标 → DROP retired（失败仅 warn）。
// 自愈：目标库不存在（上次对换夹缝崩溃）→ 跳过 rename-away 直接换上。
// 维护 SQL 经 template1 的一次性连接（seam 可 fake）；库名全部来自内部常量，
// 无注入面。
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../core/interfaces/database_backup_service.dart';
import '../core/interfaces/database_restore_service.dart';
import '../core/interfaces/process_runner.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';
import '../storage/pg_binary_locator.dart';
import 'database_backup_service.dart';
import 'process_watchdog.dart';

/// 日志 module 名（内部标识，English-only）。
const String kRestoreModule = 'db.restore';

/// scratch 库名 / 对换退役库名前缀。
const String kRestoreTmpDb = 'inkframe_restore_tmp';
const String kRetiredDbPrefix = 'inkframe_retired_';

/// 维护会话最小面：目录级 DDL 与探测。默认实现包 postgres Connection（template1）。
abstract class MaintenanceSession {
  Future<List<List<Object?>>> execute(String sql);
  Future<void> close();
}

/// 维护 SQL 失败（fake 可脚本化抛出；默认实现把 PgException 翻成本类型）。
class MaintenanceSqlError extends Error {
  MaintenanceSqlError(this.message);
  final String message;
  @override
  String toString() => 'MaintenanceSqlError: $message';
}

typedef MaintenanceSessionFactory = Future<MaintenanceSession> Function(
  BackupConnection connection,
);

/// 默认工厂：连 template1（永远存在的维护库）执行目录级 DDL。
Future<MaintenanceSession> openPgMaintenanceSession(
  BackupConnection c,
) async {
  final conn = await Connection.open(
    Endpoint(
      host: c.host,
      port: c.port,
      database: 'template1',
      username: c.username,
      password: c.password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  return _PgMaintenanceSession(conn);
}

class _PgMaintenanceSession implements MaintenanceSession {
  _PgMaintenanceSession(this._conn);
  final Connection _conn;

  @override
  Future<List<List<Object?>>> execute(String sql) async {
    try {
      final r = await _conn.execute(sql);
      return <List<Object?>>[for (final row in r) row.toList()];
    } on PgException catch (e) {
      throw MaintenanceSqlError(e.message);
    } on Exception catch (e) {
      // 连接中途断（SocketException 等）不属 PgException——同样收口成
      // MaintenanceSqlError，杜绝逃逸出 flow（#189 评审 P1-1 次级口）。
      throw MaintenanceSqlError(e.toString());
    }
  }

  @override
  Future<void> close() async {
    try {
      await _conn.close();
    } on Exception {
      // 关闭失败不得顶掉主流程返回值（finally 内被调）。
    }
  }
}

class PgSwapRestoreService implements DatabaseRestoreService {
  PgSwapRestoreService({
    required AppPaths paths,
    required PgBinaryLocator locator,
    required ProcessStarter starter,
    required Clock clock,
    MaintenanceSessionFactory maintenance = openPgMaintenanceSession,
    LoggerService? logger,
    Duration restoreTimeout = const Duration(minutes: 30),
  })  : _paths = paths,
        _locator = locator,
        _starter = starter,
        _clock = clock,
        _maintenance = maintenance,
        _logger = logger,
        _restoreTimeout = restoreTimeout;

  final AppPaths _paths;
  final PgBinaryLocator _locator;
  final ProcessStarter _starter;
  final Clock _clock;
  final MaintenanceSessionFactory _maintenance;
  final LoggerService? _logger;

  /// pg_restore 看门狗上限（债153）：kill 后 --single-transaction 自动回滚
  /// 无半状态,scratch 库随即被 drop——原库全程不动。
  final Duration _restoreTimeout;

  @override
  Future<RestoreOutcome> restore(
    BackupConnection connection,
    String backupFileName,
  ) async {
    // 1) 识别名校验（防穿越）+ 文件存在。
    if (backupKindOf(backupFileName) == null) {
      _logger?.warn(kRestoreModule, 'restore.invalid_name',
          extra: <String, Object?>{'name': backupFileName});
      return RestoreOutcome.failed;
    }
    final File dump = File(p.join(_paths.backups.path, backupFileName));
    if (!dump.existsSync()) {
      _logger?.warn(kRestoreModule, 'restore.missing_file',
          extra: <String, Object?>{'name': backupFileName});
      return RestoreOutcome.failed;
    }

    // 2) sidecar 校验（存量备份无 sidecar → 跳过）。
    final RestoreOutcome? gate = _verifySidecar(dump);
    if (gate != null) return gate;

    // 3) 定位 pg_restore。
    final File pgRestore;
    try {
      pgRestore = _locator.locate().pgRestore;
    } on PgBinaryNotFoundError {
      _logger?.warn(kRestoreModule, 'restore.no_binaries');
      return RestoreOutcome.failedNoBinaries;
    }
    if (!pgRestore.existsSync()) {
      _logger?.warn(kRestoreModule, 'restore.no_binaries');
      return RestoreOutcome.failedNoBinaries;
    }

    // 4) scratch 灌入 + 对换。
    final MaintenanceSession session;
    try {
      session = await _maintenance(connection);
    } on Exception catch (e) {
      _logger?.warn(kRestoreModule, 'restore.maintenance_unavailable',
          extra: <String, Object?>{'error': e.toString()});
      return RestoreOutcome.failed;
    }
    try {
      // FORCE 同 _dropTmpQuietly：上次超时残留的 backend 可能还占着 tmp 库。
      await session
          .execute('DROP DATABASE IF EXISTS "$kRestoreTmpDb" WITH (FORCE)');
      await session.execute('CREATE DATABASE "$kRestoreTmpDb"');

      final List<String> args = <String>[
        '-h', connection.host,
        '-p', '${connection.port}',
        '-U', connection.username,
        '-d', kRestoreTmpDb,
        '--single-transaction',
        dump.path,
      ];
      final Map<String, String>? env = connection.password == null
          ? null
          : <String, String>{'PGPASSWORD': connection.password!};
      final WatchdogResult result;
      try {
        result = await runWithWatchdog(_starter, pgRestore.path, args,
            environment: env, timeout: _restoreTimeout);
      } on ProcessException catch (e) {
        _logger?.warn(kRestoreModule, 'restore.spawn_failed',
            extra: <String, Object?>{'reason': e.message});
        await _dropTmpQuietly(session);
        return RestoreOutcome.failed;
      }
      // exit 0 优先于超时判定：kill 迟到、scratch 已灌完 → 照常对换
      //（与 EX-3「已成功不误删」同一不变量,评审 P2-1）。
      if (result.exitCode != 0) {
        final String event =
            result.timedOut ? 'restore.timeout' : 'restore.pg_restore_failed';
        _logger?.warn(kRestoreModule, event, extra: <String, Object?>{
          if (result.timedOut) 'timeout_s': _restoreTimeout.inSeconds,
          'exit_code': result.exitCode,
          // 被 kill 的 pg_restore 的 stderr 尾部往往就是挂死根因（评审 P2-3）。
          'stderr': result.stderrTail.trim(),
          if (result.streamError != null)
            'stream_error': result.streamError.toString(),
        });
        await _dropTmpQuietly(session);
        return RestoreOutcome.failed;
      }

      // 对换：目标库在则先退役（自愈：不在=上次夹缝崩溃，直接换上）。
      final String db = connection.database;
      final bool targetExists = (await session.execute(
        "SELECT 1 FROM pg_database WHERE datname = '$db'",
      ))
          .isNotEmpty;
      final String retired = _retiredName(_clock.nowUtc());
      if (targetExists) {
        await session.execute('ALTER DATABASE "$db" RENAME TO "$retired"');
      }
      try {
        await session
            .execute('ALTER DATABASE "$kRestoreTmpDb" RENAME TO "$db"');
      } on MaintenanceSqlError catch (e) {
        // rename-in 失败：补偿回滚 rename-away，原库归位（#189 评审 P2-1——
        // 否则原库滞留 retired 名下，「数据未被改动」变谎言）。
        _logger?.warn(kRestoreModule, 'restore.swap_failed',
            extra: <String, Object?>{'error': e.message});
        if (targetExists) {
          try {
            await session
                .execute('ALTER DATABASE "$retired" RENAME TO "$db"');
          } on MaintenanceSqlError catch (e2) {
            // 补偿也失败：原库滞留 retired——大声记日志（含库名）供手工救援。
            _logger?.error(kRestoreModule, 'restore.swap_stranded',
                extra: <String, Object?>{
                  'retired': retired,
                  'error': e2.message,
                });
          }
        }
        await _dropTmpQuietly(session);
        return RestoreOutcome.failed;
      }
      if (targetExists) {
        try {
          await session.execute('DROP DATABASE "$retired"');
        } on MaintenanceSqlError catch (e) {
          // 退役库删不掉只是占空间，不推翻已完成的对换。
          _logger?.warn(kRestoreModule, 'restore.drop_retired_failed',
              extra: <String, Object?>{'error': e.message});
        }
      }
      _logger?.info(kRestoreModule, 'restore.done',
          extra: <String, Object?>{'file': backupFileName});
      return RestoreOutcome.restored;
    } on MaintenanceSqlError catch (e) {
      _logger?.warn(kRestoreModule, 'restore.maintenance_failed',
          extra: <String, Object?>{'error': e.message});
      await _dropTmpQuietly(session);
      return RestoreOutcome.failed;
    } finally {
      await session.close();
    }
  }

  /// sidecar 门：null=放行；否则返回拒绝结果。
  RestoreOutcome? _verifySidecar(File dump) {
    final File meta = File('${dump.path}$kBackupMetaSuffix');
    if (!meta.existsSync()) return null; // 存量备份（LB-10 时代）无 sidecar。
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      _logger?.warn(kRestoreModule, 'restore.meta_corrupt');
      return RestoreOutcome.failedCorrupt;
    } on FileSystemException {
      _logger?.warn(kRestoreModule, 'restore.meta_unreadable');
      return RestoreOutcome.failedCorrupt;
    }
    final Object? expected = parsed['sha256'];
    if (expected is String) {
      final String actual;
      try {
        actual = sha256.convert(dump.readAsBytesSync()).toString();
      } on FileSystemException {
        // dump 被占锁/中途被删（AV/云盘同步）——读不了就不还原，
        // 绝不能让异常逃逸出 flow（#189 评审 P1-1）。
        _logger?.warn(kRestoreModule, 'restore.dump_unreadable');
        return RestoreOutcome.failed;
      }
      if (actual != expected) {
        _logger?.warn(kRestoreModule, 'restore.sha_mismatch');
        return RestoreOutcome.failedCorrupt;
      }
    }
    final Object? version = parsed['schemaVersion'];
    if (version is int && version > kAppMigrations.last.version) {
      _logger?.warn(kRestoreModule, 'restore.version_newer',
          extra: <String, Object?>{'backup_schema': version});
      return RestoreOutcome.failedVersionNewer;
    }
    return null;
  }

  Future<void> _dropTmpQuietly(MaintenanceSession session) async {
    try {
      // WITH (FORCE)（PG13+,内嵌 PG17）：超时 kill 后 pg_restore 的服务端
      // backend 可能仍在跑长语句占着库,普通 DROP 会 55006 拒绝——恰是
      // 超时分支的主流成因（评审 P1-2）。FORCE 直接终止占用连接。
      await session
          .execute('DROP DATABASE IF EXISTS "$kRestoreTmpDb" WITH (FORCE)');
    } on MaintenanceSqlError catch (e) {
      // 清不掉留给下次进门的 DROP;但必须留证（评审 P1-2:整库残留不可无声）。
      _logger?.warn(kRestoreModule, 'restore.drop_tmp_failed',
          extra: <String, Object?>{'error': e.toString()});
    }
  }

  static String _retiredName(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '$kRetiredDbPrefix${utc.year}${two(utc.month)}${two(utc.day)}'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }
}
