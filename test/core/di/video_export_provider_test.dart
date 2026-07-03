// 视频导出 DI 接线冒烟：接口 → 默认实现，locator/runner 可注入可覆盖。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/process_runner.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/services/ffmpeg_video_export_service.dart';
import 'package:inkframe/services/system_process_runner.dart';

void main() {
  test('videoExportServiceProvider 装配 Ffmpeg 实现链', () {
    final container = ProviderContainer(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(
          DefaultAppPaths.forRoot(Directory.systemTemp),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(processRunnerProvider), isA<SystemProcessRunner>());
    expect(container.read(ffmpegLocatorProvider), isA<DefaultFfmpegLocator>());
    expect(
      container.read(videoExportServiceProvider),
      isA<FfmpegVideoExportService>(),
    );
  });
}
