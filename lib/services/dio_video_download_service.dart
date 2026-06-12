// DioVideoDownloadService：基于 dio 的 VideoDownloadService 实现。
//
// 流式落盘（dio.download），不整文件缓冲内存。
// 失败路径统一抛 VideoDownloadError：非 https / 非 2xx / 空体 /
// 文本型 content-type（疑似错误页）/ 超大小上限。
// 上层 JobQueueService 负责把异常翻译成 ProviderError / LocalIOError。

import 'dart:io';

import 'package:dio/dio.dart';

import '../core/interfaces/video_download_service.dart';

class DioVideoDownloadService implements VideoDownloadService {
  DioVideoDownloadService(this._dio, {int maxBytes = kDefaultMaxBytes})
      : _maxBytes = maxBytes;

  /// 单个视频下载上限（2 GiB）——超过视为异常响应而非合法素材。
  static const int kDefaultMaxBytes = 2 * 1024 * 1024 * 1024;

  final Dio _dio;
  final int _maxBytes;

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw VideoDownloadError(url: url, httpStatus: -1);
    }
    await destination.parent.create(recursive: true);
    final cancelToken = CancelToken();
    final Response<dynamic> response;
    try {
      response = await _dio.download(
        url,
        destination.path,
        cancelToken: cancelToken,
        options: Options(
          validateStatus: (s) => s != null && s ~/ 100 == 2,
        ),
        onReceiveProgress: (received, total) {
          // 边收边卡上限：声明的 total 或已收字节超限立即取消。
          if (received > _maxBytes || total > _maxBytes) {
            cancelToken.cancel();
          }
        },
      );
    } on DioException catch (e) {
      await _deleteIfExists(destination);
      throw VideoDownloadError(
        url: url,
        httpStatus: e.response?.statusCode ?? -1,
      );
    }
    final status = response.statusCode ?? -1;
    final contentType = (response.headers.value(Headers.contentTypeHeader) ??
            '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    final length = destination.existsSync() ? destination.lengthSync() : 0;
    // 空体 / 文本型响应（多为伪装成 2xx 的错误页）/ 超限兜底。
    if (length == 0 ||
        length > _maxBytes ||
        contentType.startsWith('text/') ||
        contentType.endsWith('json') ||
        contentType.endsWith('xml')) {
      await _deleteIfExists(destination);
      throw VideoDownloadError(url: url, httpStatus: status);
    }
    return destination;
  }

  /// Windows 上取消下载后 dio 的文件句柄释放有延迟，删除需短暂重试。
  Future<void> _deleteIfExists(File f) async {
    for (var i = 0; i < 5; i++) {
      try {
        if (f.existsSync()) f.deleteSync();
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}
