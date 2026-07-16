// PostgresProjectArchiveReader 真 PG 集成测：全保真读侧（软删含入、success-job 过滤、FK 闭包）。
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

  test('全保真读侧：软删行含入、success-job 过滤、slot 全带、项目隔离', () async {
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

      // 种子：项目 → 2 画布（1 软删）→ 3 节点（1 软删）→ 边/泳道/角色/预设各 1（角色软删）
      // → 2 job（仅 1 个有 success slot）。
      final pid = await projects.create(name: 'p');
      final c1 = await canvases.create(projectId: pid, name: 'c1');
      final c2 = await canvases.create(projectId: pid, name: 'c2');
      await canvases.softDelete(c2);

      final n1 = await nodes.create(
        canvasId: c1, type: 'image', nodeRole: 'config');
      final n2 = await nodes.create(
        canvasId: c1, type: 'image', nodeRole: 'result', sourceNodeId: n1);
      final n3 = await nodes.create(
        canvasId: c2, type: 'image', nodeRole: 'config');
      await nodes.softDelete(n2);

      await edges.create(
        canvasId: c1, sourceNodeId: n1, targetNodeId: n2, edgeType: 'data');
      await lanes.create(canvasId: c1, label: 'lane');
      final ch = await characters.create(projectId: pid, name: 'hero');
      await characters.softDelete(ch);
      await presets.create(projectId: pid, name: 'preset');

      final j1 = await jobs.create(
        canvasId: c1, sourceNodeId: n1, resultNodeId: n2,
        providerId: 'prov', jobType: 'image',
        fullPrompt: 'fp', userPrompt: 'up');
      final j2 = await jobs.create(
        canvasId: c1, sourceNodeId: n1,
        providerId: 'prov', jobType: 'image',
        fullPrompt: 'fp', userPrompt: 'up');
      final s1 = await slots.create(
        nodeId: n2, jobId: j1, slotIndex: 0, status: SlotStatuses.generating);
      await slots.update(s1, <String, Object?>{'status': SlotStatuses.success});
      await slots.create(
        nodeId: n2, jobId: j1, slotIndex: 1, status: SlotStatuses.error);
      await slots.create(
        nodeId: n2, jobId: j2, slotIndex: 0, status: SlotStatuses.error);

      // 全保真：软删画布 / 节点 / 角色都含入，deleted_at 随行。
      expect((await reader.projectRow(pid))?['id'], pid);
      expect(await reader.canvasRows(pid), hasLength(2));
      final nodeRows = await reader.nodeRows(pid);
      expect(nodeRows, hasLength(3));
      expect(nodeRows.where((r) => r['deleted_at'] != null), hasLength(1));
      expect(nodeRows.map((r) => r['id']), containsAll(<String>[n1, n2, n3]));
      expect(await reader.edgeRows(pid), hasLength(1));
      expect(await reader.laneRows(pid), hasLength(1));
      final charRows = await reader.characterRows(pid);
      expect(charRows, hasLength(1));
      expect(charRows.single['deleted_at'], isNotNull);
      expect(await reader.presetRows(pid), hasLength(1));

      // 只有 j1（有 success slot）被导出，且其全部 2 个 slot 都带上。
      final jobRows = await reader.successJobRows(pid);
      expect(jobRows.map((r) => r['id']), <String>[j1]);
      final slotRows = await reader.batchResultRows(pid);
      expect(slotRows, hasLength(2));
      expect(slotRows.every((r) => r['job_id'] == j1), isTrue);
      expect(
        slotRows.map((r) => r['slot_index']).toList(),
        <int>[0, 1],
      );

      // 项目隔离：无关项目读空。
      final pid2 = await projects.create(name: 'other');
      expect(await reader.projectRow('00000000-0000-0000-0000-000000000000'),
          isNull);
      expect(await reader.canvasRows(pid2), isEmpty);
      expect(await reader.successJobRows(pid2), isEmpty);
      expect(await reader.batchResultRows(pid2), isEmpty);
    } on _Skip {
      return;
    }
  });
}
