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
  }) {
    return guard('create', 'canvases', () async {
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
    });
  }

  /// 活项目下的画布读前缀。
  ///
  /// JOIN 条件上的 `p.deleted_at IS NULL` 不是装饰：项目软删【不级联】到
  /// canvases（`projects.softDelete` 只碰 projects 那一行），所以只过滤
  /// `c.deleted_at` 的读路径会把回收站里项目的画布照常读出来。与 #254 的
  /// 画布→子表那一层同一手法：过滤写在 **JOIN 条件**而非 WHERE，让每个复用
  /// 本前缀的查询自动继承，漏不掉。
  ///
  /// 投影是 `c.*`——与改之前的 `SELECT *` 逐列相同，调用方看到的行形状不变
  /// （不像 nodes 那条还要带出 `c.project_id`；canvases 自己就有这一列）。
  /// 列名一律限定：JOIN 之后 `created_at` / `name` / `id` / `deleted_at` 在
  /// 两张表里都存在，裸写会被 PG 判 ambiguous。
  static const _selectAlive = 'SELECT c.* FROM canvases c '
      'JOIN projects p ON p.id = c.project_id AND p.deleted_at IS NULL';

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'canvases', () async {
      final r = await session.execute(
        Sql.named('$_selectAlive WHERE c.id = @id AND c.deleted_at IS NULL'),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) {
    return guard('listByProject', 'canvases', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE c.project_id = @pid AND c.deleted_at IS NULL '
          'ORDER BY c.created_at ASC',
        ),
        parameters: <String, Object?>{'pid': projectId},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) {
    return guard('listByProjects', 'canvases', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE c.project_id = ANY(@pids) AND c.deleted_at IS NULL '
          'ORDER BY c.project_id ASC, c.created_at ASC',
        ),
        parameters: <String, Object?>{'pids': projectIds},
      );
      return allRows(r);
    });
  }

  /// 【刻意不 JOIN projects】回收站是软删行的唯一出口。要求"项目必须活"会让
  /// 「项目和画布都在回收站」时那些画布再也取不回来——比它要防的洞坏得多。
  /// 守这条的是 repository_sql_templates_test 里的反向护栏。
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) {
    return guard('listTrashedByProject', 'canvases', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM canvases WHERE project_id = @pid '
          'AND deleted_at IS NOT NULL ORDER BY deleted_at DESC',
        ),
        parameters: <String, Object?>{'pid': projectId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'canvases', () async {
      final q = buildUpdate('canvases', id, patch);
      final r = await session.execute(Sql.named(q.sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'canvases', () async {
      final q = buildUpdate(
        'canvases',
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
    return guard('hardDelete', 'canvases', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM canvases WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
