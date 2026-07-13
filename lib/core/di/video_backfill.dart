// 存量视频元数据回填 DI + 启动触发（XM-1b）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/video_metadata_backfill_service.dart';
import '../../storage/repositories/postgres_video_backfill_repository.dart';
import '../interfaces/video_metadata_backfill.dart';
import 'database.dart';
import 'file_resolver.dart';
import 'logger.dart';
import 'repositories.dart';
import 'thumbnail.dart';

final videoBackfillRepositoryProvider =
    FutureProvider<VideoMetadataBackfillRepository>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresVideoBackfillRepository(pool);
}, name: 'videoBackfillRepositoryProvider');

/// 启动首帧后触发一轮存量回填。housekeeping：任何失败只 warn，绝不阻断启动。
/// 平台无缩略图能力（thumbnailServiceProvider 为 null）→ 直接跳过。
final videoBackfillStartupProvider = FutureProvider<void>((ref) async {
  final logger = ref.watch(loggerProvider);
  try {
    final thumbnail = ref.watch(thumbnailServiceProvider);
    if (thumbnail == null) return;
    final service = VideoMetadataBackfillService(
      backfillRepo: await ref.watch(videoBackfillRepositoryProvider.future),
      nodeRepo: await ref.watch(nodeRepositoryProvider.future),
      fileResolver: ref.watch(fileResolverServiceProvider),
      thumbnail: thumbnail,
      logger: logger,
    );
    await service.run();
  } catch (e, st) {
    // ── 放行点（sanctioned swallow）─────────────────────────────────────────
    // 与 orphanReapStartupProvider 同级的启动 housekeeping 全捕获吞点：
    // 任何失败（InkError 或逻辑异常）只 warn，下次启动再试，异常绝不逃逸。
    logger.warn(
      kVideoBackfillModule,
      'video.backfill.failed',
      extra: <String, Object?>{
        'error': e.toString(),
        'stack': st.toString(),
      },
    );
  }
}, name: 'videoBackfillStartupProvider');
