// PostgresProjectArchiveReader —— LB-11 导出专用全保真只读（含软删；见接口注释）。
import 'package:postgres/postgres.dart';

import '../../core/constants/job_statuses.dart';
import '../../core/interfaces/project_archive_reader.dart';
import '../base_repository.dart';

class PostgresProjectArchiveReader
    with BaseRepository
    implements ProjectArchiveReader {
  PostgresProjectArchiveReader(this.session);

  @override
  final Session session;

  /// 「项目下拥有 ≥1 success slot 的 jobs」共享子句（jobs 过滤与 slot 全带复用）。
  /// 状态值来自 const 常量（单一真相源），无注入面；projectId 走 @p 参数。
  static const String _successJobsFrom =
      'FROM jobs j JOIN canvases c ON c.id = j.canvas_id '
      'WHERE c.project_id = @p AND EXISTS ('
      'SELECT 1 FROM batch_results s '
      "WHERE s.job_id = j.id AND s.status = '${SlotStatuses.success}')";

  Future<List<Map<String, Object?>>> _rows(String sql, String projectId) {
    return guard('archiveRead', 'project_archive', () async {
      final r = await session.execute(
        Sql.named(sql),
        parameters: <String, Object?>{'p': projectId},
      );
      return allRows(r);
    });
  }

  @override
  Future<Map<String, Object?>?> projectRow(String projectId) {
    return guard('archiveRead', 'projects', () async {
      final r = await session.execute(
        Sql.named('SELECT * FROM projects WHERE id = @p'),
        parameters: <String, Object?>{'p': projectId},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> canvasRows(String projectId) => _rows(
        'SELECT * FROM canvases WHERE project_id = @p ORDER BY created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> nodeRows(String projectId) => _rows(
        'SELECT n.* FROM nodes n JOIN canvases c ON c.id = n.canvas_id '
        'WHERE c.project_id = @p ORDER BY n.created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> edgeRows(String projectId) => _rows(
        'SELECT e.* FROM edges e JOIN canvases c ON c.id = e.canvas_id '
        'WHERE c.project_id = @p ORDER BY e.created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> laneRows(String projectId) => _rows(
        'SELECT l.* FROM style_lanes l JOIN canvases c ON c.id = l.canvas_id '
        'WHERE c.project_id = @p ORDER BY l.created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> characterRows(String projectId) => _rows(
        'SELECT * FROM characters WHERE project_id = @p ORDER BY created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> presetRows(String projectId) => _rows(
        'SELECT * FROM prompt_presets WHERE project_id = @p '
        'ORDER BY created_at',
        projectId,
      );

  @override
  Future<List<Map<String, Object?>>> successJobRows(String projectId) =>
      _rows('SELECT j.* $_successJobsFrom ORDER BY j.created_at', projectId);

  @override
  Future<List<Map<String, Object?>>> batchResultRows(String projectId) =>
      _rows(
        'SELECT br.* FROM batch_results br WHERE br.job_id IN '
        '(SELECT j.id $_successJobsFrom) '
        'ORDER BY br.job_id, br.slot_index',
        projectId,
      );
}
