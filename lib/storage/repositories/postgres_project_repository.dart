// PostgresProjectRepository —— projects 表实现。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/db/columns.dart';
import '../../core/interfaces/project_repository.dart';
import '../base_repository.dart';

class PostgresProjectRepository with BaseRepository implements ProjectRepository {
  PostgresProjectRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({required String name, String? coverNodeId}) {
    return guard('create', 'projects', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO projects (name, cover_node_id) VALUES (@name, @cover) '
          'RETURNING id',
        ),
        parameters: <String, Object?>{
          'name': name,
          'cover': coverNodeId,
        },
      );
      return r.first[0]!.toString();
    });
  }

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'projects', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM projects WHERE id = @id AND deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listAll() {
    return guard('listAll', 'projects', () async {
      final r = await session.execute(
        'SELECT * FROM projects WHERE deleted_at IS NULL '
        'ORDER BY created_at DESC',
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listTrashed() {
    return guard('listTrashed', 'projects', () async {
      final r = await session.execute(
        'SELECT * FROM projects WHERE deleted_at IS NOT NULL '
        'ORDER BY deleted_at DESC',
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'projects', () async {
      // delivery_settings 是 JSONB：Map 要先显式 JSON 编码，参数再 cast ::jsonb，
      // 否则驱动会按文本列发过去、PG 报类型不符（nodes.type_config 同样处理）。
      final normalized = <String, Object?>{
        for (final MapEntry<String, Object?> e in patch.entries)
          e.key: e.key == ProjectCol.deliverySettings &&
                  e.value is Map<String, Object?>
              ? jsonEncode(e.value)
              : e.value,
      };
      final q = buildUpdate('projects', id, normalized);
      final sql = q.sql.replaceAll(
        '${ProjectCol.deliverySettings} = @p_${ProjectCol.deliverySettings}',
        '${ProjectCol.deliverySettings} = @p_${ProjectCol.deliverySettings}::jsonb',
      );
      final r = await session.execute(Sql.named(sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'projects', () async {
      final q = buildUpdate(
        'projects',
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
    return guard('hardDelete', 'projects', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM projects WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
