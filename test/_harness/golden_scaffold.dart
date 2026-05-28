// Golden test 专用启动器：固定 surface size + 真实字体 + 主题装配。
//
// 与 pumpInkApp 区别：
//   - 不接 ProviderScope override 默认值（golden 测视觉，少有 DI 注入需求）
//   - 默认 Scaffold(body: Center(child: child))，避免 SUT 顶满 surface 难看
//   - 固定 surface size 避免不同机器 device pixel ratio 差异
//
// 字体由 test/flutter_test_config.dart 全局 loadAppFonts() 加载，本文件不重复。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

/// 装配标准 golden scene：固定 size、暗主题、l10n delegates、Scaffold 居中。
Future<void> pumpGoldenScene(
  WidgetTester tester,
  Widget child, {
  required Size size,
  List<Override> overrides = const <Override>[],
  InkThemeVariant variant = InkThemeVariant.dark,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: variant, textScale: 1),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  // 等动画/AnimatedContainer settle，避免 golden 抓到过渡帧
  await tester.pumpAndSettle();
}
