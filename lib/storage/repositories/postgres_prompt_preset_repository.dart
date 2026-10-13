// PostgresPromptPresetRepository —— prompt_presets 表实现（全 TEXT，无 JSONB）。
import 'package:postgres/postgres.dart';

import '../../core/interfaces/prompt_preset_repository.dart';
import '../base_repository.dart';

class PostgresPromptPresetRepository
    with BaseRepository
    implements PromptPresetRepository {
  PostgresPromptPresetRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String projectId,
    String name = '',
    String prompt = '',
    String prefix = '',
    String suffix = '',
    String negative = '',
    int sortOrder = 0,
  }) {
    return guard('create', 'prompt_presets', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO prompt_presets '
          '(project_id, name, prompt, prefix, suffix, negative, sort_order) '
          'VALUES (@pid, @name, @prompt, @prefix, @suffix, @neg, @so) RETURNING id',
        ),
        parameters: <String, Object?>{
          'pid': projectId,
          'name': name,
          'prompt': prompt,
          'prefix': prefix,
          'suffix': suffix,
          'neg': negative,
          'so': sortOrder,
        },
      );
      return r.first[0]!.toString();
    });
  }

  /// 活项目下的预设读前缀。理由与 `postgres_canvas_repository._selectAlive`
  /// 同一条：项目软删不级联到 prompt_presets，过滤只能在读路径上做，且写在
  /// **JOIN 条件**而非 WHERE——复用本前缀的查询自动继承。投影 `pp.*` 与
  /// 原来的 `SELECT *` 逐列相同，行形状不变。
  static const _selectAlive = 'SELECT pp.* FROM prompt_presets pp '
      'JOIN projects p ON p.id = pp.project_id AND p.deleted_at IS NULL';

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'prompt_presets', () async {
      final r = await session.execute(
        Sql.named('$_selectAlive WHERE pp.id = @id AND pp.deleted_at IS NULL'),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) {
    return guard('listByProject', 'prompt_presets', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE pp.project_id = @pid AND pp.deleted_at IS NULL '
          'ORDER BY pp.sort_order ASC, pp.created_at ASC',
        ),
        parameters: <String, Object?>{'pid': projectId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'prompt_presets', () async {
      final q = buildUpdate('prompt_presets', id, patch);
      final r = await session.execute(Sql.named(q.sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'prompt_presets', () async {
      final q = buildUpdate(
        'prompt_presets',
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
    return guard('hardDelete', 'prompt_presets', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM prompt_presets WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
