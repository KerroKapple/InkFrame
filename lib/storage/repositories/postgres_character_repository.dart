// PostgresCharacterRepository —— characters 表实现。
// reference_image_paths 为 JSONB：绑定 jsonEncode(list) + @param::jsonb（对齐 nodes.type_config）。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/db/columns.dart';
import '../../core/interfaces/character_repository.dart';
import '../base_repository.dart';

class PostgresCharacterRepository
    with BaseRepository
    implements CharacterRepository {
  PostgresCharacterRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String projectId,
    String name = '',
    List<String> referenceImagePaths = const <String>[],
    String description = '',
    int sortOrder = 0,
  }) {
    return guard('create', 'characters', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO characters '
          '(project_id, name, reference_image_paths, description, sort_order) '
          'VALUES (@pid, @name, @refs::jsonb, @desc, @so) RETURNING id',
        ),
        parameters: <String, Object?>{
          'pid': projectId,
          'name': name,
          'refs': jsonEncode(referenceImagePaths),
          'desc': description,
          'so': sortOrder,
        },
      );
      return r.first[0]!.toString();
    });
  }

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'characters', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM characters WHERE id = @id AND deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) {
    return guard('listByProject', 'characters', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM characters WHERE project_id = @pid AND deleted_at IS NULL '
          'ORDER BY sort_order ASC, created_at ASC',
        ),
        parameters: <String, Object?>{'pid': projectId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'characters', () async {
      // reference_image_paths 若在 patch 里，需 JSON 编码 + ::jsonb cast。
      final normalized = <String, Object?>{};
      patch.forEach((k, v) {
        if (k == CharacterCol.referenceImagePaths && v is List) {
          normalized[k] = jsonEncode(v);
        } else {
          normalized[k] = v;
        }
      });
      final q = buildUpdate('characters', id, normalized);
      final finalSql = q.sql.replaceAll(
        'reference_image_paths = @p_reference_image_paths',
        'reference_image_paths = @p_reference_image_paths::jsonb',
      );
      final r = await session.execute(Sql.named(finalSql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'characters', () async {
      final q = buildUpdate(
        'characters',
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
    return guard('hardDelete', 'characters', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM characters WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
