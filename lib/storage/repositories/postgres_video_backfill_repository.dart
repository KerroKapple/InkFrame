// PostgresVideoBackfillRepository —— 存量视频元数据回填候选查询（XM-1b）。
import 'package:postgres/postgres.dart';

import '../../core/interfaces/video_metadata_backfill.dart';
import '../base_repository.dart';

class PostgresVideoBackfillRepository
    with BaseRepository
    implements VideoMetadataBackfillRepository {
  PostgresVideoBackfillRepository(this.session);

  @override
  final Session session;

  @override
  Future<List<VideoBackfillCandidate>> listMissingDuration({int limit = 50}) {
    return guard('listMissingDuration', 'nodes', () async {
      // 活体 video result 节点，有 video_url 但缺 duration_ms。
      // join canvases 拿 project_id（文件解析需要 project/canvas 双 id），
      // 并带 c.deleted_at IS NULL：画布软删不级联到 nodes，不过滤就会去探测
      // 已删画布的视频文件、再把 duration_ms 写回它的节点（白跑 + 多余 I/O 报错）。
      final r = await session.execute(
        Sql.named(
          'SELECT n.id, c.project_id, n.canvas_id, '
          "n.type_config->>'video_url', n.type_config->>'thumbnail_url' "
          'FROM nodes n '
          'JOIN canvases c ON c.id = n.canvas_id AND c.deleted_at IS NULL '
          "WHERE n.node_role = 'result' "
          'AND n.deleted_at IS NULL '
          "AND COALESCE(n.type_config->>'video_url', '') <> '' "
          "AND n.type_config->>'duration_ms' IS NULL "
          'ORDER BY n.created_at LIMIT @limit',
        ),
        parameters: <String, Object?>{'limit': limit},
      );
      return <VideoBackfillCandidate>[
        for (final row in r)
          VideoBackfillCandidate(
            nodeId: row[0].toString(),
            projectId: row[1].toString(),
            canvasId: row[2].toString(),
            videoUrl: row[3]! as String,
            thumbnailUrl: row[4] as String?,
          ),
      ];
    });
  }
}
