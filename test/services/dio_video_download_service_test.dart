// DioVideoDownloadService：覆盖 200 字节一致 / 404 / 空体 / 非视频类型 /
// 非 https / 超大小上限 各失败路径。
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
    // Windows 句柄延迟释放，删除临时目录需重试。
    for (var i = 0; i < 10; i++) {
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
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

  test('下载 404 → VideoDownloadError(404)，不留残文件', () async {
    adapter.onGet('https://fake/miss.mp4', (s) => s.reply(404, 'nope'));

    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'x.mp4'));
    await expectLater(
      () => svc.download(url: 'https://fake/miss.mp4', destination: dst),
      throwsA(
        isA<VideoDownloadError>().having((e) => e.httpStatus, 'status', 404),
      ),
    );
    expect(dst.existsSync(), isFalse);
  });

  test('200 空体 → VideoDownloadError，不留 0 字节文件', () async {
    adapter.onGet(
      'https://fake/empty.mp4',
      (s) => s.reply(200, Uint8List(0), headers: {
        'content-type': ['video/mp4'],
      }),
    );

    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'empty.mp4'));
    await expectLater(
      () => svc.download(url: 'https://fake/empty.mp4', destination: dst),
      throwsA(
        isA<VideoDownloadError>().having((e) => e.httpStatus, 'status', 200),
      ),
    );
    expect(dst.existsSync(), isFalse);
  });

  test('200 但 content-type 是 text/html → VideoDownloadError', () async {
    adapter.onGet(
      'https://fake/errpage.mp4',
      (s) => s.reply(200, '<html>oops</html>', headers: {
        'content-type': ['text/html; charset=utf-8'],
      }),
    );

    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'errpage.mp4'));
    await expectLater(
      () => svc.download(url: 'https://fake/errpage.mp4', destination: dst),
      throwsA(isA<VideoDownloadError>()),
    );
    expect(dst.existsSync(), isFalse);
  });

  test('非 https URL → VideoDownloadError，不发请求', () async {
    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'plain.mp4'));
    await expectLater(
      () => svc.download(url: 'http://fake/plain.mp4', destination: dst),
      throwsA(
        isA<VideoDownloadError>().having((e) => e.httpStatus, 'status', -1),
      ),
    );
    expect(dst.existsSync(), isFalse);
  });

  test('畸形 URL → VideoDownloadError(-1)', () async {
    final svc = DioVideoDownloadService(dio);
    await expectLater(
      () => svc.download(
        url: '::not a url::',
        destination: File(p.join(tmp.path, 'bad.mp4')),
      ),
      throwsA(
        isA<VideoDownloadError>().having((e) => e.httpStatus, 'status', -1),
      ),
    );
  });

  test('超过大小上限 → VideoDownloadError，不留残文件', () async {
    final bytes = Uint8List.fromList(List<int>.filled(1024, 7));
    adapter.onGet(
      'https://fake/big.mp4',
      (s) => s.reply(200, bytes, headers: {
        'content-type': ['video/mp4'],
      }),
    );

    final svc = DioVideoDownloadService(dio, maxBytes: 512);
    final dst = File(p.join(tmp.path, 'big.mp4'));
    await expectLater(
      () => svc.download(url: 'https://fake/big.mp4', destination: dst),
      throwsA(isA<VideoDownloadError>()),
    );
    expect(dst.existsSync(), isFalse);
  });
}
