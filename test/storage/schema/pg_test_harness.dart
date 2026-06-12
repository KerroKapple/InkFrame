// PG 集成测试通用 harness：
//   1) 读 TEST_PG_URL（缺失时 skip 整个测试文件）
//   2) 每用例开独立 schema，经 MigrationRunner 跑完整迁移链（kAppMigrations）
//   3) 用例结束 DROP SCHEMA CASCADE
//
// 目的：在 CI / 本地 brew PG 上跑真实 SQL 断言（与生产同一迁移路径），不互相污染。
// 注意：必须与生产 DI 用同一份 kAppMigrations，schema 断言才反映真实库形态。
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/postgres.dart';

class PgTestHarness {
  PgTestHarness._(this.conn, this.schema);

  final Connection conn;
  final String schema;

  static Future<PgTestHarness?> openFromEnv(
    Map<String, String> env,
    String schemaLabel,
  ) async {
    final url = env['TEST_PG_URL'];
    if (url == null || url.isEmpty) return null;
    final conn = await Connection.openFromUrl(url);
    // 先保证 pgcrypto 扩展存在（schema 共享 db 级扩展，容忍并发）。
    try {
      await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    } on ServerException catch (e) {
      // 23505 duplicate_object（并发竞争）可忽略；其他错误重抛。
      if (e.code != '23505') rethrow;
    }
    final schema = 'test_${schemaLabel}_${DateTime.now().microsecondsSinceEpoch}'
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    await conn.execute('CREATE SCHEMA "$schema"');
    await conn.execute('SET search_path TO "$schema"');
    // 与生产 DI 同路径：MigrationRunner 在事务内逐版本执行 + UPSERT schema_version。
    await MigrationRunner(conn, migrations: kAppMigrations).migrate();
    return PgTestHarness._(conn, schema);
  }

  Future<void> close() async {
    try {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
    } finally {
      await conn.close();
    }
  }
}
