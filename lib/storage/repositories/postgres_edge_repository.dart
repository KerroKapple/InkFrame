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
  }) async {
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
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final r = await session.execute(
      Sql.named('SELECT * FROM edges WHERE id = @id AND deleted_at IS NULL'),
      parameters: <String, Object?>{'id': id},
    );
    return firstRow(r);
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM edges WHERE canvas_id = @cid AND deleted_at IS NULL '
        'ORDER BY sort_order ASC, created_at ASC',
      ),
      parameters: <String, Object?>{'cid': canvasId},
    );
    return allRows(r);
  }

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM edges WHERE source_node_id = @sid AND deleted_at IS NULL',
      ),
      parameters: <String, Object?>{'sid': sourceNodeId},
    );
    return allRows(r);
  }

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM edges WHERE target_node_id = @tid AND deleted_at IS NULL',
      ),
      parameters: <String, Object?>{'tid': targetNodeId},
    );
    return allRows(r);
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    // edges 表没有 updated_at 列；withUpdatedAt 不适用——直接 patch。
    if (patch.isEmpty) return 0;
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
  }

  @override
  Future<int> softDelete(String id) async {
    final r = await session.execute(
      Sql.named(
        'UPDATE edges SET deleted_at = @dat WHERE id = @id AND deleted_at IS NULL',
      ),
      parameters: <String, Object?>{'id': id, 'dat': utcNowIso()},
    );
    return r.affectedRows;
  }

  @override
  Future<int> restore(String id) async {
    final r = await session.execute(
      Sql.named('UPDATE edges SET deleted_at = NULL WHERE id = @id'),
      parameters: <String, Object?>{'id': id},
    );
    return r.affectedRows;
  }

  @override
  Future<int> hardDelete(String id) async {
    final r = await session.execute(
      Sql.named('DELETE FROM edges WHERE id = @id'),
      parameters: <String, Object?>{'id': id},
    );
    return r.affectedRows;
  }
}
