// PostgresProjectImportWriter 真 PG 集成测（LB-12）：保真写入 + 事务回滚零残留。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/services/import/import_remapper.dart';
import 'package:inkframe/storage/repositories/postgres_project_archive_reader.dart';
import 'package:inkframe/storage/repositories/postgres_project_import_writer.dart';
import 'package:uuid/uuid.dart';

import '../schema/pg_test_harness.dart';

class _Skip implements Exception {}

/// 与 remapper 单测同构的小项目 data.json（旧 id 用可读别名）。
Map<String, dynamic> _data() => <String, dynamic>{
      'project': {
        'id': 'P', 'name': 'demo', 'cover_node_id': 'n2',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      },
      'canvases': [
        {'id': 'c1', 'project_id': 'P', 'name': 'A',
         'created_at': '2026-01-01T00:00:00.000Z'},
        {'id': 'c2', 'project_id': 'P', 'name': 'B',
         'created_at': '2026-01-01T00:00:00.000Z',
         'deleted_at': '2026-01-02T00:00:00.000Z'},
      ],
      'lanes': [
        {'id': 'l1', 'canvas_id': 'c1', 'label': 'lane'},
      ],
      'nodes': [
        {'id': 'n1', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'config',
         'type_config': {'prompt': 'x', 'character_ids': ['ch1']},
         'created_at': '2026-01-01T00:00:00.000Z'},
        {'id': 'n2', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'result',
         'source_node_id': 'n1', 'lane_id': 'l1',
         'created_at': '2026-01-01T01:00:00.000Z',
         'deleted_at': '2026-01-05T00:00:00.000Z'},
      ],
      'edges': [
        {'id': 'e1', 'canvas_id': 'c1', 'source_node_id': 'n1',
         'target_node_id': 'n2', 'edge_type': 'data'},
      ],
      'characters': [
        {'id': 'ch1', 'project_id': 'P', 'name': 'hero',
         'reference_image_paths': ['characters/hero.png']},
      ],
      'prompt_presets': [
        {'id': 'pp1', 'project_id': 'P', 'name': 'preset'},
      ],
      'jobs': [
        {'id': 'j1', 'canvas_id': 'c1', 'source_node_id': 'n1',
         'result_node_id': 'n2', 'provider_id': 'prov', 'job_type': 'image',
         'status': 'polling', 'full_prompt': 'f', 'user_prompt': 'u',
         'parameters': {'seed': 42},
         'created_at': '2026-01-03T00:00:00.000Z'},
      ],
      'batch_results': [
        {'id': 's1', 'node_id': 'n2', 'job_id': 'j1', 'slot_index': 0,
         'status': 'success', 'output_url': 'images/s0.png'},
      ],
    };

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'import');
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

  test('保真写入：行数/自引用/JSONB/时间戳/软删/终态化全对齐', () async {
    try {
      final h = req();
      final plan = remapArchiveData(_data(), newId: const Uuid().v4);
      await PostgresProjectImportWriter(h.conn).writeAll(plan);

      final reader = PostgresProjectArchiveReader(h.conn);
      final snap = await reader.snapshot(plan.newProjectId);

      expect(snap.project?['name'], 'demo');
      expect((snap.project?['created_at'] as DateTime).toUtc(),
          DateTime.utc(2026, 1, 1));
      // cover 补丁生效且指向新 id。
      final n2New = snap.nodes
          .firstWhere((r) => r['node_role'] == 'result')['id']
          .toString();
      expect(snap.project?['cover_node_id'].toString(), n2New);

      expect(snap.canvases, hasLength(2));
      expect(snap.canvases.where((r) => r['deleted_at'] != null), hasLength(1));
      expect(snap.lanes, hasLength(1));
      expect(snap.nodes, hasLength(2));
      // 自引用与 lane 补丁。
      final result = snap.nodes.firstWhere((r) => r['node_role'] == 'result');
      final config = snap.nodes.firstWhere((r) => r['node_role'] == 'config');
      expect(result['source_node_id'].toString(), config['id'].toString());
      expect(result['lane_id'].toString(),
          snap.lanes.single['id'].toString());
      expect(result['deleted_at'], isNotNull); // 软删保真。
      // JSONB 往返 + character_ids 已重映射。
      final cfg = config['type_config'] as Map;
      expect(cfg['prompt'], 'x');
      expect((cfg['character_ids'] as List).single.toString(),
          snap.characters.single['id'].toString());
      expect(snap.edges, hasLength(1));
      expect(snap.presets, hasLength(1));
      // 终态化：polling→cancelled+completed_at。
      expect(snap.jobs.single['status'], 'cancelled');
      expect(snap.jobs.single['completed_at'], isNotNull);
      expect((snap.jobs.single['parameters'] as Map)['seed'], 42);
      expect(snap.batchResults.single['output_url'], 'images/s0.png');
    } on _Skip {
      return;
    }
  });

  test('事务性：末表 FK 悬空 → 整体回滚零残留', () async {
    try {
      final h = req();
      final good = remapArchiveData(_data(), newId: const Uuid().v4);
      // 手工造坏 plan：batch 行指向不存在的 job（绕过 remapper 防线，直击事务）。
      final bad = ImportPlanData(
        newProjectId: good.newProjectId,
        canvasIdMap: good.canvasIdMap,
        project: good.project,
        canvases: good.canvases,
        lanes: good.lanes,
        nodes: good.nodes,
        edges: good.edges,
        characters: good.characters,
        presets: good.presets,
        jobs: good.jobs,
        batchResults: [
          ...good.batchResults,
          {
            'id': const Uuid().v4(),
            'node_id': good.nodes.first['id'],
            'job_id': const Uuid().v4(), // 悬空 FK。
            'slot_index': 9,
            'status': 'success',
          },
        ],
        droppedColumnCount: 0,
        nulledRefCount: 0,
        droppedRowCount: 0,
      );

      await expectLater(
        PostgresProjectImportWriter(h.conn).writeAll(bad),
        throwsA(anything),
      );
      // 零残留：项目行不存在。
      final snap = await PostgresProjectArchiveReader(h.conn)
          .snapshot(bad.newProjectId);
      expect(snap.project, isNull);
      expect(snap.canvases, isEmpty);
      expect(snap.nodes, isEmpty);
    } on _Skip {
      return;
    }
  });
}
