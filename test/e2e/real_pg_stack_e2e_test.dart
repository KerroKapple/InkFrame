// 真二进制全栈 E2E（验收资产）：真 initdb(SCRAM) → 真 pg_ctl → 真迁移链 →
// 真 pg_dump 冷备 → 真 pg_restore scratch 对换 → 真 teardown。
//
// 门控：需 INKFRAME_PG_BIN 指向 Windows/macOS 真 PG bin（开发机跑
// `TEST_REAL_PG=1 INKFRAME_PG_BIN=<bin> flutter test --tags realpg`）；
// CI/无二进制环境自动跳过。全程使用生产代码路径（SystemPgProcessRunner /
// SystemProcessRunner / 真仓储），仅 SecureStorage 用内存 fake（不污染系统凭据）。
@Tags(['realpg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/interfaces/database_restore_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/database_backup_service.dart';
import 'package:inkframe/services/database_restore_service.dart';
import 'package:inkframe/services/system_process_runner.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../_harness/fake_secure_storage.dart';

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime nowUtc() => _now;
}

void main() {
  test('真栈冷启→备份→还原→teardown 全链', () async {
    // 双门控：TEST_REAL_PG 显式开关——避免开发机常驻导出 INKFRAME_PG_BIN
    // （生产查找路径）时 pre-push 全量测被动跑 5 分钟真栈（同 ffmpeg tag 先例）。
    if (Platform.environment['TEST_REAL_PG'] != '1') {
      markTestSkipped('TEST_REAL_PG!=1，跳过真二进制 E2E');
      return;
    }
    final binDir = Platform.environment['INKFRAME_PG_BIN'];
    if (binDir == null || binDir.isEmpty) {
      markTestSkipped('INKFRAME_PG_BIN 未设置，跳过真二进制 E2E');
      return;
    }

    final tmp = Directory.systemTemp.createTempSync('ink_real_e2e_');
    final paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
    await paths.ensureInitialized();
    final secure = FakeSecureStorage();
    final locator = DefaultPgBinaryLocator(
      environment: {'INKFRAME_PG_BIN': binDir},
    );
    final controller = PgController(
      paths: paths,
      locator: locator,
      secureStorage: secure,
    );

    addTearDown(() async {
      try {
        await controller.stop();
      } on PgLifecycleError {
        // stop 失败兜底：按 postmaster.pid 强杀，防泄漏活体库进程。
        final pidFile = File(p.join(paths.database.path, 'postmaster.pid'));
        if (pidFile.existsSync()) {
          final pid = int.tryParse(pidFile.readAsLinesSync().first.trim());
          if (pid != null) {
            Platform.isWindows
                ? Process.runSync('taskkill', ['/PID', '$pid', '/F'])
                : Process.runSync('kill', ['-9', '$pid']);
          }
        }
      }
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows 句柄延迟释放，不影响断言。
      }
    });

    // 阶段标记（门控 E2E，print 供挂起定位）。
    // ignore: avoid_print
    void stage(String s) => print('[e2e] $s');

    // ── 1) 真 initdb（LB-07 SCRAM）+ 真启动 ──
    stage('initdb');
    await controller.ensureInitialized();
    final hba = File(p.join(paths.database.path, 'pg_hba.conf'))
        .readAsStringSync();
    expect(hba.contains('scram-sha-256'), isTrue, reason: 'SCRAM 未启用');
    expect(
      hba.split('\n').where((l) =>
          l.trim().isNotEmpty &&
          !l.trimLeft().startsWith('#') &&
          l.contains(RegExp(r'\btrust\b'))),
      isEmpty,
      reason: 'pg_hba 残留 trust 行',
    );
    // 密码已入（fake）SecureStorage 且 pwfile 不残留。
    final pw = await secure.retrieve(SecureStorageKeys.databasePassword);
    expect(pw, isNotNull);
    expect(
      paths.database.parent
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains('pwfile')),
      isEmpty,
    );

    stage('pg_ctl start');
    final runtime = await controller.start();
    expect(runtime.password, pw);

    // ── 2) 真迁移链（LB-08）──
    final pool = Pool<void>.withEndpoints(
      [
        Endpoint(
          host: runtime.host,
          port: runtime.port,
          database: kPgDatabaseName,
          username: kPgSuperuser,
          password: runtime.password,
        ),
      ],
      settings: const PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: 2,
      ),
    );
    addTearDown(pool.close);
    stage('bootstrap');
    await DatabaseBootstrap(pool).run();
    final ver = await pool
        .execute('SELECT version FROM schema_version ORDER BY version DESC');
    expect(ver.first.first, 7, reason: '迁移链未到 v7');

    // 种一行真数据（还原语义锚点）。
    final projects = PostgresProjectRepository(pool);
    final pid = await projects.create(name: 'REAL-E2E');
    expect(await projects.findById(pid), isNotNull);

    // ── 3) 真 pg_dump 冷备（LB-10——真二进制首跑）──
    final conn = BackupConnection(
      host: runtime.host,
      port: runtime.port,
      username: kPgSuperuser,
      database: kPgDatabaseName,
      password: runtime.password,
    );
    final backup = PgDumpBackupService(
      paths: paths,
      locator: locator,
      starter: const SystemProcessRunner(),
      clock: _FixedClock(DateTime.utc(2026, 7, 17, 9)),
    );
    stage('pg_dump');
    final outcome = await backup.backup(conn);
    expect(outcome, BackupOutcome.created, reason: '真 pg_dump 失败');
    final dumpFile = File(
        p.join(paths.backups.path, 'inkframe-2026-07-17.dump'));
    expect(dumpFile.existsSync(), isTrue);
    expect(dumpFile.lengthSync(), greaterThan(1000)); // 真 -Fc 头+目录。
    expect(
        File('${dumpFile.path}$kBackupMetaSuffix').existsSync(), isTrue);

    // ── 4) 备份后改数据 → 真 pg_restore scratch 对换（LB-22）→ 数据回退 ──
    final pid2 = await projects.create(name: 'AFTER-BACKUP');
    await pool.close(); // 静默池（flow 语义）。

    final restore = PgSwapRestoreService(
      paths: paths,
      locator: locator,
      starter: const SystemProcessRunner(),
      clock: _FixedClock(DateTime.utc(2026, 7, 17, 10)),
    );
    final restored =
        await restore.restore(conn, 'inkframe-2026-07-17.dump');
    expect(restored, RestoreOutcome.restored, reason: '真 pg_restore 对换失败');

    final pool2 = Pool<void>.withEndpoints(
      [
        Endpoint(
          host: runtime.host,
          port: runtime.port,
          database: kPgDatabaseName,
          username: kPgSuperuser,
          password: runtime.password,
        ),
      ],
      settings: const PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: 2,
      ),
    );
    addTearDown(pool2.close);
    final projects2 = PostgresProjectRepository(pool2);
    expect(await projects2.findById(pid), isNotNull,
        reason: '还原后备份内数据应在');
    expect(await projects2.findById(pid2), isNull,
        reason: '备份后新增的数据应随对换消失');
    // retired 库已被 drop（对换收尾）。
    // `\_` 转义 LIKE 通配符：只匹配字面下划线前缀（tmp/retired 族）。
    final leftovers = await pool2.execute(
        r"SELECT datname FROM pg_database WHERE datname LIKE 'inkframe\_%'");
    expect(leftovers, isEmpty, reason: 'retired/tmp 库残留: $leftovers');

    // ── 5) 真 teardown ──
    await pool2.close();
    await controller.stop();
    expect(controller.runtime, isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
