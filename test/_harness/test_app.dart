// 统一的 widget test 启动器：MaterialApp + ProviderScope + l10n delegates 一站式装配。
//
// 所有 InkFrame widget test 都走 pumpInkApp。手写 MaterialApp / 重复 delegates 视为反模式。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

/// 标准 widget test 启动器。
///
/// - [overrides]: ProviderScope override 列表
/// - [variant]: 主题变体（默认 dark）
/// - [textScale]: 文字缩放
/// - [locale]: 默认 en；多语言断言时传 Locale('zh')
/// - [surfaceSize]: 自定义窗口大小，自动 tearDown
Future<void> pumpInkApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  InkThemeVariant variant = InkThemeVariant.dark,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: variant, textScale: textScale),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}
