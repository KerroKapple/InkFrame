// PgSwapRestoreService 单测：scratch 库对换序 / 校验门 / 失败原库未动。
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/database_restore_service.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/database_restore_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:path/path.dart' as p;

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime nowUtc() => _now;
}

class _FakeRunner implements ProcessRunner {
  _FakeRunner.withOrder(this.order, {this.exitCode = 0});
  int exitCode;
  int calls = 0;
  String? lastExecutable;
  List<String>? lastArgs;
  Map<String, String>? lastEnv;
  final List<String> order;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    calls++;
    lastExecutable = executable;
    lastArgs = arguments;
    lastEnv = environment;
    order.add('pg_restore');
    return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : 'boom');
  }
}

class _FakeLocator implements PgBinaryLocator {
  _FakeLocator(this._binDir, {this.binExists = true});
  final Directory _binDir;
  final bool binExists;
  @override
  PgBinaryLocation locate() {
    if (!binExists) {
      throw PgBinaryNotFoundError('no packaged PG (dev machine)');
    }
    return PgBinaryLocation(
      binDir: _binDir,
      libDir: Directory(p.join(_binDir.parent.path, 'lib')),
    );
  }
}

/// 记录 SQL 序；可脚本化 datname 探测结果与指定语句失败。
class _FakeMaintenance implements MaintenanceSession {
  _FakeMaintenance(this.order);
  final List<String> order;
  bool targetDbExists = true;
  bool closed = false;

  /// 命中该前缀的 SQL 抛 PgLifecycleError 风格异常（用 StateError 代真 PgException
  /// 会绕开捕获——这里抛 FormatException 家族也不对；直接抛 MaintenanceSqlError）。
  String? failOnPrefix;

  @override
  Future<List<List<Object?>>> execute(String sql) async {
    order.add(sql);
    final f = failOnPrefix;
    if (f != null && sql.startsWith(f)) {
      throw MaintenanceSqlError('scripted failure: $sql');
    }
    if (sql.startsWith('SELECT 1 FROM pg_database')) {
      return targetDbExists ? <List<Object?>>[<Object?>[1]] : <List<Object?>>[];
    }
    return <List<Object?>>[];
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  const conn = BackupConnection(
    host: '127.0.0.1',
    port: 5544,
    username: 'inkframe',
    database: 'postgres',
    password: 'secret-pw',
  );

  late Directory tmp;
  late Directory binDir;
  late AppPaths paths;
  late List<String> order;
  late _FakeMaintenance maint;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_restore_');
    binDir = Directory(p.join(tmp.path, 'pgbin'))..createSync(recursive: true);
    final exe = Platform.isWindows ? 'pg_restore.exe' : 'pg_restore';
    File(p.join(binDir.path, exe)).writeAsStringSync('x');
    paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'data')));
    order = <String>[];
    maint = _FakeMaintenance(order);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// 放一份合法备份（可选带 sidecar），返回文件名。
  String seedBackup({
    String name = 'inkframe-2026-07-15.dump',
    String content = 'PGDMP-fake',
    Map<String, Object?>? meta,
    bool autoMeta = false,
  }) {
    paths.backups.createSync(recursive: true);
    final f = File(p.join(paths.backups.path, name))
      ..writeAsStringSync(content);
    if (autoMeta) {
      meta = <String, Object?>{
        'sha256': sha256.convert(f.readAsBytesSync()).toString(),
        'schemaVersion': kAppMigrations.last.version,
        'createdAtUtc': '2026-07-15T00:00:00.000Z',
      };
    }
    if (meta != null) {
      File('${f.path}.meta.json').writeAsStringSync(jsonEncode(meta));
    }
    return name;
  }

  PgSwapRestoreService build({
    _FakeRunner? runner,
    _FakeLocator? locator,
  }) =>
      PgSwapRestoreService(
        paths: paths,
        locator: locator ?? _FakeLocator(binDir),
        runner: runner ?? _FakeRunner.withOrder(order),
        clock: _FixedClock(DateTime.utc(2026, 7, 16, 10, 20, 30)),
        maintenance: (c) async => maint,
      );

  test('成功序：drop tmp → create tmp → pg_restore(--single-transaction) → 探测 → 双 rename → drop retired',
      () async {
    final name = seedBackup(autoMeta: true);
    final runner = _FakeRunner.withOrder(order);

    final outcome = await build(runner: runner).restore(conn, name);

    expect(outcome, RestoreOutcome.restored);
    expect(order, <String>[
      'DROP DATABASE IF EXISTS "inkframe_restore_tmp"',
      'CREATE DATABASE "inkframe_restore_tmp"',
      'pg_restore',
      "SELECT 1 FROM pg_database WHERE datname = 'postgres'",
      'ALTER DATABASE "postgres" RENAME TO "inkframe_retired_20260716102030"',
      'ALTER DATABASE "inkframe_restore_tmp" RENAME TO "postgres"',
      'DROP DATABASE "inkframe_retired_20260716102030"',
    ]);
    // pg_restore 参数：连的是 tmp 库 + 单事务；PGPASSWORD 经 env。
    expect(runner.lastExecutable,
        endsWith(Platform.isWindows ? 'pg_restore.exe' : 'pg_restore'));
    expect(
      runner.lastArgs,
      containsAllInOrder(<String>[
        '-h', '127.0.0.1', '-p', '5544', '-U', 'inkframe',
        '-d', 'inkframe_restore_tmp', '--single-transaction',
      ]),
    );
    expect(runner.lastArgs!.last, endsWith(name));
    expect(runner.lastEnv?['PGPASSWORD'], 'secret-pw');
    expect(maint.closed, isTrue);
  });

  test('pg_restore 非零退出 → drop tmp、无任何 rename、failed（原库未动）', () async {
    final name = seedBackup(autoMeta: true);
    final runner = _FakeRunner.withOrder(order, exitCode: 1);

    final outcome = await build(runner: runner).restore(conn, name);

    expect(outcome, RestoreOutcome.failed);
    expect(order.where((s) => s.startsWith('ALTER DATABASE')), isEmpty);
    expect(order.last, 'DROP DATABASE IF EXISTS "inkframe_restore_tmp"');
  });

  test('sidecar sha 不符 → failedCorrupt，零进程零 SQL', () async {
    final name = seedBackup(meta: <String, Object?>{
      'sha256': 'deadbeef',
      'schemaVersion': 1,
    });
    final runner = _FakeRunner.withOrder(order);

    final outcome = await build(runner: runner).restore(conn, name);

    expect(outcome, RestoreOutcome.failedCorrupt);
    expect(runner.calls, 0);
    expect(order, isEmpty);
  });

  test('sidecar 版本超过当前 → failedVersionNewer', () async {
    paths.backups.createSync(recursive: true);
    final f = File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'))
      ..writeAsStringSync('PGDMP-fake');
    File('${f.path}.meta.json').writeAsStringSync(jsonEncode(<String, Object?>{
      'sha256': sha256.convert(f.readAsBytesSync()).toString(),
      'schemaVersion': kAppMigrations.last.version + 1,
    }));

    expect(
      await build().restore(conn, 'inkframe-2026-07-15.dump'),
      RestoreOutcome.failedVersionNewer,
    );
  });

  test('sidecar 损坏（非 JSON）→ failedCorrupt', () async {
    paths.backups.createSync(recursive: true);
    File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'))
        .writeAsStringSync('PGDMP-fake');
    File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump.meta.json'))
        .writeAsStringSync('not-json{');

    expect(
      await build().restore(conn, 'inkframe-2026-07-15.dump'),
      RestoreOutcome.failedCorrupt,
    );
  });

  test('无 sidecar 的存量备份 → 跳过校验直接还原', () async {
    final name = seedBackup(); // 无 meta
    expect(await build().restore(conn, name), RestoreOutcome.restored);
  });

  test('非法名（穿越/杂名）→ failed，零进程零 SQL', () async {
    seedBackup();
    final runner = _FakeRunner.withOrder(order);
    final svc = build(runner: runner);
    expect(await svc.restore(conn, '../evil.dump'), RestoreOutcome.failed);
    expect(await svc.restore(conn, 'other.dump'), RestoreOutcome.failed);
    expect(runner.calls, 0);
    expect(order, isEmpty);
  });

  test('文件不存在 → failed 零调用；无二进制 → failedNoBinaries', () async {
    expect(await build().restore(conn, 'inkframe-2026-01-01.dump'),
        RestoreOutcome.failed);
    final name = seedBackup();
    expect(
      await build(locator: _FakeLocator(binDir, binExists: false))
          .restore(conn, name),
      RestoreOutcome.failedNoBinaries,
    );
  });

  test('自愈：目标库不存在（上次夹缝崩溃）→ 跳过 rename-away 直接换上', () async {
    maint.targetDbExists = false;
    final name = seedBackup(autoMeta: true);

    final outcome = await build().restore(conn, name);

    expect(outcome, RestoreOutcome.restored);
    expect(order.where((s) => s.contains('RENAME TO "inkframe_retired')),
        isEmpty);
    expect(order, contains('ALTER DATABASE "inkframe_restore_tmp" RENAME TO "postgres"'));
    expect(order.where((s) => s.startsWith('DROP DATABASE "inkframe_retired')),
        isEmpty);
  });

  test('rename-away 失败 → drop tmp、failed（原库未动）', () async {
    maint.failOnPrefix = 'ALTER DATABASE "postgres" RENAME';
    final name = seedBackup(autoMeta: true);

    final outcome = await build().restore(conn, name);

    expect(outcome, RestoreOutcome.failed);
    expect(order.last, 'DROP DATABASE IF EXISTS "inkframe_restore_tmp"');
    expect(order.where((s) => s.contains('RENAME TO "postgres"')), isEmpty);
  });

  test('drop retired 失败 → 仍 restored（仅 warn）', () async {
    maint.failOnPrefix = 'DROP DATABASE "inkframe_retired';
    final name = seedBackup(autoMeta: true);
    expect(await build().restore(conn, name), RestoreOutcome.restored);
  });

  test('trust 集群 password=null → 不设 PGPASSWORD', () async {
    const trustConn = BackupConnection(
      host: '127.0.0.1',
      port: 5544,
      username: 'inkframe',
      database: 'postgres',
    );
    final name = seedBackup();
    final runner = _FakeRunner.withOrder(order);
    await build(runner: runner).restore(trustConn, name);
    expect(runner.lastEnv, anyOf(isNull, isEmpty));
  });
}
