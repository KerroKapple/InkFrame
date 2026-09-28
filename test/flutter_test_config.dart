// 全局 test 启动钩子：每个 test isolate 跑前加载真实字体。
//
// Flutter golden test 默认用 Ahem font（方块字），typography 回归丢失。
// loadAppFonts() 来自 golden_toolkit：扫描 pubspec assets 注册的字体文件
// 并装载到测试 Skia 实例（含 golden_toolkit 自带的 Roboto，作为 Material 默认族）。
//
// 【Noto Sans SC 别名】界面字体 Noto Sans SC 刻意不打包（typography.dart 头注），
// 生产环境走系统回落链；但测试 Skia 里它是未知族 ⇒ 落到 Ahem 方块字（每字 1em 宽），
// 所有依赖文字宽度的布局断言与 golden 都会随之漂移。这里把 Roboto 的字节再以
// 'Noto Sans SC' 为族名装载一次，让测试度量与 V0 之前「null 族 → Roboto」完全一致。
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await _aliasUiFontToRoboto();
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // CI / 本地用同一份基线 png，禁用 host-only 跳过
      skipGoldenAssertion: () => false,
      enableRealShadows: true,
    ),
  );
}

Future<void> _aliasUiFontToRoboto() async {
  final FontLoader loader = FontLoader('Noto Sans SC')
    ..addFont(rootBundle.load('packages/golden_toolkit/fonts/Roboto-Regular.ttf'));
  await loader.load();
}
