// MigrationRunner 真 PG 集成测：验证 simple 协议多语句 DDL 能一次跑完 schema_v1，
// 并正确 UPSERT schema_version。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:inkframe/storage/schema/schema_v1.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('MigrationRunner.migrate 在真 PG 下顺畅执行 v=1', () async {
    final url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置');
      return;
    }
    final conn = await Connection.openFromUrl(url);
    final schema = 'mig_run_${DateTime.now().microsecondsSinceEpoch}';
    try {
      try {
        await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
      } on ServerException catch (e) {
        if (e.code != '23505') rethrow;
      }
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');
      final runner = MigrationRunner(
        conn,
        migrations: const [Migration(version: 1, sql: kSchemaV1)],
      );
      await runner.migrate();
      // v=1 已写入
      final v = await conn.execute(
        'SELECT version FROM schema_version WHERE id = 1',
      );
      expect(v.first[0], 1);
      // 冗余执行：应 no-op（当前版本 == target）
      await runner.migrate();
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  }, tags: const ['pg']);
}
