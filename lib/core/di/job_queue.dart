import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/job_queue_service.dart';
import '../../services/job_queue_service.dart';
import 'file_resolver.dart';
import 'logger.dart';
import 'providers.dart';
import 'repositories.dart';
import 'thumbnail.dart';
import 'video_download.dart';

/// app-scoped 单例：JobQueueService 横跨所有项目和画布（PRD §10.7）。
///
/// 持久化版：注入 JobRepository + NodeRepository + FileResolverService，解析时
/// 调用 init() 做启动恢复（孤儿 submitted/polling → cancelled）。repo 依赖内嵌
/// PG（async），故本 provider 为 FutureProvider；首次被 await 时触发 PG 启动 +
/// schema migrate。VideoDownload/Thumbnail 仍按 T5-S3 注入（thumbnail 可空）。
final jobQueueServiceProvider = FutureProvider<JobQueueService>((ref) async {
  final registry = ref.watch(providerRegistryProvider);
  final downloader = ref.watch(videoDownloadServiceProvider);
  final thumbnail = ref.watch(thumbnailServiceProvider);
  final repo = await ref.watch(jobRepositoryProvider.future);
  final nodeRepo = await ref.watch(nodeRepositoryProvider.future);
  final fileResolver = ref.watch(fileResolverServiceProvider);
  final service = InMemoryJobQueueService(
    registry: registry,
    repo: repo,
    fileResolver: fileResolver,
    nodeRepo: nodeRepo,
    videoDownloader: downloader,
    thumbnailService: thumbnail,
    logger: ref.watch(loggerProvider),
  );
  await service.init();
  ref.onDispose(service.dispose);
  return service;
});
