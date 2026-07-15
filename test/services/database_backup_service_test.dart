import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/database_backup_service.dart';
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
}
