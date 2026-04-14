// PostgresCanvasRepository —— canvases 表实现。
import 'package:postgres/postgres.dart';

import '../../core/interfaces/canvas_repository.dart';
import '../base_repository.dart';

class PostgresCanvasRepository with BaseRepository implements CanvasRepository {
  PostgresCanvasRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async {
    final r = await session.execute(
      Sql.named(
        'INSERT INTO canvases (project_id, name, base_style_prefix, base_style_suffix) '
        'VALUES (@pid, @name, @pre, @suf) RETURNING id',
      ),
      parameters: <String, Object?>{
        'pid': projectId,
        'name': name,
        'pre': baseStylePrefix,
        'suf': baseStyleSuffix,
      },
    );
    return r.first[0]!.toString();
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final r = await session.execute(
      Sql.named('SELECT * FROM canvases WHERE id = @id AND deleted_at IS NULL'),
      parameters: <String, Object?>{'id': id},
    );
    return firstRow(r);
  }

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async {
    final r = await session.execute(
      Sql.named(
        'SELECT * FROM canvases WHERE project_id = @pid AND deleted_at IS NULL '
        'ORDER BY created_at ASC',
      ),
      parameters: <String, Object?>{'pid': projectId},
    );
    return allRows(r);
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final q = buildUpdate('canvases', id, patch);
    final r = await session.execute(Sql.named(q.sql), parameters: q.params);
    return r.affectedRows;
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) async {
    final q = buildUpdate(
      'canvases',
      id,
      restorePatch(),
      includeDeletedFilter: false,
    );
    final r = await session.execute(Sql.named(q.sql), parameters: q.params);
    return r.affectedRows;
  }

  @override
  Future<int> hardDelete(String id) async {
    final r = await session.execute(
      Sql.named('DELETE FROM canvases WHERE id = @id'),
      parameters: <String, Object?>{'id': id},
    );
    return r.affectedRows;
  }
}
