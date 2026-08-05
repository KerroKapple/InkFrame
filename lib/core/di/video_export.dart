// 视频导出 DI —— app-scoped：ffmpeg 探测 + concat 导出服务。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ffmpeg_locator.dart';
import '../../services/ffmpeg_video_export_service.dart';
import '../interfaces/video_export_service.dart';
import 'clock.dart';
import 'file_resolver.dart';
import 'logger.dart';
import 'process_runner.dart';

final ffmpegLocatorProvider = Provider<FfmpegLocator>(
  (ref) => DefaultFfmpegLocator(runner: ref.watch(processRunnerProvider)),
  name: 'ffmpegLocatorProvider',
);

final videoExportServiceProvider = Provider<VideoExportService>(
  (ref) => FfmpegVideoExportService(
    fileResolver: ref.watch(fileResolverServiceProvider),
    ffmpegLocator: ref.watch(ffmpegLocatorProvider),
    processStarter: ref.watch(processStarterProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  ),
  name: 'videoExportServiceProvider',
);
