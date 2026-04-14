// PostgresBatchResultRepository —— batch_results 表实现。
import 'package:postgres/postgres.dart';

import '../../core/interfaces/batch_result_repository.dart';
import '../base_repository.dart';

class PostgresBatchResultRepository
    with BaseRepository
    implements BatchResultRepository {
  PostgresBatchResultRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String nodeId,
    required String jobId,
    required int slotIndex,
    required String status,
  }) async {
    final r = await session.execute(
      Sql.named(
        'INSERT INTO batch_results (node_id, job_id, slot_index, status) '
        'VALUES (@nid, @jid, @si, @st) RETURNING id',
      ),
      parameters: <String, Object?>{
        'nid': nodeId,
        'jid': jobId,
        'si': slotIndex,
        'st': status,
      },
    );
    return r.first[0]!.toString();
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final r = await session.execute(
      Sql.named('SELECT * FROM batch_results WHERE id = @id'),
      parameters: <String, Object?>{'id': id},
    );
    return firstRow(r);
  }

  @override
  Future<Map<String, Object?>?> findBySlot(
    String nodeId,
    int slotIndex,
  ) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM batch_results WHERE node_id = @nid AND slot_index = @si',
      ),
      parameters: <String, Object?>{'nid': nodeId, 'si': slotIndex},
    );
    return firstRow(r);
  }

  @override
  Future<List<Map<String, Object?>>> listByNode(String nodeId) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM batch_results WHERE node_id = @nid '
        'ORDER BY slot_index ASC',
      ),
      parameters: <String, Object?>{'nid': nodeId},
    );
    return allRows(r);
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (patch.isEmpty) return 0;
    final setParts = <String>[];
    final params = <String, Object?>{'id': id};
    patch.forEach((k, v) {
      final p = 'p_$k';
      setParts.add('$k = @$p');
      params[p] = v;
    });
    final r = await session.execute(
      Sql.named('UPDATE batch_results SET ${setParts.join(', ')} WHERE id = @id'),
      parameters: params,
    );
    return r.affectedRows;
  }

  @override
  Future<int> markPromoted({
    required String id,
    required String promotedNodeId,
  }) async {
    final r = await session.execute(
      Sql.named(
        'UPDATE batch_results SET promoted = true, promoted_node_id = @pnid '
        'WHERE id = @id',
      ),
      parameters: <String, Object?>{'id': id, 'pnid': promotedNodeId},
    );
    return r.affectedRows;
  }

  @override
  Future<int> hardDelete(String id) async {
    final r = await session.execute(
      Sql.named('DELETE FROM batch_results WHERE id = @id'),
      parameters: <String, Object?>{'id': id},
    );
    return r.affectedRows;
  }
}
