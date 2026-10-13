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
    'projects': [ProjectCol.id, ProjectCol.name, ProjectCol.coverNodeId, ProjectCol.createdAt, ProjectCol.updatedAt, ProjectCol.deletedAt, ProjectCol.deliverySettings],
    'canvases': [CanvasCol.id, CanvasCol.projectId, CanvasCol.name, CanvasCol.baseStylePrefix, CanvasCol.baseStyleSuffix, CanvasCol.viewportX, CanvasCol.viewportY, CanvasCol.viewportScale, CanvasCol.defaultNodeWidth, CanvasCol.laneDirection, CanvasCol.createdAt, CanvasCol.updatedAt, CanvasCol.deletedAt],
    'style_lanes': [StyleLaneCol.id, StyleLaneCol.canvasId, StyleLaneCol.label, StyleLaneCol.stylePrompt, StyleLaneCol.sortOrder, StyleLaneCol.tintColor, StyleLaneCol.size, StyleLaneCol.createdAt, StyleLaneCol.updatedAt, StyleLaneCol.deletedAt],
    'characters': [CharacterCol.id, CharacterCol.projectId, CharacterCol.name, CharacterCol.referenceImagePaths, CharacterCol.description, CharacterCol.sortOrder, CharacterCol.createdAt, CharacterCol.updatedAt, CharacterCol.deletedAt],
    'prompt_presets': [PromptPresetCol.id, PromptPresetCol.projectId, PromptPresetCol.name, PromptPresetCol.prompt, PromptPresetCol.prefix, PromptPresetCol.suffix, PromptPresetCol.negative, PromptPresetCol.sortOrder, PromptPresetCol.createdAt, PromptPresetCol.updatedAt, PromptPresetCol.deletedAt],
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

  // 【双向】原来只查「每个常量都是真列」，没查「每个真列都有常量」。迁移加了列却
  // 没补常量，这条测不出来——而 columns.dart 是导入白名单的真相源
  // （test/quality/import_schema_sync_test），常量缺一个，白名单闸就跟着漏一个，
  // 这一列在「导出再导入」之后静默消失（v8 的 delivery_settings 就是这样丢的，
  // 只不过那次漏在白名单这一环）。
  //
  // 按 current_schema() 过滤：harness 每条用例建一个独立 schema，CI 并行时同一个库里
  // 有很多份同名表；只按 table_name 查会把别的 schema 的列并进来。
  test('每张表：真库的列 == 列常量（双向）', () async {
    final h = harness;
    if (h == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过');
      return;
    }
    for (final entry in expected.entries) {
      final r = await h.conn.execute(
        Sql.named(
          'SELECT column_name FROM information_schema.columns '
          'WHERE table_schema = current_schema() AND table_name = @t',
        ),
        parameters: <String, Object?>{'t': entry.key},
      );
      final actual = r.map((row) => row[0]! as String).toSet();
      expect(actual, isNotEmpty, reason: '${entry.key} 在当前 schema 里不存在');
      final declared = entry.value.toSet();
      expect(
        actual,
        unorderedEquals(declared),
        reason: '${entry.key}：\n'
            '库里有、常量里没有 ⇒ ${actual.difference(declared)}'
            '（迁移加了列没补常量——导入白名单闸因此看不见它）\n'
            '常量里有、库里没有 ⇒ ${declared.difference(actual)}'
            '（常量写错或列已被删）',
      );
    }
  });

  // 自证：上面 expected 这张手抄表必须覆盖 columns.dart 里每个列类的**全部**常量。
  // 否则往 ProjectCol 加一个常量、这张表不动，它就从来没跟真库对过。不需要真 PG。
  test('expected 覆盖 columns.dart 每个列类的全部常量（自证）', () {
    const Map<String, String> tableOf = <String, String>{
      'ProjectCol': 'projects',
      'CanvasCol': 'canvases',
      'StyleLaneCol': 'style_lanes',
      'CharacterCol': 'characters',
      'PromptPresetCol': 'prompt_presets',
      'NodeCol': 'nodes',
      'EdgeCol': 'edges',
      'JobCol': 'jobs',
      'BatchResultCol': 'batch_results',
      'SchemaVersionCol': 'schema_version',
    };
    // 刻意不对真列的常量。
    const Set<String> notRealColumns = <String>{
      'project_id@nodes', // NodeCol.projectId：JOIN canvases 带出的派生列
    };
    final String src = File('lib/core/db/columns.dart').readAsStringSync();
    final Set<String> classes = <String>{
      for (final RegExpMatch m
          in RegExp(r'class\s+(\w+Col)\s*\{').allMatches(src))
        m.group(1)!,
    };
    expect(classes, unorderedEquals(<String>{...tableOf.keys, 'CommonCol'}),
        reason: 'columns.dart 多了 / 少了列类，tableOf 没跟上');

    tableOf.forEach((String cls, String table) {
      final RegExpMatch body =
          RegExp(r'class\s+' + cls + r'\s*\{([\s\S]*?)\n\}').firstMatch(src)!;
      final Set<String> fromSource = <String>{
        for (final RegExpMatch c in RegExp(r"static const \w+\s*=\s*'([^']+)'")
            .allMatches(body.group(1)!))
          if (!notRealColumns.contains('${c.group(1)}@$table')) c.group(1)!,
      };
      expect(
        expected[table]!.toSet(),
        unorderedEquals(fromSource),
        reason: '$cls 的常量与 expected[$table] 不一致：新常量没登进 expected，'
            '它就从来没跟真库对过',
      );
    });
  });
}
