// DioVideoDownloadService：基于 dio 的 VideoDownloadService 实现。
//
// 只处理"下载到指定路径 + 非 2xx 抛 VideoDownloadError"两件事。
// 上层 JobQueueService 负责把异常翻译成 ProviderError / LocalIOError。

import 'dart:io';

import 'package:dio/dio.dart';

import '../core/interfaces/video_download_service.dart';

class DioVideoDownloadService implements VideoDownloadService {
  DioVideoDownloadService(this._dio);

  final Dio _dio;

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    try {
      await destination.parent.create(recursive: true);
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode;
      if (status == null || status ~/ 100 != 2) {
        throw VideoDownloadError(url: url, httpStatus: status ?? -1);
      }
      final data = response.data;
      final List<int> bytes;
      if (data is List<int>) {
        bytes = data;
      } else if (data is List) {
        bytes = data.cast<int>();
      } else {
        bytes = const <int>[];
      }
      await destination.writeAsBytes(bytes, flush: true);
      return destination;
    } on DioException catch (e) {
      throw VideoDownloadError(
        url: url,
        httpStatus: e.response?.statusCode ?? -1,
      );
    }
  }
}
