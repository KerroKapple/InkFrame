// PostgresProjectArchiveReader —— LB-11 导出专用全保真只读（含软删；见接口注释）。
//
// 9 张表在单 REPEATABLE READ 事务内读出：同一快照保证 FK 闭包不被导出期间的
// 并发写（JobQueue 在跑）撕开（#188 评审 P2-3）。
import 'package:postgres/postgres.dart';

import '../../core/constants/job_statuses.dart';
import '../../core/interfaces/project_archive_reader.dart';
import '../base_repository.dart';

class PostgresProjectArchiveReader
    with BaseRepository
    implements ProjectArchiveReader {
  /// [session] 需同时是 [SessionExecutor]（Pool / Connection 均满足）——
  /// 快照读要开显式事务。
  PostgresProjectArchiveReader(this.session)
      : assert(session is SessionExecutor);

  @override
  final Session session;

  /// 「项目下拥有 ≥1 success slot 的 jobs」共享子句（jobs 过滤与 slot 全带复用）。
  /// 状态值来自 const 常量（单一真相源），无注入面；projectId 走 @p 参数。
  static const String _successJobsFrom =
      'FROM jobs j JOIN canvases c ON c.id = j.canvas_id '
      'WHERE c.project_id = @p AND EXISTS ('
      'SELECT 1 FROM batch_results s '
      "WHERE s.job_id = j.id AND s.status = '${SlotStatuses.success}')";

  @override
  Future<ProjectArchiveSnapshot> snapshot(String projectId) {
    return guard('snapshot', 'project_archive', () async {
      return (session as SessionExecutor).runTx<ProjectArchiveSnapshot>(
        (tx) async {
          Future<List<Map<String, Object?>>> rows(String sql) async {
            final r = await tx.execute(
              Sql.named(sql),
              parameters: <String, Object?>{'p': projectId},
            );
            return allRows(r);
          }

          final projectRows =
              await rows('SELECT * FROM projects WHERE id = @p');
          return (
            project: projectRows.isEmpty ? null : projectRows.first,
            canvases: await rows(
              'SELECT * FROM canvases WHERE project_id = @p '
              'ORDER BY created_at, id',
            ),
            nodes: await rows(
              'SELECT n.* FROM nodes n JOIN canvases c ON c.id = n.canvas_id '
              'WHERE c.project_id = @p ORDER BY n.created_at, n.id',
            ),
            edges: await rows(
              'SELECT e.* FROM edges e JOIN canvases c ON c.id = e.canvas_id '
              'WHERE c.project_id = @p ORDER BY e.created_at, e.id',
            ),
            lanes: await rows(
              'SELECT l.* FROM style_lanes l '
              'JOIN canvases c ON c.id = l.canvas_id '
              'WHERE c.project_id = @p ORDER BY l.created_at, l.id',
            ),
            characters: await rows(
              'SELECT * FROM characters WHERE project_id = @p '
              'ORDER BY created_at, id',
            ),
            presets: await rows(
              'SELECT * FROM prompt_presets WHERE project_id = @p '
              'ORDER BY created_at, id',
            ),
            jobs: await rows(
              'SELECT j.* $_successJobsFrom ORDER BY j.created_at, j.id',
            ),
            batchResults: await rows(
              'SELECT br.* FROM batch_results br WHERE br.job_id IN '
              '(SELECT j.id $_successJobsFrom) '
              'ORDER BY br.job_id, br.slot_index',
            ),
          );
        },
        settings: TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );
    });
  }
}
