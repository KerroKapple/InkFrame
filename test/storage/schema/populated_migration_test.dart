// QG-4 CI 侧:populated-DB 迁移测试。
// 从 v1 起逐版本迁移,版本引入表时立即种子——保证 v2..vN 每条 ALTER 都在
// 有数据的表上执行(空表迁移暴露不了数据问题)。链跑完后:
//   1) 种子数据完整性逐表断言(含 v3 悬空 cover 预清理的正反例);
//   2) 全表非空守卫(information_schema 动态枚举)——未来 schema PR 新增表
//      不补种子即红,固化 ADR-0012「每个 schema PR」纪律;
//   3) 截断链打开新库 → SchemaDowngradeError(真 PG 版降级拒绝)。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('QG-4:v1 起边迁边种,全链数据零丢失 + 全表非空 + 降级拒绝', () async {
    final url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置');
      return;
    }
    final conn = await Connection.openFromUrl(url);
    final schema = 'qg4_${DateTime.now().microsecondsSinceEpoch}';
    try {
      try {
        await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
      } on ServerException catch (e) {
        if (e.code != '23505') rethrow;
      }
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');

      // ── 逐版本迁移 + 版本引入表时种子 ──────────────────────────────
      // 循环上界取 kAppMigrations.length:v8 合入后自动纳入本测试。
      final seeders = <int, Future<void> Function()>{
        1: () => _seedV1(conn),
        6: () => _seedV6(conn),
        7: () => _seedV7(conn),
      };
      for (var k = 1; k <= kAppMigrations.length; k++) {
        await MigrationRunner(
          conn,
          migrations: kAppMigrations.sublist(0, k),
        ).migrate();
        await seeders[k]?.call();
      }

      // ── 1) 种子数据完整性 ─────────────────────────────────────────
      final ver = await conn
          .execute('SELECT version FROM schema_version WHERE id = 1');
      expect(ver.first[0], kAppMigrations.length);

      Future<int> count(String sql) async =>
          (await conn.execute(sql)).first[0]! as int;

      expect(await count('SELECT count(*) FROM projects'), 2);
      expect(await count('SELECT count(*) FROM canvases'), 2);
      expect(await count('SELECT count(*) FROM style_lanes'), 1);
      expect(await count('SELECT count(*) FROM nodes'), 2); // node3 已硬删
      expect(await count('SELECT count(*) FROM edges'), 2);
      expect(await count('SELECT count(*) FROM jobs'), 1);
      expect(await count('SELECT count(*) FROM batch_results'), 2);
      expect(await count('SELECT count(*) FROM characters'), 1);
      expect(await count('SELECT count(*) FROM prompt_presets'), 1);

      // v3 悬空 cover 预清理:坏引用置 NULL,好引用原样保留。
      expect(
        await count('SELECT count(*) FROM projects '
            "WHERE name = 'p-dangling' AND cover_node_id IS NULL"),
        1,
        reason: 'v3 未清理悬空 cover_node_id',
      );
      expect(
        await count('SELECT count(*) FROM projects '
            "WHERE name = 'p-main' AND cover_node_id IS NOT NULL"),
        1,
        reason: 'v3 误清有效 cover_node_id',
      );
      // JSONB 载荷原样存活(迁移不碰内容)。
      expect(
        await count('SELECT count(*) FROM nodes '
            "WHERE type_config->>'image_url' = 'canvases/c1/img.png'"),
        1,
      );
      expect(
        await count('SELECT count(*) FROM jobs '
            "WHERE parameters->>'aspect_ratio' = '16:9'"),
        1,
      );
      // 软删边仍是软删态(v3 重建唯一索引不碰行)。
      expect(
        await count('SELECT count(*) FROM edges '
            'WHERE deleted_at IS NOT NULL'),
        1,
      );
      // v3/v4 死列确已不在(迁移真的执行了,不是被跳过)。
      expect(
        await count('SELECT count(*) FROM information_schema.columns '
            'WHERE table_schema = current_schema() '
            "AND table_name = 'jobs' "
            "AND column_name IN ('retry_count','max_retries','next_poll_at')"),
        0,
      );

      // ── 2) 全表非空守卫(未来 schema PR 不补种子即红)──────────────
      final tables = await conn.execute(
        'SELECT table_name FROM information_schema.tables '
        "WHERE table_schema = current_schema() AND table_type = 'BASE TABLE'",
      );
      for (final row in tables) {
        final t = row[0]! as String;
        expect(
          await count('SELECT count(*) FROM "$t"'),
          greaterThan(0),
          reason: '表 $t 无种子数据——新增表必须在本测试补 seeder(QG-4 守卫)',
        );
      }

      // ── 3) 降级拒绝(真 PG 版)─────────────────────────────────────
      await expectLater(
        MigrationRunner(
          conn,
          migrations: kAppMigrations.sublist(0, kAppMigrations.length - 1),
        ).migrate,
        throwsA(isA<SchemaDowngradeError>()),
      );
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  }, tags: const ['pg']);
}

/// v1 形态种子:覆盖 v1 全部业务表,用当时存在的列(后被删的列走默认值)。
Future<void> _seedV1(Connection conn) async {
  await conn.execute(queryMode: QueryMode.simple, '''
    INSERT INTO projects (id, name) VALUES
      ('00000000-0000-4000-8000-000000000001', 'p-main'),
      ('00000000-0000-4000-8000-000000000002', 'p-dangling');
    INSERT INTO canvases (id, project_id, name, base_style_prefix) VALUES
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-000000000001', 'c1', 'cinematic'),
      ('00000000-0000-4000-8000-0000000000c2',
       '00000000-0000-4000-8000-000000000002', 'c2', '');
    INSERT INTO style_lanes (id, canvas_id, label, style_prompt) VALUES
      ('00000000-0000-4000-8000-0000000000a1',
       '00000000-0000-4000-8000-0000000000c1', 'lane', 'noir');
    INSERT INTO nodes (id, canvas_id, type, node_role, status,
                       lane_id, type_config) VALUES
      ('00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000c1', 'image', 'config', 'idle',
       '00000000-0000-4000-8000-0000000000a1',
       '{"prompt":"a cat"}'::jsonb),
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000c1', 'image', 'result', 'success',
       NULL, '{"image_url":"canvases/c1/img.png"}'::jsonb);
    UPDATE nodes SET source_node_id = '00000000-0000-4000-8000-0000000000d1'
      WHERE id = '00000000-0000-4000-8000-0000000000d2';
    -- 有效 cover(断言 v3 保留)
    UPDATE projects SET cover_node_id = '00000000-0000-4000-8000-0000000000d2'
      WHERE id = '00000000-0000-4000-8000-000000000001';
    -- 悬空 cover 夹具:node3 设为 cover 后硬删(v1 无 FK,悬空得以存在;
    -- 断言 v3 预清理置 NULL)
    INSERT INTO nodes (id, canvas_id, type) VALUES
      ('00000000-0000-4000-8000-0000000000d3',
       '00000000-0000-4000-8000-0000000000c2', 'image');
    UPDATE projects SET cover_node_id = '00000000-0000-4000-8000-0000000000d3'
      WHERE id = '00000000-0000-4000-8000-000000000002';
    DELETE FROM nodes WHERE id = '00000000-0000-4000-8000-0000000000d3';
    -- 活边 + 软删边(不同 edge_type,满足 v1 全量 UNIQUE)
    INSERT INTO edges (canvas_id, source_node_id, target_node_id,
                       edge_type, deleted_at) VALUES
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2', 'data', NULL),
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2', 'narrative', now());
    INSERT INTO jobs (id, canvas_id, source_node_id, result_node_id,
                      provider_id, job_type, status,
                      full_prompt, user_prompt, parameters) VALUES
      ('00000000-0000-4000-8000-0000000000b1',
       '00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2',
       'gemini', 'image', 'success',
       'cinematic, a cat', 'a cat',
       '{"aspect_ratio":"16:9","seed":42}'::jsonb);
    INSERT INTO batch_results (node_id, job_id, slot_index, status,
                               output_url, promoted) VALUES
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000b1', 0, 'success',
       'canvases/c1/slot0.png', true),
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000b1', 1, 'error', NULL, false);
  ''');
}

/// v6 引入 characters。
Future<void> _seedV6(Connection conn) async {
  await conn.execute(queryMode: QueryMode.simple, '''
    INSERT INTO characters (project_id, name, reference_image_paths) VALUES
      ('00000000-0000-4000-8000-000000000001', 'hero',
       '["characters/hero/ref1.png"]'::jsonb);
  ''');
}

/// v7 引入 prompt_presets。
Future<void> _seedV7(Connection conn) async {
  await conn.execute(queryMode: QueryMode.simple, '''
    INSERT INTO prompt_presets (project_id, name, prompt, prefix) VALUES
      ('00000000-0000-4000-8000-000000000001', 'noir', 'moody', 'cinematic');
  ''');
}
