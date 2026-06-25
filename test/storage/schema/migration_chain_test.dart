// harness 迁移全链验证（真 PG）：
//   - schema_version 必须等于 kAppMigrations 目标版本（防 harness 只装 v1 的假绿）
//   - v2 效果落地：jobs.result_node_id FK 为 ON DELETE SET NULL（confdeltype = 'n'）
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:postgres/postgres.dart';

import 'pg_test_harness.dart';

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'chain');
  });

  tearDown(() async {
    await harness?.close();
  });

  PgTestHarness req() {
    final x = harness;
    if (x == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      throw _Skip();
    }
    return x;
  }

  test('harness schema_version == kAppMigrations 目标版本', () async {
    try {
      final h = req();
      final r = await h.conn.execute(
        'SELECT version FROM schema_version WHERE id = 1',
      );
      expect(r.first[0], kAppMigrations.last.version,
          reason: 'harness 必须跑完整迁移链，不允许停在 v1');
    } on _Skip {
      return;
    }
  });

  test('v2 生效：jobs.result_node_id FK 为 ON DELETE SET NULL', () async {
    try {
      final h = req();
      final r = await h.conn.execute(
        Sql.named(
          'SELECT confdeltype::text FROM pg_constraint '
          "WHERE conname = 'jobs_result_node_id_fkey' "
          'AND connamespace = @s::regnamespace',
        ),
        parameters: {'s': h.schema},
      );
      expect(r, hasLength(1));
      expect(r.first[0], 'n', reason: "confdeltype 'n' = SET NULL");
    } on _Skip {
      return;
    }
  });

  test('v5 生效：复合 idx_jobs_canvas_created 存在且单列 idx_jobs_canvas_id 已删',
      () async {
    try {
      final h = req();
      final r = await h.conn.execute(
        Sql.named(
          'SELECT indexname FROM pg_indexes '
          "WHERE tablename = 'jobs' AND schemaname = @s",
        ),
        parameters: {'s': h.schema},
      );
      final names = r.map((row) => row[0]! as String).toSet();
      expect(names, contains('idx_jobs_canvas_created'),
          reason: 'v5 应建复合 (canvas_id, created_at DESC) 索引');
      expect(names, isNot(contains('idx_jobs_canvas_id')),
          reason: 'v5 应删冗余单列索引（复合最左前缀已覆盖）');
    } on _Skip {
      return;
    }
  });
}

class _Skip implements Exception {}
