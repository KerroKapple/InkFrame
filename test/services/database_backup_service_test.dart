import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/database_backup_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:path/path.dart' as p;

/// 定时 fake clock（UTC）。
class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime nowUtc() => _now;
}

/// 记录调用并按脚本返回；成功时模拟 pg_dump 写出 `-f` 目标文件。
class _FakeRunner implements ProcessRunner {
  _FakeRunner({this.exitCode = 0, this.writesOutput = true});
  int exitCode;
  bool writesOutput;
  int calls = 0;
  String? lastExecutable;
  List<String>? lastArgs;
  Map<String, String>? lastEnv;

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
    // 真实 pg_dump 即便非零退出也常已把截断的 -Fc 头写进 -f 目标——writesOutput
    // 时无论退出码都产出文件，好让「失败清半成品」断言测的是真删除而非空。
    if (writesOutput) {
      final fi = arguments.indexOf('-f');
      if (fi >= 0 && fi + 1 < arguments.length) {
        File(arguments[fi + 1]).writeAsStringSync('PGDMP-fake');
      }
    }
    return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : 'boom');
  }
}

/// 指向给定 bin 目录的 locator；binExists=false 模拟开发机无打包 PG。
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

void main() {
  const conn = BackupConnection(
    host: '127.0.0.1',
    port: 5544,
    username: 'inkframe',
    database: 'postgres',
    password: 'secret-pw',
  );

  group('纯函数', () {
    test('backupFileName → inkframe-YYYY-MM-DD.dump（零填充）', () {
      expect(
        PgDumpBackupService.backupFileName(DateTime.utc(2026, 7, 5)),
        'inkframe-2026-07-05.dump',
      );
      expect(
        PgDumpBackupService.backupFileName(DateTime.utc(2026, 11, 20)),
        'inkframe-2026-11-20.dump',
      );
    });

    test('backupsToPrune 保留最新 7 份、按日期序删最旧、忽略不匹配名', () {
      final names = <String>[
        for (var d = 1; d <= 9; d++)
          'inkframe-2026-07-${d.toString().padLeft(2, '0')}.dump',
        'notes.txt', // 不匹配
        'inkframe-broken.dump', // 无日期段，不匹配
      ];
      final prune = PgDumpBackupService.backupsToPrune(names);
      expect(prune, <String>['inkframe-2026-07-01.dump', 'inkframe-2026-07-02.dump']);
    });

    test('backupsToPrune ≤7 份时不删任何', () {
      final names = <String>[
        for (var d = 1; d <= 5; d++)
          'inkframe-2026-07-0$d.dump',
      ];
      expect(PgDumpBackupService.backupsToPrune(names), isEmpty);
    });
  });

  group('backup 编排', () {
    late Directory tmp;
    late Directory binDir;
    late AppPaths paths;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ink_backup_');
      binDir = Directory(p.join(tmp.path, 'pgbin'))..createSync(recursive: true);
      // 造出 pg_dump 可执行文件占位（existsSync 命中）。
      final exe = Platform.isWindows ? 'pg_dump.exe' : 'pg_dump';
      File(p.join(binDir.path, exe)).writeAsStringSync('x');
      paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'data')));
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    PgDumpBackupService service({
      _FakeRunner? runner,
      _FakeLocator? locator,
      DateTime? now,
    }) =>
        PgDumpBackupService(
          paths: paths,
          locator: locator ?? _FakeLocator(binDir),
          runner: runner ?? _FakeRunner(),
          clock: _FixedClock(now ?? DateTime.utc(2026, 7, 15)),
        );

    test('无当日备份 → 调 pg_dump（-Fc + 连接参数 + PGPASSWORD env）→ created', () async {
      final runner = _FakeRunner();
      final outcome = await service(runner: runner).backup(conn);

      expect(outcome, BackupOutcome.created);
      expect(runner.calls, 1);
      expect(runner.lastExecutable, endsWith(Platform.isWindows ? 'pg_dump.exe' : 'pg_dump'));
      expect(runner.lastArgs, containsAllInOrder(<String>['-Fc', '-f']));
      expect(runner.lastArgs, containsAll(<String>['-h', '127.0.0.1', '-p', '5544', '-U', 'inkframe', '-d', 'postgres']));
      expect(runner.lastEnv, <String, String>{'PGPASSWORD': 'secret-pw'});
      // pg_dump 写 .partial 临时文件（原子写），产物 rename 到当日最终名。
      expect(runner.lastArgs!.last, endsWith('.dump.partial'));
      final f = File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'));
      expect(f.existsSync(), isTrue);
      // 成功后不留 .partial 碎片。
      expect(File('${f.path}.partial').existsSync(), isFalse);
    });

    test('trust 集群（password=null）→ 不设 PGPASSWORD env', () async {
      final runner = _FakeRunner();
      const trustConn = BackupConnection(
        host: '127.0.0.1',
        port: 5544,
        username: 'inkframe',
        database: 'postgres',
      );
      await service(runner: runner).backup(trustConn);
      expect(runner.lastEnv, anyOf(isNull, isEmpty));
    });

    test('当日已有备份 → 跳过，不调 pg_dump', () async {
      paths.backups.createSync(recursive: true);
      File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'))
          .writeAsStringSync('existing');
      final runner = _FakeRunner();

      final outcome = await service(runner: runner).backup(conn);

      expect(outcome, BackupOutcome.skippedAlreadyToday);
      expect(runner.calls, 0);
    });

    test('无打包 PG 二进制（开发机）→ 跳过、不调、不算失败', () async {
      final runner = _FakeRunner();
      final outcome = await service(
        runner: runner,
        locator: _FakeLocator(binDir, binExists: false),
      ).backup(conn);

      expect(outcome, BackupOutcome.skippedNoBinaries);
      expect(runner.calls, 0);
    });

    test('pg_dump 退出码非 0（已写出半成品）→ failed 且清掉 .partial 与最终名', () async {
      final runner = _FakeRunner(exitCode: 1, writesOutput: true);
      final outcome = await service(runner: runner).backup(conn);

      expect(outcome, BackupOutcome.failed);
      final f = File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'));
      // 失败绝不发布：最终名不存在，半成品 .partial 也被清掉（真删除，非空断言）。
      expect(f.existsSync(), isFalse);
      expect(File('${f.path}.partial').existsSync(), isFalse,
          reason: '失败必须清掉半成品 .partial，免占保留位/误判当日已有');
    });

    test('崩溃遗留的同日 .partial 不阻止重试，成功后被清理', () async {
      paths.backups.createSync(recursive: true);
      // 模拟上次同日 pg_dump 中途被 SIGKILL 留下的半成品。
      final leftover =
          File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump.partial'))
            ..writeAsStringSync('truncated');
      final runner = _FakeRunner();

      final outcome = await service(runner: runner).backup(conn);

      expect(outcome, BackupOutcome.created, reason: '最终名不存在，应照常重试而非跳过');
      expect(File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump')).existsSync(),
          isTrue);
      expect(leftover.existsSync(), isFalse, reason: '残留 .partial 应被清理');
    });

    test('成功后应用保留策略：预置 8 份历史 + 今日 → 只留最新 7', () async {
      paths.backups.createSync(recursive: true);
      // 预置 2026-07-06 .. 2026-07-13 共 8 份旧备份。
      for (var d = 6; d <= 13; d++) {
        File(p.join(paths.backups.path,
                'inkframe-2026-07-${d.toString().padLeft(2, '0')}.dump'))
            .writeAsStringSync('old');
      }
      final runner = _FakeRunner();
      final outcome = await service(runner: runner).backup(conn); // 今日=07-15

      expect(outcome, BackupOutcome.created);
      final remaining = paths.backups
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((n) => n.startsWith('inkframe-') && n.endsWith('.dump'))
          .toList()
        ..sort();
      // 9 份候选（8 旧 + 今日）删到 7：最旧的 07-06、07-07 被删。
      expect(remaining.length, 7);
      expect(remaining.contains('inkframe-2026-07-06.dump'), isFalse);
      expect(remaining.contains('inkframe-2026-07-07.dump'), isFalse);
      expect(remaining.contains('inkframe-2026-07-15.dump'), isTrue);
    });
  });

  group('备份族 rev2（LB-22）', () {
    late Directory tmp;
    late Directory binDir;
    late AppPaths paths;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ink_backup22_');
      binDir = Directory(p.join(tmp.path, 'pgbin'))..createSync(recursive: true);
      final exe = Platform.isWindows ? 'pg_dump.exe' : 'pg_dump';
      File(p.join(binDir.path, exe)).writeAsStringSync('x');
      paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'data')));
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    PgDumpBackupService service({
      _FakeRunner? runner,
      _FakeLocator? locator,
      DateTime? now,
    }) =>
        PgDumpBackupService(
          paths: paths,
          locator: locator ?? _FakeLocator(binDir),
          runner: runner ?? _FakeRunner(),
          clock: _FixedClock(now ?? DateTime.utc(2026, 7, 15, 9, 30, 0)),
        );

    test('backupKindOf：三族识别、穿越与杂名拒绝', () {
      expect(backupKindOf('inkframe-2026-07-15.dump'), BackupKind.daily);
      expect(backupKindOf('inkframe-manual-2026-07-15-093000.dump'),
          BackupKind.manual);
      expect(backupKindOf('inkframe-prerestore-2026-07-15-093000.dump'),
          BackupKind.preRestore);
      expect(backupKindOf('../evil.dump'), isNull);
      expect(backupKindOf('inkframe-broken.dump'), isNull);
      expect(backupKindOf('inkframe-2026-07-15.dump.meta.json'), isNull);
    });

    test('backupSortKey：每日视为当天最早，时间戳按时刻排', () {
      expect(
        backupSortKey('inkframe-2026-07-15.dump')
            .compareTo(backupSortKey('inkframe-manual-2026-07-15-000001.dump')),
        lessThan(0),
      );
      expect(
        backupSortKey('inkframe-manual-2026-07-15-093000.dump')
            .compareTo(backupSortKey('inkframe-2026-07-16.dump')),
        lessThan(0),
      );
    });

    test('backupNow(manual)：当日 daily 已存在照做；命名+sidecar（sha256/schemaVersion）',
        () async {
      paths.backups.createSync(recursive: true);
      File(p.join(paths.backups.path, 'inkframe-2026-07-15.dump'))
          .writeAsStringSync('daily');
      final runner = _FakeRunner();

      final result = await service(runner: runner).backupNow(
        conn,
        kind: BackupKind.manual,
      );

      expect(result.outcome, BackupOutcome.created);
      expect(result.fileName, 'inkframe-manual-2026-07-15-093000.dump');
      expect(runner.calls, 1);
      final f = File(p.join(paths.backups.path, result.fileName!));
      expect(f.existsSync(), isTrue);

      final meta = File('${f.path}.meta.json');
      expect(meta.existsSync(), isTrue);
      final parsed =
          jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      expect(parsed['sha256'],
          sha256.convert(f.readAsBytesSync()).toString());
      expect(parsed['schemaVersion'], kAppMigrations.last.version);
      expect(parsed['createdAtUtc'], isA<String>());
    });

    test('backupNow(preRestore)：prerestore 族命名', () async {
      final result = await service().backupNow(
        conn,
        kind: BackupKind.preRestore,
      );
      expect(result.outcome, BackupOutcome.created);
      expect(result.fileName, 'inkframe-prerestore-2026-07-15-093000.dump');
    });

    test('backupNow 失败 → failed、fileName null、半成品清理', () async {
      final runner = _FakeRunner(exitCode: 1, writesOutput: true);
      final result = await service(runner: runner).backupNow(
        conn,
        kind: BackupKind.manual,
      );
      expect(result.outcome, BackupOutcome.failed);
      expect(result.fileName, isNull);
      expect(
        paths.backups
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
    });

    test('backupNow 无二进制 → skippedNoBinaries', () async {
      final result = await service(
        locator: _FakeLocator(binDir, binExists: false),
      ).backupNow(conn, kind: BackupKind.manual);
      expect(result.outcome, BackupOutcome.skippedNoBinaries);
    });

    test('分池剪枝：manual 触发发布后各族按各自 cap 剪，sidecar 连带删', () async {
      paths.backups.createSync(recursive: true);
      // 7 daily（满额不该动）+ 4 manual + 4 prerestore。
      for (var d = 8; d <= 14; d++) {
        File(p.join(paths.backups.path,
                'inkframe-2026-07-${d.toString().padLeft(2, '0')}.dump'))
            .writeAsStringSync('daily');
      }
      for (var i = 1; i <= 4; i++) {
        final m = File(p.join(paths.backups.path,
            'inkframe-manual-2026-07-1$i-090000.dump'))
          ..writeAsStringSync('m');
        File('${m.path}.meta.json').writeAsStringSync('{}');
        File(p.join(paths.backups.path,
                'inkframe-prerestore-2026-07-1$i-090000.dump'))
            .writeAsStringSync('r');
      }

      final result =
          await service().backupNow(conn, kind: BackupKind.manual);
      expect(result.outcome, BackupOutcome.created);

      final names = paths.backups
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toSet();
      // daily 满额 7，一份不少。
      expect(names.where((n) => backupKindOf(n) == BackupKind.daily),
          hasLength(7));
      // manual 4+1 → 3（最旧的 11/12 两份被剪，sidecar 连带删）。
      expect(names.where((n) => backupKindOf(n) == BackupKind.manual),
          hasLength(3));
      expect(names, isNot(contains('inkframe-manual-2026-07-11-090000.dump')));
      expect(names,
          isNot(contains('inkframe-manual-2026-07-11-090000.dump.meta.json')));
      // prerestore 4 → 3。
      expect(names.where((n) => backupKindOf(n) == BackupKind.preRestore),
          hasLength(3));
    });

    test('preserve：兜底备份的剪枝排除正要还原的目标（#189 评审 P1-2）', () async {
      paths.backups.createSync(recursive: true);
      // prerestore 满额 3 份，目标=最旧那份（用户最常想回到的点）。
      for (var i = 1; i <= 3; i++) {
        File(p.join(paths.backups.path,
                'inkframe-prerestore-2026-07-1$i-090000.dump'))
            .writeAsStringSync('r');
      }
      const target = 'inkframe-prerestore-2026-07-11-090000.dump';

      final result = await service().backupNow(
        conn,
        kind: BackupKind.preRestore,
        preserve: target,
      );

      expect(result.outcome, BackupOutcome.created);
      final names = paths.backups
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toSet();
      // 目标必须活着；被保护的那份不计入候选 → 本轮容忍超额（下轮自然回落）。
      expect(names, contains(target));
      expect(names.where((n) => backupKindOf(n) == BackupKind.preRestore),
          hasLength(4));
    });

    test('listBackups：仅识别名、新→旧、kind 正确', () async {
      paths.backups.createSync(recursive: true);
      File(p.join(paths.backups.path, 'inkframe-2026-07-14.dump'))
          .writeAsStringSync('d');
      File(p.join(paths.backups.path,
              'inkframe-manual-2026-07-14-090000.dump'))
          .writeAsStringSync('mm');
      File(p.join(paths.backups.path, 'notes.txt')).writeAsStringSync('x');
      File(p.join(paths.backups.path, 'inkframe-2026-07-14.dump.meta.json'))
          .writeAsStringSync('{}');

      final list = service().listBackups();
      expect(list.map((b) => b.name).toList(), <String>[
        'inkframe-manual-2026-07-14-090000.dump',
        'inkframe-2026-07-14.dump',
      ]);
      expect(list.first.kind, BackupKind.manual);
      expect(list.last.kind, BackupKind.daily);
      expect(list.first.sizeBytes, 2);
    });

    test('daily backup() 也写 sidecar（还原校验对每份备份成立）', () async {
      final outcome = await service().backup(conn);
      expect(outcome, BackupOutcome.created);
      expect(
        File(p.join(
                paths.backups.path, 'inkframe-2026-07-15.dump.meta.json'))
            .existsSync(),
        isTrue,
      );
    });
  });
}
