// PostgresNodeRepository —— nodes 表实现。
import 'dart:convert';

import 'package:postgres/postgres.dart';

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

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'nodes', () async {
      final r = await session.execute(
        Sql.named('SELECT * FROM nodes WHERE id = @id AND deleted_at IS NULL'),
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
          'SELECT * FROM nodes WHERE canvas_id = @cid AND deleted_at IS NULL '
          'ORDER BY z_index ASC, created_at ASC',
        ),
        parameters: <String, Object?>{'cid': canvasId},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) {
    return guard('listOrphanResults', 'nodes', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM nodes WHERE canvas_id = @cid AND deleted_at IS NULL '
          "AND node_role = 'result' AND source_node_id IS NULL",
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
}
