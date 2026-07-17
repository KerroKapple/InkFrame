// LB-11→LB-12 roundtrip 大红测（卡面 DoD）：真导出 → 真导入（同库）→
// 行数相等 / 画廊相等 / 文件逐字节相等 / 新旧 id 零交集。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/job_statuses.dart';
import 'package:inkframe/core/interfaces/project_archive_reader.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/project_archive_service.dart';
import 'package:inkframe/services/project_import_service.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_character_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_archive_reader.dart';
import 'package:inkframe/storage/repositories/postgres_project_import_writer.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_prompt_preset_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';
import 'package:path/path.dart' as p;

import '../storage/schema/pg_test_harness.dart';

class _Skip implements Exception {}

class _FixedClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 7, 17, 12);
}

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'rt');
  });

  tearDown(() async {
    await harness?.close();
  });

  test('roundtrip：满配项目 导出→导入 全对齐', () async {
    final h = harness;
    if (h == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      return;
    }
    try {
      final tmp = Directory.systemTemp.createTempSync('ink_rt_');
      addTearDown(() {
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // archive 句柄泄漏已知问题。
        }
      });
      final paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'r')));
      await paths.ensureInitialized();

      // ── 种满配项目（含软删/自引用/lane/角色/预设/部分成功批量 job/cover）──
      final projects = PostgresProjectRepository(h.conn);
      final canvases = PostgresCanvasRepository(h.conn);
      final nodes = PostgresNodeRepository(h.conn);
      final edges = PostgresEdgeRepository(h.conn);
      final lanes = PostgresStyleLaneRepository(h.conn);
      final characters = PostgresCharacterRepository(h.conn);
      final presets = PostgresPromptPresetRepository(h.conn);
      final jobs = PostgresJobRepository(h.conn);
      final slots = PostgresBatchResultRepository(h.conn);

      final pid = await projects.create(name: 'RT');
      final c1 = await canvases.create(projectId: pid, name: 'main');
      final c2 = await canvases.create(projectId: pid, name: 'bin');
      final lane = await lanes.create(canvasId: c1, label: 'L');
      final n1 = await nodes.create(
          canvasId: c1, type: 'image', nodeRole: 'config',
          typeConfig: {'prompt': 'hello'});
      final n2 = await nodes.create(
          canvasId: c1, type: 'image', nodeRole: 'result',
          sourceNodeId: n1, laneId: lane,
          typeConfig: {'image_url': 'images/main.png'});
      final n3 = await nodes.create(
          canvasId: c2, type: 'image', nodeRole: 'config');
      await nodes.softDelete(n3);
      await canvases.softDelete(c2);
      await edges.create(
          canvasId: c1, sourceNodeId: n1, targetNodeId: n2, edgeType: 'data');
      final ch = await characters.create(
          projectId: pid, name: 'hero',
          referenceImagePaths: ['characters/hero.png']);
      await nodes.update(n1, {
        'type_config': {'prompt': 'hello', 'character_ids': [ch]},
      });
      await presets.create(projectId: pid, name: 'pp');
      await projects.update(pid, {'cover_node_id': n2});
      final j1 = await jobs.create(
          canvasId: c1, sourceNodeId: n1, resultNodeId: n2,
          providerId: 'prov', jobType: 'image',
          fullPrompt: 'f', userPrompt: 'u');
      final s1 = await slots.create(
          nodeId: n2, jobId: j1, slotIndex: 0, status: SlotStatuses.generating);
      await slots.update(s1, {
        'status': SlotStatuses.success,
        'output_url': 'images/s0.png',
      });
      await slots.create(
          nodeId: n2, jobId: j1, slotIndex: 1, status: SlotStatuses.error);

      // 磁盘产物。
      final projDir = Directory(p.join(paths.projects.path, pid));
      File(p.join(projDir.path, 'canvases', c1, 'images', 'main.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      File(p.join(projDir.path, 'canvases', c1, 'images', 's0.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([4, 5]);
      File(p.join(projDir.path, 'characters', 'hero.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([6]);

      // ── 真导出 ──
      final reader = PostgresProjectArchiveReader(h.conn);
      final zipPath = p.join(tmp.path, 'rt.zip');
      await ZipProjectArchiveService(
        reader: reader,
        paths: paths,
        clock: _FixedClock(),
        appVersion: 't',
      ).exportProject(projectId: pid, targetPath: zipPath);

      // ── 真导入（同库）──
      final result = await ZipProjectImportService(
        paths: paths,
        writer: PostgresProjectImportWriter(h.conn),
      ).importArchive(zipPath: zipPath);
      expect(result.outcome, ImportOutcome.imported);
      final newId = result.newProjectId!;
      expect(newId, isNot(pid));

      // ── 对齐断言 ──
      final src = await reader.snapshot(pid);
      final dst = await reader.snapshot(newId);
      expect(dst.canvases.length, src.canvases.length);
      expect(dst.lanes.length, src.lanes.length);
      expect(dst.nodes.length, src.nodes.length);
      expect(dst.edges.length, src.edges.length);
      expect(dst.characters.length, src.characters.length);
      expect(dst.presets.length, src.presets.length);
      expect(dst.jobs.length, src.jobs.length);
      expect(dst.batchResults.length, src.batchResults.length);
      // 新旧 id 零交集。
      Set<String> ids(ProjectArchiveSnapshot snap) => <String>{
            for (final t in <List<Map<String, Object?>>>[
              snap.canvases, snap.nodes, snap.edges, snap.lanes,
              snap.characters, snap.presets, snap.jobs, snap.batchResults,
            ])
              for (final r in t) r['id'].toString(),
          };
      expect(ids(src).intersection(ids(dst)), isEmpty);
      // 软删保真。
      expect(dst.canvases.where((r) => r['deleted_at'] != null), hasLength(1));
      expect(dst.nodes.where((r) => r['deleted_at'] != null), hasLength(1));
      // cover / character_ids 重映射闭合。
      final dstResult =
          dst.nodes.firstWhere((r) => r['node_role'] == 'result');
      expect(dst.project?['cover_node_id'].toString(),
          dstResult['id'].toString());
      final dstConfigCfg = dst.nodes
          .firstWhere((r) =>
              r['node_role'] == 'config' && r['deleted_at'] == null)['type_config'] as Map;
      expect((dstConfigCfg['character_ids'] as List).single.toString(),
          dst.characters.single['id'].toString());
      // 拍板 7 单独断言（#192 评审 P3-1）：在途 job 导入后终态化。
      expect(dst.jobs.single['status'], JobStatuses.cancelled);
      expect(dst.jobs.single['completed_at'], isNotNull);
      // 两趟 patch 断言：自引用与 lane 引用闭合。
      expect(dstResult['source_node_id'], isNotNull);
      expect(dstResult['lane_id'].toString(),
          dst.lanes.single['id'].toString());
      // created_at 保真。
      expect(dst.project?['created_at'], src.project?['created_at']);
      // 画廊相等（成功 slot 数与路径集）。
      final gallerySrc = await slots.listSuccessByProject(pid);
      final galleryDst = await slots.listSuccessByProject(newId);
      expect(galleryDst.length, gallerySrc.length);
      expect(galleryDst.map((r) => r['output_url']).toSet(),
          gallerySrc.map((r) => r['output_url']).toSet());
      // 文件逐字节对齐（canvases 段已改名）。
      final newC1 = dst.canvases
          .firstWhere((r) => r['deleted_at'] == null)['id']
          .toString();
      expect(
        File(p.join(paths.projects.path, newId, 'canvases', newC1, 'images',
                'main.png'))
            .readAsBytesSync(),
        [1, 2, 3],
      );
      expect(
        File(p.join(paths.projects.path, newId, 'canvases', newC1, 'images',
                's0.png'))
            .readAsBytesSync(),
        [4, 5],
      );
      expect(
        File(p.join(paths.projects.path, newId, 'characters', 'hero.png'))
            .readAsBytesSync(),
        [6],
      );
    } on _Skip {
      return;
    }
  });
}
