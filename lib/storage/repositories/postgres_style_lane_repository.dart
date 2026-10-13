// PostgresStyleLaneRepository —— style_lanes 表实现。
import 'package:postgres/postgres.dart';

import '../../core/constants/lane_defaults.dart';
import '../../core/interfaces/style_lane_repository.dart';
import '../base_repository.dart';

class PostgresStyleLaneRepository
    with BaseRepository
    implements StyleLaneRepository {
  PostgresStyleLaneRepository(this.session);

  @override
  final Session session;

  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = kDefaultLaneSize,
  }) {
    return guard('create', 'style_lanes', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO style_lanes (canvas_id, label, style_prompt, sort_order, tint_color, size) '
          'VALUES (@cid, @lbl, @sp, @so, @tc, @sz) RETURNING id',
        ),
        parameters: <String, Object?>{
          'cid': canvasId,
          'lbl': label,
          'sp': stylePrompt,
          'so': sortOrder,
          'tc': tintColor,
          'sz': size,
        },
      );
      return r.first[0]!.toString();
    });
  }

  // 读路径统一 JOIN canvases 只为过滤画布软删（投影保持 l.*，不带出任何列）。
  // 理由同 postgres_node_repository 的 _selectWithProject：画布软删不级联到
  // style_lanes，只看自身 deleted_at 会把已删画布的泳道读出来。
  static const _selectAlive = 'SELECT l.* FROM style_lanes l '
      'JOIN canvases c ON c.id = l.canvas_id AND c.deleted_at IS NULL';

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'style_lanes', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive WHERE l.id = @id AND l.deleted_at IS NULL',
        ),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    return guard('listByCanvas', 'style_lanes', () async {
      final r = await session.execute(
        Sql.named(
          '$_selectAlive '
          'WHERE l.canvas_id = @cid AND l.deleted_at IS NULL '
          'ORDER BY l.sort_order ASC, l.created_at ASC',
        ),
        parameters: <String, Object?>{'cid': canvasId},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    return guard('update', 'style_lanes', () async {
      final q = buildUpdate('style_lanes', id, patch);
      final r = await session.execute(Sql.named(q.sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  @override
  Future<int> softDelete(String id) => update(id, softDeletePatch());

  @override
  Future<int> restore(String id) {
    return guard('restore', 'style_lanes', () async {
      final q = buildUpdate(
        'style_lanes',
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
    return guard('hardDelete', 'style_lanes', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM style_lanes WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
