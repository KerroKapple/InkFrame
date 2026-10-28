// PostgresNodeRepository —— nodes 表实现。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/constants/import_keys.dart';
import '../../core/constants/job_statuses.dart';
import '../../core/interfaces/node_repository.dart';
import '../base_repository.dart';

class PostgresNodeRepository with BaseRepository implements NodeRepository {
  PostgresNodeRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) {
    return guard('create', 'nodes', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO nodes (canvas_id, type, label, node_role, source_node_id, '
          'lane_id, position_x, position_y, width, height, z_index, type_config) '
          'VALUES (@cid, @type, @lbl, @role, @src, @lane, @px, @py, @w, @h, @z, @cfg::jsonb) '
          'RETURNING id',
        ),
        parameters: <String, Object?>{
          'cid': canvasId,
          'type': type,
          'lbl': label,
          'role': nodeRole,
          'src': sourceNodeId,
          'lane': laneId,
          'px': positionX,
          'py': positionY,
          'w': width,
          'h': height,
          'z': zIndex,
          'cfg': jsonEncode(typeConfig),
        },
      );
      return r.first[0]!.toString();
    });
  }

  // 读路径统一 JOIN canvases 带出 project_id（CR-01）：
  // 生成链路 / CanvasNode.fromRow 依赖行内 project_id 解析产物落盘路径。
  //
  // JOIN 条件上的 `c.deleted_at IS NULL` 不是装饰：画布软删【不级联】到 nodes
  // （canvases.softDelete 只碰 canvases 那一行），所以只过滤 n.deleted_at 的
  // 读路径会把已删画布的节点照常读出来——画面上完全看不出它已被删，用户的
  // 改动会一直写进一张已删画布。过滤必须在读路径上做，写在 JOIN 条件而不是
  // WHERE 里，是为了让每个复用本前缀的查询自动继承，漏不掉。
  static const _selectWithProject =
      'SELECT n.*, c.project_id FROM nodes n '
      'JOIN canvases c ON c.id = n.canvas_id AND c.deleted_at IS NULL';

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'nodes', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectWithProject WHERE n.id = @id AND n.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    return guard('listByCanvas', 'nodes', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectWithProject '
          'WHERE n.canvas_id = @cid AND n.deleted_at IS NULL '
          'ORDER BY n.z_index ASC, n.created_at ASC',
        ),
        parameters: <String, Object?>{'cid': canvasId},
      );
      return allRows(r);
    });
  }

  // 导入的媒体（type_config.origin = import）本来就没有来源配置节点，不是「丢了来源」
  // 的孤儿结果，这里排除掉。
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) {
    return guard('listOrphanResults', 'nodes', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectWithProject '
          'WHERE n.canvas_id = @cid AND n.deleted_at IS NULL '
          "AND n.node_role = 'result' AND n.source_node_id IS NULL "
          "AND COALESCE(n.type_config->>'${ImportKeys.origin}','') "
          "<> '${ImportKeys.originImport}'",
        ),
        parameters: <String, Object?>{'cid': canvasId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'nodes', () async {
      // type_config 若在 patch 里需要显式 JSON 编码。
      final normalized = <String, Object?>{};
      patch.forEach((k, v) {
        if (k == 'type_config' && v is Map<String, Object?>) {
          normalized[k] = jsonEncode(v);
        } else {
          normalized[k] = v;
        }
      });
      final q = buildUpdate('nodes', id, normalized);
      // type_config 参数需要 cast ::jsonb；重写 SQL。
      final finalSql = q.sql.replaceAll(
        'type_config = @p_type_config',
        'type_config = @p_type_config::jsonb',
      );
      final r = await session.execute(Sql.named(finalSql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) {
    return guard('patchTypeConfig', 'nodes', () async {
      // jsonb 合并：type_config = type_config || @patch::jsonb；同时 touch updated_at。
      final r = await session.execute(
        Sql.named(
          'UPDATE nodes SET type_config = type_config || @patch::jsonb, '
          'updated_at = @uat WHERE id = @id AND deleted_at IS NULL',
        ),
        parameters: <String, Object?>{
          'id': id,
          'patch': jsonEncode(patch),
          'uat': utcNowIso(),
        },
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'nodes', () async {
      final q = buildUpdate(
        'nodes',
        id,
        restorePatch(),
        includeDeletedFilter: false,
      );
      final r = await session.execute(Sql.named(q.sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> hardDelete(String id) {
    return guard('hardDelete', 'nodes', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM nodes WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDeleteEmptyOrphanResults() {
    return guard('softDeleteEmptyOrphanResults', 'nodes', () async {
      // LB-14：空 result 壳判据不能只看 3 个 url——批量部分成功后崩溃时主图
      // 可能尚未回写节点，故必须再排除「有 success slot」与「有在途 job」的节点，
      // 否则会误删仍有 slot 产物的节点。status 字面量一律引 LB-01 常量。
      //
      // 导入壳（origin=import）在复制完成前也是「三个 url 皆空」。本清扫挂在任务队列懒启动
      // 的 init 上（会话里第一次点「生成」、DB 恢复后重建队列都会跑），不只在启动时跑，
      // 故排除本次 PG 实例启动之后建的导入壳——它们可能正在复制；之前建的是上次进程崩溃
      // 遗留的空壳，照常收进回收站。created_at 由库端 DEFAULT now() 写，与
      // pg_postmaster_start_time() 同一时钟。
      final r = await session.execute(
        Sql.named(
          'UPDATE nodes SET deleted_at = now(), updated_at = now() '
          "WHERE node_role = 'result' "
          'AND deleted_at IS NULL '
          "AND COALESCE(type_config->>'image_url','') = '' "
          "AND COALESCE(type_config->>'video_url','') = '' "
          "AND COALESCE(type_config->>'thumbnail_url','') = '' "
          "AND NOT (COALESCE(type_config->>'${ImportKeys.origin}','') "
          "= '${ImportKeys.originImport}' "
          'AND created_at >= pg_postmaster_start_time()) '
          'AND NOT EXISTS (SELECT 1 FROM batch_results br '
          "WHERE br.node_id = nodes.id AND br.status = '${SlotStatuses.success}') "
          'AND NOT EXISTS (SELECT 1 FROM jobs j '
          'WHERE j.result_node_id = nodes.id '
          "AND j.status IN ('${JobStatuses.pending}','${JobStatuses.submitted}',"
          "'${JobStatuses.polling}'))",
        ),
      );
      return r.affectedRows;
    });
  }

  @override
  Future<List<String>> listAllMediaUrls() {
    return guard('listAllMediaUrls', 'nodes', () async {
      // LB-13：孤儿回收引用集。**不加 deleted_at 过滤**——软删节点产物仍占盘、
      // 仍可 LB-15 恢复，必须算「被引用」（安全#2）。三个 url 键 UNION 后滤空。
      final r = await session.execute(
        Sql.named(
          'SELECT url FROM ('
          "SELECT type_config->>'image_url' AS url FROM nodes "
          'UNION ALL '
          "SELECT type_config->>'video_url' FROM nodes "
          'UNION ALL '
          "SELECT type_config->>'thumbnail_url' FROM nodes"
          ") t WHERE url IS NOT NULL AND url <> ''",
        ),
      );
      return <String>[
        for (final row in r)
          if (row[0] is String) row[0]! as String,
      ];
    });
  }
}
