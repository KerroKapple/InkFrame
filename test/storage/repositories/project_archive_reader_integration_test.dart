// PostgresProjectArchiveReader 真 PG 集成测：全保真快照（软删含入、success-job 过滤、FK 闭包）。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/job_statuses.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_character_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_archive_reader.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_prompt_preset_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';

import '../schema/pg_test_harness.dart';

class _Skip implements Exception {}

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'archive');
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

  test('全保真快照：软删行含入、success-job 过滤、slot 全带、项目隔离', () async {
    try {
      final h = req();
      final projects = PostgresProjectRepository(h.conn);
      final canvases = PostgresCanvasRepository(h.conn);
      final nodes = PostgresNodeRepository(h.conn);
      final edges = PostgresEdgeRepository(h.conn);
      final lanes = PostgresStyleLaneRepository(h.conn);
      final characters = PostgresCharacterRepository(h.conn);
      final presets = PostgresPromptPresetRepository(h.conn);
      final jobs = PostgresJobRepository(h.conn);
      final slots = PostgresBatchResultRepository(h.conn);
      final reader = PostgresProjectArchiveReader(h.conn);

      // 种子：项目 → 2 画布（c2 软删）→ 节点 ×4（n2 软删）→ 边/泳道/角色/预设
      // → 3 job：j1(成功 slot×1+失败×1) / j2(纯失败,自有节点) / j3(软删画布上的成功)。
      // 注意 batch_results 有 UNIQUE(node_id, slot_index)——slot 槽位按节点唯一，
      // 每个 job 的 slot 必须种在各自的 result 节点上。
      final pid = await projects.create(name: 'p');
      final c1 = await canvases.create(projectId: pid, name: 'c1');
      final c2 = await canvases.create(projectId: pid, name: 'c2');

      final n1 = await nodes.create(
        canvasId: c1, type: 'image', nodeRole: 'config');
      final n2 = await nodes.create(
        canvasId: c1, type: 'image', nodeRole: 'result', sourceNodeId: n1);
      final n4 = await nodes.create(
        canvasId: c1, type: 'image', nodeRole: 'result', sourceNodeId: n1);
      final n5 = await nodes.create(
        canvasId: c2, type: 'image', nodeRole: 'result', sourceNodeId: n1);
      await nodes.softDelete(n2);
      await canvases.softDelete(c2);

      await edges.create(
        canvasId: c1, sourceNodeId: n1, targetNodeId: n2, edgeType: 'data');
      await lanes.create(canvasId: c1, label: 'lane');
      final ch = await characters.create(projectId: pid, name: 'hero');
      await characters.softDelete(ch);
      await presets.create(projectId: pid, name: 'preset');

      Future<String> seedJob(String canvasId, String nodeId) => jobs.create(
            canvasId: canvasId,
            sourceNodeId: n1,
            resultNodeId: nodeId,
            providerId: 'prov',
            jobType: 'image',
            fullPrompt: 'fp',
            userPrompt: 'up',
          );
      // j1：成功 slot + 失败 slot（slot 全带语义）。
      final j1 = await seedJob(c1, n2);
      final s1 = await slots.create(
        nodeId: n2, jobId: j1, slotIndex: 0, status: SlotStatuses.generating);
      await slots.update(s1, <String, Object?>{'status': SlotStatuses.success});
      await slots.create(
        nodeId: n2, jobId: j1, slotIndex: 1, status: SlotStatuses.error);
      // j2：纯失败 → 不入选。
      final j2 = await seedJob(c1, n4);
      await slots.create(
        nodeId: n4, jobId: j2, slotIndex: 0, status: SlotStatuses.error);
      // j3：软删画布上的成功 job → 照样入选（接口注释的显式语义）。
      final j3 = await seedJob(c2, n5);
      final s3 = await slots.create(
        nodeId: n5, jobId: j3, slotIndex: 0, status: SlotStatuses.generating);
      await slots.update(s3, <String, Object?>{'status': SlotStatuses.success});

      final snap = await reader.snapshot(pid);

      // 全保真：软删画布 / 节点 / 角色都含入，deleted_at 随行。
      expect(snap.project?['id'], pid);
      expect(snap.canvases, hasLength(2));
      expect(
          snap.canvases.where((r) => r['deleted_at'] != null), hasLength(1));
      expect(snap.nodes, hasLength(4));
      expect(snap.nodes.where((r) => r['deleted_at'] != null), hasLength(1));
      expect(snap.nodes.map((r) => r['id']),
          containsAll(<String>[n1, n2, n4, n5]));
      expect(snap.edges, hasLength(1));
      expect(snap.lanes, hasLength(1));
      expect(snap.characters, hasLength(1));
      expect(snap.characters.single['deleted_at'], isNotNull);
      expect(snap.presets, hasLength(1));

      // 只有含 success slot 的 j1/j3 入选（j2 纯失败排除），slot 全带（含失败）。
      expect(snap.jobs.map((r) => r['id']).toSet(), <String>{j1, j3});
      expect(snap.batchResults, hasLength(3));
      expect(snap.batchResults.map((r) => r['job_id']).toSet(),
          <String>{j1, j3});
      final j1Slots =
          snap.batchResults.where((r) => r['job_id'] == j1).toList();
      expect(j1Slots.map((r) => r['slot_index']).toList(), <int>[0, 1]);

      // FK 闭包：slot/job 引用的节点全部在 nodes 快照内。
      final nodeIds = snap.nodes.map((r) => r['id']).toSet();
      for (final r in snap.batchResults) {
        expect(nodeIds, contains(r['node_id']));
      }
      for (final r in snap.jobs) {
        expect(nodeIds, contains(r['result_node_id']));
        expect(nodeIds, contains(r['source_node_id']));
      }

      // 项目隔离：无关项目读空；不存在的项目 project=null。
      final pid2 = await projects.create(name: 'other');
      final snap2 = await reader.snapshot(pid2);
      expect(snap2.project?['id'], pid2);
      expect(snap2.canvases, isEmpty);
      expect(snap2.jobs, isEmpty);
      expect(snap2.batchResults, isEmpty);
      final none =
          await reader.snapshot('00000000-0000-0000-0000-000000000000');
      expect(none.project, isNull);
    } on _Skip {
      return;
    }
  });
}
