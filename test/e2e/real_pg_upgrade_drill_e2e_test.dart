// QG-4 真栈升级演练:同一数据目录,「旧版应用」(截断链 v6)写数据关库 →
// 「新版应用」(全链)冷启 → 前向迁移自动执行,数据存活。
// 这是对真实用户升级路径(装新版打开旧工作区)的最忠实自动化模拟。
// 门控同 real_pg_stack_e2e_test.dart:TEST_REAL_PG=1 + INKFRAME_PG_BIN。
@Tags(['realpg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../_harness/fake_secure_storage.dart';

void main() {
  test('QG-4 真栈:旧版(v6)写入 → 关库 → 新版全链冷启 → 数据存活', () async {
    // 双门控理由同 real_pg_stack_e2e_test.dart。
    if (Platform.environment['TEST_REAL_PG'] != '1') {
      markTestSkipped('TEST_REAL_PG!=1,跳过真二进制 E2E');
      return;
    }
    final binDir = Platform.environment['INKFRAME_PG_BIN'];
    if (binDir == null || binDir.isEmpty) {
      markTestSkipped('INKFRAME_PG_BIN 未设置,跳过真二进制 E2E');
      return;
    }

    final tmp = Directory.systemTemp.createTempSync('ink_qg4_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
    await paths.ensureInitialized();
    final secure = FakeSecureStorage(); // 跨两阶段同实例:密码延续
    final locator =
        DefaultPgBinaryLocator(environment: {'INKFRAME_PG_BIN': binDir});

    Pool<void> openPool(PgRuntime rt) => Pool<void>.withEndpoints(
          [
            Endpoint(
              host: rt.host,
              port: rt.port,
              database: kPgDatabaseName,
              username: kPgSuperuser,
              password: rt.password,
            ),
          ],
          settings: const PoolSettings(
            sslMode: SslMode.disable,
            maxConnectionCount: 2,
          ),
        );

    // ── 阶段 1:「旧版应用」——截断链到 v6,写真数据,正常关库 ──
    const oldLen = 6;
    final oldApp =
        PgController(paths: paths, locator: locator, secureStorage: secure);
    final rt1 = await oldApp.start();
    final pool1 = openPool(rt1);
    await DatabaseBootstrap(
      pool1,
      migrations: kAppMigrations.sublist(0, oldLen),
    ).run();
    final v1 =
        await pool1.execute('SELECT version FROM schema_version WHERE id = 1');
    expect(v1.first[0], oldLen, reason: '旧版链未停在 v$oldLen');
    final pid = await PostgresProjectRepository(pool1).create(name: 'QG4-OLD');
    await pool1.close();
    await oldApp.stop();

    // ── 阶段 2:「新版应用」——同一数据目录,全链 bootstrap 冷启 ──
    final newApp =
        PgController(paths: paths, locator: locator, secureStorage: secure);
    final rt2 = await newApp.start();
    final pool2 = openPool(rt2);
    addTearDown(() async {
      await pool2.close();
      await newApp.stop();
    });
    await DatabaseBootstrap(pool2).run(); // 生产同路径:kAppMigrations 全链

    final v2 =
        await pool2.execute('SELECT version FROM schema_version WHERE id = 1');
    expect(v2.first[0], kAppMigrations.length, reason: '前向迁移未到最新版');
    // 旧版数据存活。
    final survived = await PostgresProjectRepository(pool2).findById(pid);
    expect(survived, isNotNull, reason: '升级后旧数据丢失');
    expect(survived!['name'], 'QG4-OLD');
    // 新版新增表可用(v7 prompt_presets)。
    final presets =
        await pool2.execute('SELECT count(*) FROM prompt_presets');
    expect(presets.first[0], 0);
  }, tags: const ['realpg'], timeout: const Timeout(Duration(minutes: 3)));
}
