// VideoDownloadService 抽象：把远端 URL 下载为本地文件。
//
// 抽接口而不是直接用 dio：
//   1. 单测可 Fake；
//   2. 未来可以切 native downloader / 分片下载，不需要改 JobQueueService。
//
// 故意不继承 InkError —— 本层只关心 HTTP 失败细节；向上由
// JobQueueService 翻译成 ProviderError / LocalIOError。

import 'dart:io';

abstract class VideoDownloadService {
  /// 把 [url] 下载到 [destination]。成功返回写好字节的文件。
  /// HTTP 非 2xx / DioException → 抛 [VideoDownloadError]。
  Future<File> download({required String url, required File destination});
}

/// 本 service 独有的失败信号——名字刻意和 ink_error.DownloadError 区分，
/// 避免在 _persistRemoteUrls 同时 import 两者时 class 冲突。
class VideoDownloadError implements Exception {
  const VideoDownloadError({required this.url, required this.httpStatus});
  final String url;
  final int httpStatus;

  @override
  String toString() => 'VideoDownloadError(url=$url, httpStatus=$httpStatus)';
}
