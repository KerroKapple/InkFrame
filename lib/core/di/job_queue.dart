import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/job_queue_service.dart';
import '../../services/job_queue_service.dart';
import 'providers.dart';
import 'thumbnail.dart';
import 'video_download.dart';

/// app-scoped 单例：JobQueueService 横跨所有项目和画布（PRD §10.7）。
///
/// b1 阶段使用内存调度器；b2 子步换接持久化 + 启动恢复版本时只改本 provider。
///
/// T5-S3：注入 VideoDownloadService + ThumbnailService，让异步 Provider 通过
/// JobSuccess.remoteUrls 下载到本地；thumbnail 可选（S3 为 null → 跳过抽帧，
/// S4 换 MediaKitThumbnailService）。
final jobQueueServiceProvider = Provider<JobQueueService>((ref) {
  final registry = ref.watch(providerRegistryProvider);
  final downloader = ref.watch(videoDownloadServiceProvider);
  final thumbnail = ref.watch(thumbnailServiceProvider);
  final service = InMemoryJobQueueService(
    registry: registry,
    videoDownloader: downloader,
    thumbnailService: thumbnail,
  );
  ref.onDispose(service.dispose);
  return service;
});
