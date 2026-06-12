// 7 个 Postgres repository 的真 PG 冒烟测：完整走 CRUD + 软删 + 恢复链路。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';

import '../schema/pg_test_harness.dart';

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'repos');
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

  test('ProjectRepository 全链路 CRUD + 软删 / 恢复 / 硬删', () async {
    try {
      final h = req();
      final repo = PostgresProjectRepository(h.conn);
      final id = await repo.create(name: 'Alpha');
      final loaded = await repo.findById(id);
      expect(loaded?['name'], 'Alpha');
      expect(await repo.listAll(), hasLength(1));

      await repo.update(id, {'name': 'Beta'});
      expect((await repo.findById(id))?['name'], 'Beta');

      expect(await repo.softDelete(id), 1);
      expect(await repo.findById(id), isNull);
      expect(await repo.listAll(), isEmpty);
      expect(await repo.listTrashed(), hasLength(1));

      expect(await repo.restore(id), 1);
      expect((await repo.findById(id))?['name'], 'Beta');

      expect(await repo.hardDelete(id), 1);
      expect(await repo.findById(id), isNull);
    } on _Skip {
      return;
    }
  });

  test('CanvasRepository 全链路', () async {
    try {
      final h = req();
      final projRepo = PostgresProjectRepository(h.conn);
      final pid = await projRepo.create(name: 'P');
      final repo = PostgresCanvasRepository(h.conn);
      final cid = await repo.create(projectId: pid, name: 'Canvas A');
      expect((await repo.findById(cid))?['name'], 'Canvas A');
      expect(await repo.listByProject(pid), hasLength(1));

      await repo.update(cid, {'name': 'Canvas A2'});
      expect((await repo.findById(cid))?['name'], 'Canvas A2');

      await repo.softDelete(cid);
      expect(await repo.findById(cid), isNull);
      await repo.restore(cid);
      expect(await repo.findById(cid), isNotNull);
      await repo.hardDelete(cid);
    } on _Skip {
      return;
    }
  });

  test('CanvasRepository.listByProjects 一次取多项目画布 + 过滤软删', () async {
    try {
      final h = req();
      final projRepo = PostgresProjectRepository(h.conn);
      final repo = PostgresCanvasRepository(h.conn);
      final p1 = await projRepo.create(name: 'P1');
      final p2 = await projRepo.create(name: 'P2');
      final c1 = await repo.create(projectId: p1, name: 'C1');
      await repo.create(projectId: p2, name: 'C2');
      final c3 = await repo.create(projectId: p2, name: 'C3');
      await repo.softDelete(c3);

      final rows = await repo.listByProjects([p1, p2]);
      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r['name']),
        containsAll(<String>['C1', 'C2']),
      );

      expect(await repo.listByProjects([p1]), hasLength(1));
      expect(
        (await repo.listByProjects([p1])).single['id'].toString(),
        c1,
      );
    } on _Skip {
      return;
    }
  });

  test('StyleLaneRepository 全链路', () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final repo = PostgresStyleLaneRepository(h.conn);
      final id = await repo.create(
        canvasId: cid,
        label: 'Lane',
        stylePrompt: 'cinematic',
        sortOrder: 1,
        tintColor: '#FF0000',
      );
      expect(await repo.listByCanvas(cid), hasLength(1));
      await repo.update(id, {'label': 'Lane2'});
      expect((await repo.findById(id))?['label'], 'Lane2');
      await repo.softDelete(id);
      expect(await repo.findById(id), isNull);
      await repo.restore(id);
      await repo.hardDelete(id);
    } on _Skip {
      return;
    }
  });

  test('NodeRepository 全链路 + patchTypeConfig + listOrphanResults', () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final repo = PostgresNodeRepository(h.conn);
      final config = await repo.create(
        canvasId: cid,
        type: 'image',
        nodeRole: 'config',
        typeConfig: {'prompt': 'a'},
      );
      final result = await repo.create(
        canvasId: cid,
        type: 'image',
        nodeRole: 'result',
        sourceNodeId: config,
      );
      expect(await repo.listByCanvas(cid), hasLength(2));
      expect(await repo.listOrphanResults(cid), isEmpty);

      await repo.patchTypeConfig(result, {'progress': 0.5});
      final row = await repo.findById(result);
      expect(row?['type_config'], isA<Map<String, Object?>>()
          .having((m) => m['progress'], 'progress', 0.5));

      await repo.update(result, {
        'label': 'R1',
        'type_config': {'prompt': 'b'},
      });
      expect((await repo.findById(result))?['label'], 'R1');

      // 删 config → result 变孤儿
      await repo.hardDelete(config);
      expect(await repo.listOrphanResults(cid), hasLength(1));

      await repo.softDelete(result);
      expect(await repo.findById(result), isNull);
      await repo.restore(result);
      await repo.hardDelete(result);
    } on _Skip {
      return;
    }
  });

  test('EdgeRepository 全链路 + listOutgoing/Incoming', () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final nodes = PostgresNodeRepository(h.conn);
      final a = await nodes.create(
          canvasId: cid, type: 'image', nodeRole: 'config');
      final b = await nodes.create(
          canvasId: cid, type: 'image', nodeRole: 'result');
      final repo = PostgresEdgeRepository(h.conn);
      final e = await repo.create(
        canvasId: cid,
        sourceNodeId: a,
        targetNodeId: b,
        edgeType: 'generation_source',
      );
      expect(await repo.listByCanvas(cid), hasLength(1));
      expect(await repo.listOutgoing(a), hasLength(1));
      expect(await repo.listIncoming(b), hasLength(1));
      expect((await repo.findById(e))?['edge_type'], 'generation_source');
      await repo.update(e, {'role': 'first_frame'});
      expect((await repo.findById(e))?['role'], 'first_frame');
      await repo.softDelete(e);
      expect(await repo.findById(e), isNull);
      await repo.restore(e);
      await repo.hardDelete(e);
    } on _Skip {
      return;
    }
  });

  test('JobRepository 全链路 + transitionStatus + purgeExpired/PerCanvasCap',
      () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final nodes = PostgresNodeRepository(h.conn);
      final src = await nodes.create(
          canvasId: cid, type: 'image', nodeRole: 'config');
      final repo = PostgresJobRepository(h.conn);
      final id = await repo.create(
        canvasId: cid,
        sourceNodeId: src,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
        parameters: {'model': 'k'},
      );
      expect((await repo.findById(id))?['status'], 'pending');
      expect(await repo.listByCanvas(cid), hasLength(1));

      // pending → submitted via transition
      expect(
        await repo.transitionStatus(
          id: id,
          fromStatuses: const ['pending'],
          toStatus: 'submitted',
          extra: {'remote_task_id': 'rid'},
        ),
        1,
      );
      expect((await repo.findById(id))?['status'], 'submitted');
      expect((await repo.findById(id))?['remote_task_id'], 'rid');

      // 误跃迁：from 不匹配 → 0 行
      expect(
        await repo.transitionStatus(
          id: id,
          fromStatuses: const ['polling'],
          toStatus: 'success',
        ),
        0,
      );

      await repo.update(id, {'progress': 0.5, 'parameters': {'model': 'k2'}});
      expect(await repo.listByStatus(const ['submitted']), hasLength(1));
      expect(await repo.listDuePolling(10), isEmpty);

      // purge：status 不是终态 → 0 行；status=success + completed_at 足够老 → 1 行
      expect(await repo.purgeExpired(retention: const Duration(days: 30)), 0);

      await h.conn.execute(
        "UPDATE jobs SET status='success', completed_at = now() - interval '60 days'",
      );
      expect(await repo.purgeExpired(retention: const Duration(days: 30)), 1);

      // 重建一条、触发 perCanvasCap
      await repo.create(
        canvasId: cid,
        sourceNodeId: src,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      expect(await repo.purgePerCanvasCap(cap: 500), 0);
    } on _Skip {
      return;
    }
  });

  test('BatchResultRepository 全链路 + markPromoted', () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final nodes = PostgresNodeRepository(h.conn);
      final cfg = await nodes.create(
          canvasId: cid, type: 'image', nodeRole: 'config');
      final res = await nodes.create(
          canvasId: cid,
          type: 'image',
          nodeRole: 'result',
          sourceNodeId: cfg);
      final promoted = await nodes.create(
          canvasId: cid, type: 'image', nodeRole: 'result');
      final jobs = PostgresJobRepository(h.conn);
      final jid = await jobs.create(
        canvasId: cid,
        sourceNodeId: cfg,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      final repo = PostgresBatchResultRepository(h.conn);
      final id = await repo.create(
        nodeId: res,
        jobId: jid,
        slotIndex: 0,
        status: 'generating',
      );
      expect((await repo.findById(id))?['slot_index'], 0);
      expect((await repo.findBySlot(res, 0))?['id'].toString(), id);
      expect(await repo.listByNode(res), hasLength(1));
      await repo.update(id, {'status': 'success', 'output_url': '/tmp/x'});
      expect(await repo.markPromoted(id: id, promotedNodeId: promoted), 1);
      expect((await repo.findById(id))?['promoted'], true);
      await repo.hardDelete(id);
    } on _Skip {
      return;
    }
  });
}

class _Skip implements Exception {}
