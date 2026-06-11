// PostgresProjectRepository —— projects 表实现。
import 'package:postgres/postgres.dart';

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
      final q = buildUpdate('projects', id, patch);
      final r = await session.execute(Sql.named(q.sql), parameters: q.params);
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
