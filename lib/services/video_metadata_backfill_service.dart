// VideoMetadataBackfillService：存量视频元数据回填（XM-1b）。
//
// XM-1（#177）写侧只覆盖新生成的视频；之前的存量视频缺 duration_ms/width/height，
// Gallery 时长恒占位。本服务在启动 housekeeping 期扫描候选（缺 duration_ms 的
// 活体 video result 节点），逐条经 ThumbnailService 探针补写 type_config；
// 缺缩略图的顺带补 thumbnail_url（复用与 JobMediaPersister 相同的首帧抽取）。
//
// 失败策略：逐条兜底——文件缺失 / 越界路径 / 探针失败只记日志跳过，下条继续；
// 探针拿不到任何元数据的行不写键（下次启动重试，个人规模可接受）。
// 稳态（无候选）只花一条 SQL，无需节流标记。
import 'package:path/path.dart' as p;

import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/thumbnail_service.dart';
import '../core/interfaces/video_metadata_backfill.dart';
import '../core/logging/logger_service.dart';

/// 日志 module 名（内部标识，English-only）。
const String kVideoBackfillModule = 'video.backfill';

class VideoMetadataBackfillService {
  VideoMetadataBackfillService({
    required VideoMetadataBackfillRepository backfillRepo,
    required NodeRepository nodeRepo,
    required FileResolverService fileResolver,
    required ThumbnailService thumbnail,
    required LoggerService logger,
  })  : _backfillRepo = backfillRepo,
        _nodeRepo = nodeRepo,
        _fileResolver = fileResolver,
        _thumbnail = thumbnail,
        _logger = logger;

  final VideoMetadataBackfillRepository _backfillRepo;
  final NodeRepository _nodeRepo;
  final FileResolverService _fileResolver;
  final ThumbnailService _thumbnail;
  final LoggerService _logger;

  /// 跑一轮回填，返回成功补写的节点数。
  Future<int> run({int limit = 50}) async {
    final candidates = await _backfillRepo.listMissingDuration(limit: limit);
    if (candidates.isEmpty) return 0;

    var patched = 0;
    for (final c in candidates) {
      try {
        patched += await _backfillOne(c) ? 1 : 0;
      } on PathSecurityError catch (e) {
        _logger.warn(kVideoBackfillModule, 'path rejected', extra: {
          'node': c.nodeId,
          'error': e.toString(),
        });
      } on ThumbnailError catch (e) {
        _logger.warn(kVideoBackfillModule, 'probe failed', extra: {
          'node': c.nodeId,
          'error': e.toString(),
        });
      }
    }
    _logger.info(kVideoBackfillModule, 'backfill round done', extra: {
      'candidates': candidates.length,
      'patched': patched,
    });
    return patched;
  }

  Future<bool> _backfillOne(VideoBackfillCandidate c) async {
    final video = _fileResolver.resolve(
      projectId: c.projectId,
      canvasId: c.canvasId,
      relativePath: c.videoUrl,
    );
    if (!await video.exists()) {
      _logger.warn(kVideoBackfillModule, 'video file missing', extra: {
        'node': c.nodeId,
        'path': c.videoUrl,
      });
      return false;
    }

    // 缺缩略图 → 与写侧同目录同名派生（videos/<name>.jpg）；已有 → 原路径重写
    // 同一首帧，幂等。
    final thumbRel = c.thumbnailUrl ?? _deriveThumbRel(c.videoUrl);
    final thumbFile = _fileResolver.resolve(
      projectId: c.projectId,
      canvasId: c.canvasId,
      relativePath: thumbRel,
    );
    final probe = await _thumbnail.extractFirstFrame(
      videoPath: video.path,
      destination: thumbFile,
    );

    final patch = <String, Object?>{
      if (c.thumbnailUrl == null) 'thumbnail_url': thumbRel,
      // 与写侧同规：仅非空且 >0 才写，防 0/null 垃圾键。
      if (probe.durationMs case final int v when v > 0) 'duration_ms': v,
      if (probe.width case final int v when v > 0) 'width': v,
      if (probe.height case final int v when v > 0) 'height': v,
    };
    if (patch.isEmpty) {
      _logger.warn(kVideoBackfillModule, 'probe yielded no metadata', extra: {
        'node': c.nodeId,
      });
      return false;
    }
    await _nodeRepo.patchTypeConfig(c.nodeId, patch);
    return true;
  }

  static String _deriveThumbRel(String videoUrl) =>
      p.setExtension(videoUrl, '.jpg');
}
