// PostgresProjectImportWriter —— LB-12 导入专用保真写侧（见接口注释）。
//
// 单 runTx 事务按 FK 序插入：project(cover 置 NULL) → canvases → style_lanes →
// nodes 两趟（先 source_node_id/lane_id 置 NULL 后 patch——自引用无序依赖）→
// edges → characters → prompt_presets → jobs → batch_results → cover 补丁。
// JSONB 列（type_config/parameters/reference_image_paths）经 jsonEncode + ::jsonb。
// 列名全部来自 remapper 的 columns.dart 白名单（无注入面）；值走参数绑定。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/db/columns.dart';
import '../../core/interfaces/project_import_writer.dart';
import '../../core/models/import_plan_data.dart';
import '../base_repository.dart';

class PostgresProjectImportWriter
    with BaseRepository
    implements ProjectImportWriter {
  /// [session] 需同时是 [SessionExecutor]（Pool / Connection 均满足）。
  PostgresProjectImportWriter(this.session)
      : assert(session is SessionExecutor);

  @override
  final Session session;

  static const Set<String> _jsonbCols = <String>{
    NodeCol.typeConfig,
    JobCol.parameters,
    CharacterCol.referenceImagePaths,
  };

  @override
  Future<void> writeAll(ImportPlanData plan) {
    return guard('importWrite', 'project_import', () async {
      await (session as SessionExecutor).runTx<void>((tx) async {
        Future<void> insert(String table, Map<String, Object?> row) async {
          final List<String> cols = row.keys.toList();
          final Map<String, Object?> params = <String, Object?>{};
          final List<String> vals = <String>[];
          for (var i = 0; i < cols.length; i++) {
            final String c = cols[i];
            final String key = 'p$i';
            final Object? v = row[c];
            if (_jsonbCols.contains(c) && (v is Map || v is List)) {
              params[key] = jsonEncode(v);
              vals.add('@$key::jsonb');
            } else {
              params[key] = v;
              vals.add('@$key');
            }
          }
          await tx.execute(
            Sql.named(
              'INSERT INTO $table (${cols.join(', ')}) '
              'VALUES (${vals.join(', ')})',
            ),
            parameters: params,
          );
        }

        // 1) project——cover_node_id 先置 NULL（nodes 尚不存在），尾段补丁。
        final Object? cover = plan.project[ProjectCol.coverNodeId];
        await insert('projects', <String, Object?>{
          ...plan.project,
          ProjectCol.coverNodeId: null,
        });
        for (final r in plan.canvases) {
          await insert('canvases', r);
        }
        for (final r in plan.lanes) {
          await insert('style_lanes', r);
        }
        // 2) nodes 两趟：自引用（source_node_id）与 lane 引用先 NULL 后 patch。
        for (final r in plan.nodes) {
          await insert('nodes', <String, Object?>{
            ...r,
            NodeCol.sourceNodeId: null,
            NodeCol.laneId: null,
          });
        }
        for (final r in plan.nodes) {
          final Object? src = r[NodeCol.sourceNodeId];
          final Object? lane = r[NodeCol.laneId];
          if (src == null && lane == null) continue;
          // updated_at 回写原值（保真；CI 的 UPDATE 语句 updated_at 扫描同时满足）。
          await tx.execute(
            Sql.named(
              'UPDATE nodes SET source_node_id = @s, lane_id = @l, '
              'updated_at = COALESCE(@u::timestamptz, updated_at) '
              'WHERE id = @id',
            ),
            parameters: <String, Object?>{
              's': src,
              'l': lane,
              'u': r[NodeCol.updatedAt],
              'id': r[NodeCol.id],
            },
          );
        }
        for (final r in plan.edges) {
          await insert('edges', r);
        }
        for (final r in plan.characters) {
          await insert('characters', r);
        }
        for (final r in plan.presets) {
          await insert('prompt_presets', r);
        }
        for (final r in plan.jobs) {
          await insert('jobs', r);
        }
        for (final r in plan.batchResults) {
          await insert('batch_results', r);
        }
        // 3) cover 补丁。
        if (cover != null) {
          await tx.execute(
            Sql.named(
              'UPDATE projects SET cover_node_id = @c, '
              'updated_at = COALESCE(@u::timestamptz, updated_at) '
              'WHERE id = @id',
            ),
            parameters: <String, Object?>{
              'c': cover,
              'u': plan.project[ProjectCol.updatedAt],
              'id': plan.newProjectId,
            },
          );
        }
      });
    });
  }
}
