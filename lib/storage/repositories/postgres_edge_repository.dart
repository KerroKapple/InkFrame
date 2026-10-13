// PostgresEdgeRepository —— edges 表实现。
import 'package:postgres/postgres.dart';

import '../../core/interfaces/edge_repository.dart';
import '../base_repository.dart';

class PostgresEdgeRepository with BaseRepository implements EdgeRepository {
  PostgresEdgeRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) {
    return guard('create', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO edges (canvas_id, source_node_id, target_node_id, edge_type, role, sort_order) '
          'VALUES (@cid, @src, @tgt, @type, @role, @so) RETURNING id',
        ),
        parameters: <String, Object?>{
          'cid': canvasId,
          'src': sourceNodeId,
          'tgt': targetNodeId,
          'type': edgeType,
          'role': role,
          'so': sortOrder,
        },
      );
      return r.first[0]!.toString();
    });
  }

  // 读路径统一 JOIN canvases 只为过滤画布软删（不带出任何列——投影保持 e.*，
  // 行形状与过去逐字节相同）。理由同 postgres_node_repository 的 _selectWithProject：
  // 画布软删不级联到 edges，只看 edges 自身 deleted_at 会把已删画布的边读出来。
  static const _selectAlive = 'SELECT e.* FROM edges e '
      'JOIN canvases c ON c.id = e.canvas_id AND c.deleted_at IS NULL';

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive WHERE e.id = @id AND e.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    return guard('listByCanvas', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE e.canvas_id = @cid AND e.deleted_at IS NULL '
          'ORDER BY e.sort_order ASC, e.created_at ASC',
        ),
        parameters: <String, Object?>{'cid': canvasId},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) {
    return guard('listOutgoing', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE e.source_node_id = @sid AND e.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'sid': sourceNodeId},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) {
    return guard('listIncoming', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE e.target_node_id = @tid AND e.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'tid': targetNodeId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    // edges 表没有 updated_at 列；withUpdatedAt 不适用——直接 patch。
    if (patch.isEmpty) return Future.value(0);
    return guard('update', 'edges', () async {
      final setParts = <String>[];
      final params = <String, Object?>{'id': id};
      patch.forEach((k, v) {
        final p = 'p_$k';
        setParts.add('$k = @$p');
        params[p] = v;
      });
      final r = await session.execute(
        Sql.named(
          'UPDATE edges SET ${setParts.join(', ')} '
          'WHERE id = @id AND deleted_at IS NULL',
        ),
        parameters: params,
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) {
    return guard('softDelete', 'edges', () async {
      final r = await session.execute(
        Sql.named(
          'UPDATE edges SET deleted_at = @dat WHERE id = @id AND deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id, 'dat': utcNowIso()},
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> restore(String id) {
    return guard('restore', 'edges', () async {
      final r = await session.execute(
        Sql.named('UPDATE edges SET deleted_at = NULL WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> hardDelete(String id) {
    return guard('hardDelete', 'edges', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM edges WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
