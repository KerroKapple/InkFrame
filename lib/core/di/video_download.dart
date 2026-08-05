// VideoDownloadService 的 Riverpod DI。
//
// app-scoped：dio 在 app 退出时关闭，供 JobQueueService 共用。

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/dio_video_download_service.dart';
import '../interfaces/video_download_service.dart';
import '../net/proxy_env.dart';

final videoDownloadServiceProvider = Provider<VideoDownloadService>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
  applyEnvProxy(dio); // LB-24：产物下载与生成链路同过代理
  ref.onDispose(dio.close);
  return DioVideoDownloadService(dio);
});
