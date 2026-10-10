// 截图试跑一屏（BOARD「把截图流程搬进 widget test」那条：先出一屏）。
//
// 跑法：
//   flutter test --tags screenshot test/screenshots/
// 产物落在 build/screenshots/（gitignored），或用 --dart-define=INKFRAME_SHOT_DIR=... 指路。
//
// 默认被 `--exclude-tags golden` 之外的普通跑**也带上**——所以本文件打了
// screenshot tag 并在找不到真中文字体时 skip，不会在别人机器上平白多出文件。
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';

import '../_harness/fake_secure_storage.dart';
import '../_harness/screenshot.dart';

void main() {
  // 字体必须在 setUpAll 里装：testWidgets 的闭包跑在 FakeAsync 区内，
  // 真实文件 I/O 的 Future 在那里永远不会完成——直接挂到超时（踩过一次，10 分钟）。
  String? font;
  setUpAll(() async {
    font = await loadRealCjkFont();
  });

  testWidgets('Studio 首页截图（1600×1000，中文）', (tester) async {
    if (font == null) {
      markTestSkipped('本机没有可用的中文字体，跳过——出一张方框图比没有图更坏');
      return;
    }

    await pumpScreenshotScene(
      tester,
      const StudioHomeScreen(),
      size: const Size(1600, 1000),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
      ],
    );

    final file = await captureToPng(
      tester,
      kScreenshotBoundary,
      '$screenshotDir/studio_home.png',
    );

    // 只钉「真的出了一张像样的图」，不比对像素——比对是 golden 的事。
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10 * 1024),
        reason: '不到 10KB 多半是整屏纯色，说明根本没渲出来');
    // ignore: avoid_print
    print('截图已落盘：${file.path}（字体 $font）');
  });
}
