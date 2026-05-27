// 全局 test 启动钩子：每个 test isolate 跑前加载真实字体。
//
// Flutter golden test 默认用 Ahem font（方块字），typography 回归丢失。
// loadAppFonts() 来自 golden_toolkit：扫描 pubspec assets 注册的字体文件
// 并装载到测试 Skia 实例。
import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // CI / 本地用同一份基线 png，禁用 host-only 跳过
      skipGoldenAssertion: () => false,
      enableRealShadows: true,
    ),
  );
}
