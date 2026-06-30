// 主题/语言控制器：build 从持久化偏好 seed + 改动落回 preferences。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/locale.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/theme.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  ({ProviderContainer c, InMemoryPreferencesService svc}) build(
    AppPreferences seed,
  ) {
    final svc = InMemoryPreferencesService(seed);
    final c = ProviderContainer(overrides: [
      preferencesServiceProvider.overrideWithValue(svc),
    ]);
    addTearDown(c.dispose);
    return (c: c, svc: svc);
  }

  test('Theme：build 从偏好 seed（highContrast 覆盖 light）', () {
    final (:c, :svc) = build(const AppPreferences(
      themePreference: 'light',
      highContrast: true,
      textScale: 1.25,
    ));
    final state = c.read(themeModeControllerProvider);
    expect(state.variant, InkThemeVariant.highContrast);
    expect(state.textScale, 1.25);
  });

  test('Theme：build 从偏好 seed（light，无对比度）', () {
    final (:c, :svc) = build(const AppPreferences(themePreference: 'light'));
    expect(c.read(themeModeControllerProvider).variant, InkThemeVariant.light);
  });

  test('Theme：setPreference / setTextScale 落到 preferences', () {
    final (:c, :svc) = build(const AppPreferences());
    c
        .read(themeModeControllerProvider.notifier)
        .setPreference(ThemePreference.light);
    expect(svc.current.themePreference, 'light');
    c.read(themeModeControllerProvider.notifier).setTextScale(1.4);
    expect(svc.current.textScale, 1.4);
  });

  test('Locale：build seed + setLocale 落盘 + 清空', () {
    final (:c, :svc) = build(const AppPreferences(localeCode: 'zh'));
    expect(c.read(localeControllerProvider)?.languageCode, 'zh');

    c.read(localeControllerProvider.notifier).setLocale(const Locale('en'));
    expect(svc.current.localeCode, 'en');

    c.read(localeControllerProvider.notifier).setLocale(null);
    expect(svc.current.localeCode, isNull);
  });
}
