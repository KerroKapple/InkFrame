// DatabaseBootstrap 真 PG 集成测（防御纵深；翻译/吞并分支已在单测用
// buildExceptionFromErrorFields 覆盖，这里对真库端到端复核）：
//   1) 幂等——连跑两次不报错，schema_version 稳定在目标版本；
//   2) 真 DDL 语法错误产生的真 ServerException 在储层边界翻成 DatabaseBootstrapError。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('run() 幂等：连跑两次，schema_version 稳定在目标版本', () async {
    final url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置');
      return;
    }
    final conn = await Connection.openFromUrl(url);
    // 与 harness 同路径：先在 public 保证 pgcrypto（DB 级，容忍并发）。
    try {
      await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    } on ServerException catch (e) {
      if (e.code != '23505') rethrow;
    }
    final schema = 'boot_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');
      final target = kAppMigrations.last.version;

      await DatabaseBootstrap(conn).run();
      var v =
          await conn.execute('SELECT version FROM schema_version WHERE id = 1');
      expect(v.first[0], target);

      // 第二次 run：幂等——不报错、版本不变、不重跑迁移。
      await DatabaseBootstrap(conn).run();
      v = await conn.execute('SELECT version FROM schema_version WHERE id = 1');
      expect(v.first[0], target);
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  }, tags: const ['pg']);

  test('迁移 DDL 的 ServerException 在边界翻成 DatabaseBootstrapError', () async {
    final url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置');
      return;
    }
    final conn = await Connection.openFromUrl(url);
    try {
      await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    } on ServerException catch (e) {
      if (e.code != '23505') rethrow;
    }
    final schema = 'boot_bad_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');

      // 故意的语法错误 DDL → 真 ServerException(42601) → 应被翻成 DatabaseBootstrapError。
      await expectLater(
        DatabaseBootstrap(
          conn,
          migrations: const [
            Migration(version: 1, sql: 'CREATE TABLE oops (id int NOT VALID)'),
          ],
        ).run(),
        throwsA(isA<DatabaseBootstrapError>()),
      );
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  }, tags: const ['pg']);
}
