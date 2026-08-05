// 真 ffmpeg 集成测（仿 pg 集成测的 env 门控模式）：
//   TEST_FFMPEG=1 flutter test --tags ffmpeg test/services/ffmpeg_concat_integration_test.dart
// 未设置 TEST_FFMPEG 或本机无 ffmpeg 时 skip，不阻塞默认测试运行。
@Tags(<String>['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/services/ffmpeg_video_export_service.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/system_process_runner.dart';

/// 门控 + 素材准备：返回 null 表示应 skip（原因已 markTestSkipped）。
Future<
    ({
      DefaultFileResolverService resolver,
      FfmpegVideoExportService svc,
      Directory tempRoot,
    })?> _setUpRealFfmpeg() async {
  if (Platform.environment['TEST_FFMPEG'] != '1') {
    markTestSkipped('TEST_FFMPEG 未设置，跳过真 ffmpeg 集成测试');
    return null;
  }
  const runner = SystemProcessRunner();
  final locator = DefaultFfmpegLocator(runner: runner);
  final ffmpeg = await locator.locate();
  if (ffmpeg == null) {
    markTestSkipped('本机无可用 ffmpeg，跳过');
    return null;
  }

  final tempRoot = await Directory.systemTemp.createTemp('ffmpeg_it_');
  final paths = DefaultAppPaths.forRoot(tempRoot);
  await paths.ensureInitialized();
  final resolver = DefaultFileResolverService(paths);

  for (final name in <String>['a.mp4', 'b.mp4']) {
    final f = resolver.resolveInProject(
      projectId: 'p1',
      relativePath: 'canvases/c1/videos/$name',
    )..parent.createSync(recursive: true);
    final gen = await runner.run(ffmpeg, <String>[
      '-f', 'lavfi',
      '-i', 'testsrc=duration=1:size=128x72:rate=10',
      '-pix_fmt', 'yuv420p',
      '-y', f.path,
    ]);
    expect(gen.exitCode, 0, reason: gen.stderr.toString());
  }

  final svc = FfmpegVideoExportService(
    fileResolver: resolver,
    ffmpegLocator: locator,
    processStarter: runner,
  );
  return (resolver: resolver, svc: svc, tempRoot: tempRoot);
}

void main() {
  test('concat 用真 ffmpeg 拼接两段 testsrc 视频 + 进度收口到 1.0', () async {
    final env = await _setUpRealFfmpeg();
    if (env == null) return;
    try {
      final seen = <double>[];
      final rel = await env.svc.concat(
        projectId: 'p1',
        inputRelativePaths: const <String>[
          'canvases/c1/videos/a.mp4',
          'canvases/c1/videos/b.mp4',
        ],
        outputBaseName: 'joined',
        totalDurationMs: 2000,
        onProgress: seen.add,
      );

      expect(rel, 'exports/joined.mp4');
      final out =
          env.resolver.resolveInProject(projectId: 'p1', relativePath: rel);
      expect(out.existsSync(), isTrue);
      expect(out.lengthSync(), greaterThan(0));

      // 真 -progress 流：至少一次回调、单调、终值 1.0。
      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
    } finally {
      if (env.tempRoot.existsSync()) {
        await env.tempRoot.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('取消：预取消 token → 真进程被 kill，CancelledError 且无产物残留', () async {
    final env = await _setUpRealFfmpeg();
    if (env == null) return;
    try {
      final token = ExportCancelToken()..cancel();

      await expectLater(
        env.svc.concat(
          projectId: 'p1',
          inputRelativePaths: const <String>[
            'canvases/c1/videos/a.mp4',
            'canvases/c1/videos/b.mp4',
          ],
          outputBaseName: 'cancelled',
          cancelToken: token,
        ),
        throwsA(isA<CancelledError>()),
      );

      final out = env.resolver.resolveInProject(
        projectId: 'p1',
        relativePath: 'exports/cancelled.mp4',
      );
      expect(out.existsSync(), isFalse, reason: '取消不留半成品');
    } finally {
      if (env.tempRoot.existsSync()) {
        await env.tempRoot.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
