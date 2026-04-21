// 级联行为集成测（真 PG）：覆盖 Sprint 1 DoD 四组。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

import 'pg_test_harness.dart';

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'cascade');
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

  Future<Map<String, String>> scaffold(PgTestHarness h) async {
    final pid = (await h.conn.execute(
      Sql.named("INSERT INTO projects (name) VALUES ('P') RETURNING id"),
    ))
        .first[0]!
        .toString();
    final cid = (await h.conn.execute(
      Sql.named(
        'INSERT INTO canvases (project_id, name) VALUES (@p, @n) RETURNING id',
      ),
      parameters: {'p': pid, 'n': 'C'},
    ))
        .first[0]!
        .toString();
    return {'pid': pid, 'cid': cid};
  }

  test('删 project → canvases CASCADE', () async {
    try {
      final h = req();
      final ids = await scaffold(h);
      await h.conn.execute(
        Sql.named('DELETE FROM projects WHERE id = @id'),
        parameters: {'id': ids['pid']},
      );
      final canvases = await h.conn.execute(
        Sql.named('SELECT count(*) FROM canvases WHERE id = @c'),
        parameters: {'c': ids['cid']},
      );
      expect(canvases.first[0], 0);
    } on _Skip {
      return;
    }
  });

  test('删 canvas → nodes / edges / style_lanes CASCADE', () async {
    try {
      final h = req();
      final ids = await scaffold(h);
      final cid = ids['cid']!;
      final nodeA = (await h.conn.execute(
        Sql.named(
          "INSERT INTO nodes (canvas_id, type) VALUES (@c, 'image') RETURNING id",
        ),
        parameters: {'c': cid},
      ))
          .first[0]!
          .toString();
      final nodeB = (await h.conn.execute(
        Sql.named(
          "INSERT INTO nodes (canvas_id, type) VALUES (@c, 'image') RETURNING id",
        ),
        parameters: {'c': cid},
      ))
          .first[0]!
          .toString();
      await h.conn.execute(
        Sql.named(
          'INSERT INTO edges (canvas_id, source_node_id, target_node_id, edge_type) '
          "VALUES (@c, @a, @b, 'data')",
        ),
        parameters: {'c': cid, 'a': nodeA, 'b': nodeB},
      );
      await h.conn.execute(
        Sql.named('INSERT INTO style_lanes (canvas_id) VALUES (@c)'),
        parameters: {'c': cid},
      );

      await h.conn.execute(
        Sql.named('DELETE FROM canvases WHERE id = @c'),
        parameters: {'c': cid},
      );

      final nodesLeft = await h.conn.execute(
        Sql.named('SELECT count(*) FROM nodes WHERE canvas_id = @c'),
        parameters: {'c': cid},
      );
      final edgesLeft = await h.conn.execute(
        Sql.named('SELECT count(*) FROM edges WHERE canvas_id = @c'),
        parameters: {'c': cid},
      );
      final lanesLeft = await h.conn.execute(
        Sql.named('SELECT count(*) FROM style_lanes WHERE canvas_id = @c'),
        parameters: {'c': cid},
      );
      expect(nodesLeft.first[0], 0);
      expect(edgesLeft.first[0], 0);
      expect(lanesLeft.first[0], 0);
    } on _Skip {
      return;
    }
  });

  test('删 config node → result.source_node_id SET NULL（§4.5.1 孤儿）',
      () async {
    try {
      final h = req();
      final ids = await scaffold(h);
      final cid = ids['cid']!;
      final config = (await h.conn.execute(
        Sql.named(
          'INSERT INTO nodes (canvas_id, type, node_role) '
          "VALUES (@c, 'image', 'config') RETURNING id",
        ),
        parameters: {'c': cid},
      ))
          .first[0]!
          .toString();
      final result = (await h.conn.execute(
        Sql.named(
          'INSERT INTO nodes (canvas_id, type, node_role, source_node_id) '
          "VALUES (@c, 'image', 'result', @s) RETURNING id",
        ),
        parameters: {'c': cid, 's': config},
      ))
          .first[0]!
          .toString();

      await h.conn.execute(
        Sql.named('DELETE FROM nodes WHERE id = @id'),
        parameters: {'id': config},
      );

      final orphan = await h.conn.execute(
        Sql.named('SELECT source_node_id FROM nodes WHERE id = @id'),
        parameters: {'id': result},
      );
      expect(orphan.first[0], isNull);
    } on _Skip {
      return;
    }
  });

  test('删 result node → batch_results CASCADE', () async {
    try {
      final h = req();
      final ids = await scaffold(h);
      final cid = ids['cid']!;
      final config = (await h.conn.execute(
        Sql.named(
          "INSERT INTO nodes (canvas_id, type, node_role) VALUES (@c, 'image', 'config') RETURNING id",
        ),
        parameters: {'c': cid},
      ))
          .first[0]!
          .toString();
      final resultNode = (await h.conn.execute(
        Sql.named(
          'INSERT INTO nodes (canvas_id, type, node_role, source_node_id) '
          "VALUES (@c, 'image', 'result', @s) RETURNING id",
        ),
        parameters: {'c': cid, 's': config},
      ))
          .first[0]!
          .toString();
      final job = (await h.conn.execute(
        Sql.named(
          'INSERT INTO jobs (canvas_id, source_node_id, provider_id, job_type, full_prompt, user_prompt) '
          "VALUES (@c, @s, 'kling', 'image', 'fp', 'up') RETURNING id",
        ),
        parameters: {'c': cid, 's': config},
      ))
          .first[0]!
          .toString();
      await h.conn.execute(
        Sql.named(
          'INSERT INTO batch_results (node_id, job_id, slot_index, status) '
          "VALUES (@n, @j, 0, 'success')",
        ),
        parameters: {'n': resultNode, 'j': job},
      );

      // schema v=2（TD-001 修复）：jobs.result_node_id ON DELETE SET NULL。
      // 删 result node 直接通过 —— batch_results CASCADE；保留的 jobs 行 result_node_id 置 NULL。
      await h.conn.execute(
        Sql.named('DELETE FROM nodes WHERE id = @id'),
        parameters: {'id': resultNode},
      );

      final leftResults = await h.conn.execute(
        Sql.named('SELECT count(*) FROM batch_results WHERE node_id = @n'),
        parameters: {'n': resultNode},
      );
      expect(leftResults.first[0], 0, reason: 'batch_results 应 CASCADE 清空');

      final jobRow = await h.conn.execute(
        Sql.named('SELECT result_node_id FROM jobs WHERE id = @j'),
        parameters: {'j': job},
      );
      expect(jobRow.first[0], isNull,
          reason: 'jobs.result_node_id 应被 SET NULL，job 审计行保留');
    } on _Skip {
      return;
    }
  });
}

class _Skip implements Exception {}
