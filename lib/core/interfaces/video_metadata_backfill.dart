// 存量视频元数据回填（XM-1b）的查询契约。
//
// XM-1（#177）只做了写侧：新生成的视频落库时带 duration_ms/width/height；
// 之前生成的存量视频缺这些键，Gallery 时长恒占位。本接口枚举待回填候选，
// 独立小接口而非并入 NodeRepository——回填是一次性 housekeeping 查询，
// 不该让全部 NodeRepository fake 陪着实现（ISP；胖接口债见 AUDIT P1-18）。

/// 待回填候选：一个缺 duration_ms 的 video result 节点。
class VideoBackfillCandidate {
  const VideoBackfillCandidate({
    required this.nodeId,
    required this.projectId,
    required this.canvasId,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  final String nodeId;
  final String projectId;
  final String canvasId;

  /// canvas 相对路径（videos/...）。
  final String videoUrl;

  /// 已有缩略图相对路径；null = 连缩略图也缺（回填时顺带补）。
  final String? thumbnailUrl;
}

abstract class VideoMetadataBackfillRepository {
  /// 枚举缺 duration_ms 的活体 video result 节点（含所属 project/canvas）。
  Future<List<VideoBackfillCandidate>> listMissingDuration({int limit = 50});
}
