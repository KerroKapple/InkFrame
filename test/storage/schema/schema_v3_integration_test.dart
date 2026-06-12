// Schema v=3 真 PG 集成测：HI-10 / LO-14 / 死 retry 列 / ME-31 迁移事务原子性。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/postgres.dart';

import 'pg_test_harness.dart';

void main() {
  PgTestHarness? harness;

  PgTestHarness req() {
    final h = harness;
    if (h == null) {
      markTestSkipped('TEST_PG_URL 未设置');
      throw const _Skipped();
    }
    return h;
  }

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'v3');
  });

  tearDown(() async {
    await harness?.close();
    harness = null;
  });

  Future<({String canvasId, String src, String tgt})> seedNodes(
    Connection conn,
  ) async {
    final pid = (await conn.execute(
      "INSERT INTO projects (name) VALUES ('P') RETURNING id",
    ))
        .first[0]
        .toString();
    final cid = (await conn.execute(
      Sql.named(
        "INSERT INTO canvases (project_id, name) VALUES (@p, 'C') RETURNING id",
      ),
      parameters: {'p': pid},
    ))
        .first[0]
        .toString();
    Future<String> node() async => (await conn.execute(
          Sql.named(
            "INSERT INTO nodes (canvas_id, type) VALUES (@c, 'image') RETURNING id",
          ),
          parameters: {'c': cid},
        ))
            .first[0]
            .toString();
    return (canvasId: cid, src: await node(), tgt: await node());
  }

  test('HI-10：软删后重连同一 (src,tgt,type) 不再 23505', () async {
    try {
      final h = req();
      final s = await seedNodes(h.conn);
      final e1 = (await h.conn.execute(
        Sql.named(
          'INSERT INTO edges (canvas_id, source_node_id, target_node_id, edge_type) '
          "VALUES (@c, @s, @t, 'data') RETURNING id",
        ),
        parameters: {'c': s.canvasId, 's': s.src, 't': s.tgt},
      ))
          .first[0]
          .toString();
      await h.conn.execute(
        Sql.named('UPDATE edges SET deleted_at = now() WHERE id = @id'),
        parameters: {'id': e1},
      );
      // 重连：软删行不占唯一槽位 → 必须成功
      await h.conn.execute(
        Sql.named(
          'INSERT INTO edges (canvas_id, source_node_id, target_node_id, edge_type) '
          "VALUES (@c, @s, @t, 'data')",
        ),
        parameters: {'c': s.canvasId, 's': s.src, 't': s.tgt},
      );
      // 活行重复仍然拒绝
      await expectLater(
        h.conn.execute(
          Sql.named(
            'INSERT INTO edges (canvas_id, source_node_id, target_node_id, edge_type) '
            "VALUES (@c, @s, @t, 'data')",
          ),
          parameters: {'c': s.canvasId, 's': s.src, 't': s.tgt},
        ),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', '23505'),
        ),
      );
    } on _Skipped {
      return;
    }
  }, tags: const ['pg']);

  test('LO-14：cover_node_id 有 FK，节点硬删 → SET NULL；悬空引用拒绝', () async {
    try {
      final h = req();
      final s = await seedNodes(h.conn);
      final pid = (await h.conn.execute('SELECT id FROM projects LIMIT 1'))
          .first[0]
          .toString();
      await h.conn.execute(
        Sql.named('UPDATE projects SET cover_node_id = @n WHERE id = @p'),
        parameters: {'n': s.src, 'p': pid},
      );
      await h.conn.execute(
        Sql.named('DELETE FROM nodes WHERE id = @n'),
        parameters: {'n': s.src},
      );
      final cover = (await h.conn.execute(
        Sql.named('SELECT cover_node_id FROM projects WHERE id = @p'),
        parameters: {'p': pid},
      ))
          .first[0];
      expect(cover, isNull);
      // 悬空 UUID → 23503
      await expectLater(
        h.conn.execute(
          Sql.named(
            'UPDATE projects SET cover_node_id = gen_random_uuid() WHERE id = @p',
          ),
          parameters: {'p': pid},
        ),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', '23503'),
        ),
      );
    } on _Skipped {
      return;
    }
  }, tags: const ['pg']);

  test('死列处置：jobs 表不再有 retry_count / max_retries', () async {
    try {
      final h = req();
      final cols = await h.conn.execute(
        'SELECT column_name FROM information_schema.columns '
        "WHERE table_schema = current_schema() AND table_name = 'jobs'",
      );
      final names = cols.map((r) => r[0].toString()).toSet();
      expect(names, isNot(contains('retry_count')));
      expect(names, isNot(contains('max_retries')));
    } on _Skipped {
      return;
    }
  }, tags: const ['pg']);

  test('ME-31：失败迁移整体回滚——版本号与半截 DDL 都不落库', () async {
    try {
      final h = req();
      // v4 故意失败：先建表再撞语法错误；事务内两者都应回滚
      final broken = MigrationRunner(
        h.conn,
        migrations: [
          ...kAllMigrations,
          const Migration(
            version: 4,
            sql: 'CREATE TABLE half_done (id INT); SELECT broken(',
          ),
        ],
      );
      await expectLater(broken.migrate(), throwsA(isA<ServerException>()));
      final v = await h.conn.execute(
        'SELECT version FROM schema_version WHERE id = 1',
      );
      expect(v.first[0], 3, reason: '失败迁移不得推进版本号');
      final half = await h.conn.execute(
        'SELECT 1 FROM information_schema.tables '
        "WHERE table_schema = current_schema() AND table_name = 'half_done'",
      );
      expect(half, isEmpty, reason: '半截 DDL 必须随事务回滚');
    } on _Skipped {
      return;
    }
  }, tags: const ['pg']);
}

class _Skipped implements Exception {
  const _Skipped();
}
