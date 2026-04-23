// DioVideoDownloadService：覆盖 200 字节一致 + 404 抛 VideoDownloadError。
//
// 用 http_mock_adapter 拦截 dio 请求，不打真 socket。

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/interfaces/video_download_service.dart';
import 'package:inkframe/services/dio_video_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late Directory tmp;

  setUp(() async {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    tmp = await Directory.systemTemp.createTemp('video_dl_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('下载 200 → 文件落盘字节一致', () async {
    final bytes = Uint8List.fromList(List<int>.generate(256, (i) => i));
    adapter.onGet(
      'https://fake/video.mp4',
      (s) => s.reply(200, bytes, headers: {
        'content-type': ['video/mp4'],
      }),
    );

    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'out.mp4'));
    final result = await svc.download(
      url: 'https://fake/video.mp4',
      destination: dst,
    );

    expect(await result.readAsBytes(), bytes);
  });

  test('下载 404 → VideoDownloadError(404)', () async {
    adapter.onGet('https://fake/miss.mp4', (s) => s.reply(404, 'nope'));

    final svc = DioVideoDownloadService(dio);
    await expectLater(
      () => svc.download(
        url: 'https://fake/miss.mp4',
        destination: File(p.join(tmp.path, 'x.mp4')),
      ),
      throwsA(
        isA<VideoDownloadError>().having((e) => e.httpStatus, 'status', 404),
      ),
    );
  });
}
