// 列名常量对真库 information_schema 校验：常量值必须是表的真实列。pg-tagged。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/columns.dart';
import 'package:postgres/postgres.dart';

import '../../storage/schema/pg_test_harness.dart';

void main() {
  // 每个表 → 该表必须存在的列常量集合（NodeCol.projectId 是 JOIN 列，排除）。
  final expected = <String, List<String>>{
    'projects': [ProjectCol.id, ProjectCol.name, ProjectCol.coverNodeId, ProjectCol.createdAt, ProjectCol.updatedAt, ProjectCol.deletedAt],
    'canvases': [CanvasCol.id, CanvasCol.projectId, CanvasCol.name, CanvasCol.baseStylePrefix, CanvasCol.baseStyleSuffix, CanvasCol.viewportX, CanvasCol.viewportY, CanvasCol.viewportScale, CanvasCol.defaultNodeWidth, CanvasCol.laneDirection, CanvasCol.createdAt, CanvasCol.updatedAt, CanvasCol.deletedAt],
    'style_lanes': [StyleLaneCol.id, StyleLaneCol.canvasId, StyleLaneCol.label, StyleLaneCol.stylePrompt, StyleLaneCol.sortOrder, StyleLaneCol.tintColor, StyleLaneCol.size, StyleLaneCol.createdAt, StyleLaneCol.updatedAt, StyleLaneCol.deletedAt],
    'nodes': [NodeCol.id, NodeCol.canvasId, NodeCol.type, NodeCol.label, NodeCol.nodeRole, NodeCol.status, NodeCol.sourceNodeId, NodeCol.positionX, NodeCol.positionY, NodeCol.width, NodeCol.height, NodeCol.zIndex, NodeCol.laneId, NodeCol.typeConfig, NodeCol.createdAt, NodeCol.updatedAt, NodeCol.deletedAt],
    'edges': [EdgeCol.id, EdgeCol.canvasId, EdgeCol.sourceNodeId, EdgeCol.targetNodeId, EdgeCol.edgeType, EdgeCol.role, EdgeCol.sortOrder, EdgeCol.createdAt, EdgeCol.deletedAt],
    'jobs': [JobCol.id, JobCol.canvasId, JobCol.sourceNodeId, JobCol.resultNodeId, JobCol.providerId, JobCol.jobType, JobCol.status, JobCol.remoteTaskId, JobCol.fullPrompt, JobCol.userPrompt, JobCol.parameters, JobCol.batchSize, JobCol.progress, JobCol.errorCode, JobCol.errorMessage, JobCol.timeoutAt, JobCol.createdAt, JobCol.submittedAt, JobCol.completedAt],
    'batch_results': [BatchResultCol.id, BatchResultCol.nodeId, BatchResultCol.jobId, BatchResultCol.slotIndex, BatchResultCol.status, BatchResultCol.outputUrl, BatchResultCol.thumbnailUrl, BatchResultCol.width, BatchResultCol.height, BatchResultCol.fileSizeBytes, BatchResultCol.seed, BatchResultCol.errorCode, BatchResultCol.errorMessage, BatchResultCol.promoted, BatchResultCol.promotedNodeId, BatchResultCol.createdAt, BatchResultCol.completedAt],
    'schema_version': [SchemaVersionCol.id, SchemaVersionCol.version, SchemaVersionCol.appliedAt],
  };

  late PgTestHarness? harness;
  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'cols');
  });
  tearDown(() async => harness?.close());

  test('每个表的列常量都存在于真库 information_schema', () async {
    final h = harness;
    if (h == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过');
      return;
    }
    for (final entry in expected.entries) {
      final r = await h.conn.execute(
        Sql.named(
          'SELECT column_name FROM information_schema.columns WHERE table_name = @t',
        ),
        parameters: <String, Object?>{'t': entry.key},
      );
      final actual = r.map((row) => row[0]! as String).toSet();
      for (final col in entry.value) {
        expect(actual, contains(col),
            reason: '${entry.key} 缺列常量 "$col"（schema 漂移或常量写错）');
      }
    }
  });
}
