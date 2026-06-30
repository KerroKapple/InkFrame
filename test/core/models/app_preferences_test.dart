import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/app_preferences.dart';

void main() {
  test('默认值', () {
    const p = AppPreferences();
    expect(p.themePreference, 'dark');
    expect(p.highContrast, false);
    expect(p.textScale, 1.0);
    expect(p.localeCode, isNull);
  });

  test('toMap/fromMap 往返', () {
    const p = AppPreferences(
      themePreference: 'light',
      highContrast: true,
      textScale: 1.25,
      localeCode: 'zh',
    );
    expect(AppPreferences.fromMap(p.toMap()), p);
  });

  test('fromMap 容错：缺失/非法/类型错 → 退默认', () {
    final p = AppPreferences.fromMap(<String, Object?>{
      'theme_preference': 'neon', // 非法值
      'high_contrast': 'yes', // 类型错
      'text_scale': null,
      // locale_code 缺失
    });
    expect(p.themePreference, 'dark');
    expect(p.highContrast, false);
    expect(p.textScale, 1.0);
    expect(p.localeCode, isNull);
  });

  test('copyWith clearLocale 清空语言', () {
    const p = AppPreferences(localeCode: 'en');
    expect(p.copyWith(clearLocale: true).localeCode, isNull);
    expect(p.copyWith(localeCode: 'zh').localeCode, 'zh');
  });
}
