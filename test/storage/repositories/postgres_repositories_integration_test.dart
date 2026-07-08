// 7 个 Postgres repository 的真 PG 冒烟测：完整走 CRUD + 软删 + 恢复链路。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/job_queue/job_media_persister.dart';
import 'package:inkframe/services/job_queue/job_state_persister.dart';
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

      // CR-01：所有读路径行内必须带非空 project_id（JOIN canvases 带出），
      // 否则生成链路读 null → 产物静默丢弃但 job 标 success。
      final cfgRow = await repo.findById(config);
      expect(cfgRow?['project_id'], isNotNull);
      expect(cfgRow?['project_id'].toString(), pid);
      for (final r in await repo.listByCanvas(cid)) {
        expect(r['project_id'].toString(), pid);
      }

      // 行内 project_id 必须能直接喂给 FileResolverService 解析产物落盘路径。
      final tmp = await Directory.systemTemp.createTemp('inkframe-cr01-');
      addTearDown(() => tmp.delete(recursive: true));
      final resolver =
          DefaultFileResolverService(DefaultAppPaths.forRoot(tmp));
      final artifact = resolver.resolve(
        projectId: cfgRow!['project_id'].toString(),
        canvasId: cfgRow['canvas_id'].toString(),
        relativePath: 'outputs/result.png',
      );
      expect(
        artifact.path.replaceAll('\\', '/'),
        contains('/projects/$pid/canvases/$cid/outputs/result.png'),
      );

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

  test('BatchResultRepository.listSuccessByProject：跨画布聚合 + 过滤状态/软删 + join 派生列',
      () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final canvasRepo = PostgresCanvasRepository(h.conn);
      final cid1 = await canvasRepo.create(projectId: pid, name: 'C1');
      final cid2 = await canvasRepo.create(projectId: pid, name: 'C2');
      final nodes = PostgresNodeRepository(h.conn);
      final cfg =
          await nodes.create(canvasId: cid1, type: 'image', nodeRole: 'config');
      final res1 = await nodes.create(
          canvasId: cid1, type: 'image', nodeRole: 'result', sourceNodeId: cfg);
      final res2 =
          await nodes.create(canvasId: cid2, type: 'image', nodeRole: 'result');
      final jid = await PostgresJobRepository(h.conn).create(
        canvasId: cid1,
        sourceNodeId: cfg,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      final repo = PostgresBatchResultRepository(h.conn);
      final ok1 = await repo.create(
          nodeId: res1, jobId: jid, slotIndex: 0, status: 'success');
      await repo.update(ok1, {'output_url': 'images/a.png'});
      final ok2 = await repo.create(
          nodeId: res2, jobId: jid, slotIndex: 1, status: 'success');
      await repo.update(ok2, {'output_url': 'images/b.png'});
      await repo.create(
          nodeId: res1, jobId: jid, slotIndex: 2, status: 'error');

      // 锁 created_at DESC 排序(与 fake 契约同语义,防真库侧漂移):
      // 顺序插入可能同毫秒,显式拉开两行时间戳。
      await h.conn.execute(
        "UPDATE batch_results SET created_at = TIMESTAMPTZ '2026-01-01T00:00:00Z' "
        "WHERE id = '$ok1'",
      );
      await h.conn.execute(
        "UPDATE batch_results SET created_at = TIMESTAMPTZ '2026-01-02T00:00:00Z' "
        "WHERE id = '$ok2'",
      );

      final rows = await repo.listSuccessByProject(pid);
      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r['id'].toString()).toList(),
        [ok2, ok1],
        reason: 'created_at DESC',
      );
      expect(
        rows.map((r) => r['canvas_id']?.toString()),
        containsAll(<String>[cid1, cid2]),
      );
      expect(rows.every((r) => r['project_id']?.toString() == pid), isTrue);

      // 软删节点的 slot 不出现
      await nodes.softDelete(res2);
      expect(await repo.listSuccessByProject(pid), hasLength(1));
      // 软删画布的 slot 不出现
      await canvasRepo.softDelete(cid1);
      expect(await repo.listSuccessByProject(pid), isEmpty);
      // 别的项目 → 空
      expect(
        await repo
            .listSuccessByProject('00000000-0000-0000-0000-000000000000'),
        isEmpty,
      );
    } on _Skip {
      return;
    }
  });

  // 直接调用 softDeleteEmptyOrphanResults() 的守卫矩阵（防御纵深）。
  // 注意：这是把收敛单独调用时的过滤契约——不是生产启动路径。生产里
  // JobStatePersister.init() 会先把 pending/submitted/polling 全部 bulkTransition
  // 成 cancelled，再跑收敛，届时不存在在途 job（见下方 full-init() 用例）。故场景
  // (c) 的「在途 job 保护」是 direct-call 路径的防御纵深守卫，非启动语义。
  test('NodeRepository.softDeleteEmptyOrphanResults 直调守卫矩阵（防御纵深，LB-14）',
      () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final nodes = PostgresNodeRepository(h.conn);
      final jobs = PostgresJobRepository(h.conn);
      final batch = PostgresBatchResultRepository(h.conn);

      // (a) 纯空 result：无 url / 无成功 slot / 无在途 job → 应被软删。
      final a =
          await nodes.create(canvasId: cid, type: 'image', nodeRole: 'result');
      // (b) 空 result 但有 success batch_result → 保留（部分成功后崩溃场景）。
      final b =
          await nodes.create(canvasId: cid, type: 'image', nodeRole: 'result');
      final jb = await jobs.create(
        canvasId: cid,
        sourceNodeId: a,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      await batch.create(nodeId: b, jobId: jb, slotIndex: 0, status: 'success');
      // (c) 空 result 但有 LIVE polling job（result_node_id=c）→ 直调时保留。
      // 防御纵深：仅当收敛被单独调用、且 job 仍在途时才成立；启动路径下 job 已先被
      // 取消（见 full-init() 用例），故该节点在生产里会被清扫，不会被此守卫救回。
      final c =
          await nodes.create(canvasId: cid, type: 'image', nodeRole: 'result');
      final jc = await jobs.create(
        canvasId: cid,
        sourceNodeId: a,
        resultNodeId: c,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      await jobs.transitionStatus(
        id: jc,
        fromStatuses: const ['pending'],
        toStatus: 'polling',
      );
      // (d) result 但 image_url 已写 → 保留。
      final d = await nodes.create(
        canvasId: cid,
        type: 'image',
        nodeRole: 'result',
        typeConfig: {'image_url': 'images/d.png'},
      );

      // 仅 (a) 被收敛。
      expect(await nodes.softDeleteEmptyOrphanResults(), 1);

      expect(await nodes.findById(a), isNull, reason: '(a) 空壳进回收站');
      expect(await nodes.findById(b), isNotNull, reason: '(b) success slot 保护');
      expect(await nodes.findById(c), isNotNull,
          reason: '(c) LIVE 在途 job 保护（direct-call 防御纵深）');
      expect(await nodes.findById(d), isNotNull, reason: '(d) 有 image_url 保护');
    } on _Skip {
      return;
    }
  });

  // 生产启动全序列：init() 先取消在途 job（bulkTransition），再收敛空壳。故崩溃时
  // 处于 polling 的空 result 节点，其 job 会被取消、随后节点被清扫——证明真实
  // post-recovery 路径，而非 direct-call 守卫。
  test('JobStatePersister.init() 全序列：崩溃时 polling 的空 result 节点被取消后清扫（LB-14）',
      () async {
    try {
      final h = req();
      final pid = await PostgresProjectRepository(h.conn).create(name: 'P');
      final cid = await PostgresCanvasRepository(h.conn)
          .create(projectId: pid, name: 'C');
      final nodes = PostgresNodeRepository(h.conn);
      final jobs = PostgresJobRepository(h.conn);

      // 崩溃现场：一个空 result 节点，其 job 崩溃时停在 polling（result_node_id 指向它）。
      final crashed =
          await nodes.create(canvasId: cid, type: 'image', nodeRole: 'result');
      final job = await jobs.create(
        canvasId: cid,
        sourceNodeId: crashed,
        resultNodeId: crashed,
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
      );
      await jobs.transitionStatus(
        id: job,
        fromStatuses: const ['pending'],
        toStatus: 'polling',
      );

      // 驱动真实启动恢复序列（孤儿回收 → slot 收敛 → purge → 空壳收敛）。
      final persister = JobStatePersister(
        repo: PostgresJobRepository(h.conn),
        batchResults: PostgresBatchResultRepository(h.conn),
        nodeRepo: PostgresNodeRepository(h.conn),
        media: const NullJobMediaPersister(),
      );
      await persister.init();

      // 在途 job 先被取消（recovery）……
      expect((await jobs.findById(job))?['status'], 'cancelled',
          reason: '在途 job 启动时被 bulkTransition 取消');
      // ……随后空壳无在途 job 保护，被清扫进回收站。
      expect(await nodes.findById(crashed), isNull,
          reason: 'polling-at-crash 空壳在 job 取消后被清扫');
    } on _Skip {
      return;
    }
  });
}

class _Skip implements Exception {}
