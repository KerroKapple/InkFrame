import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/window_bounds.dart';

void main() {
  test('默认值', () {
    const p = AppPreferences();
    expect(p.themePreference, 'dark');
    expect(p.highContrast, false);
    expect(p.textScale, 1.0);
    expect(p.localeCode, isNull);
    expect(p.windowBounds, isNull);
    expect(p.windowMaximized, false);
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

  test('上次会话字段 toMap/fromMap 往返', () {
    const p = AppPreferences(
      lastImageProviderId: 'gemini-image',
      lastVideoProviderId: 'wanx-i2v',
      lastCanvasId: 'cv1',
      lastProjectId: 'p1',
    );
    expect(AppPreferences.fromMap(p.toMap()), p);
  });

  test('上次会话字段 fromMap 容错：类型错/缺失 → null', () {
    final p = AppPreferences.fromMap(<String, Object?>{
      'last_image_provider_id': 42, // 类型错
      'last_canvas_id': true, // 类型错
      // 其余缺失
    });
    expect(p.lastImageProviderId, isNull);
    expect(p.lastVideoProviderId, isNull);
    expect(p.lastCanvasId, isNull);
    expect(p.lastProjectId, isNull);
  });

  test('copyWith clearLastCanvas 同时清画布与项目，不动 provider 记忆', () {
    const p = AppPreferences(
      lastImageProviderId: 'gemini-image',
      lastCanvasId: 'cv1',
      lastProjectId: 'p1',
    );
    final cleared = p.copyWith(clearLastCanvas: true);
    expect(cleared.lastCanvasId, isNull);
    expect(cleared.lastProjectId, isNull);
    expect(cleared.lastImageProviderId, 'gemini-image');
  });

  test('窗口状态字段 toMap/fromMap 往返', () {
    const p = AppPreferences(
      windowBounds: WindowBounds(x: 100, y: 200, width: 1280, height: 720),
      windowMaximized: true,
    );
    expect(AppPreferences.fromMap(p.toMap()), p);
  });

  test('窗口状态字段 fromMap 容错：损坏 bounds/类型错 → null/false', () {
    final p = AppPreferences.fromMap(<String, Object?>{
      'window_bounds': <String, Object?>{'x': 1}, // 缺字段
      'window_maximized': 'yes', // 类型错
    });
    expect(p.windowBounds, isNull);
    expect(p.windowMaximized, false);
  });

  test('copyWith 更新窗口状态', () {
    const p = AppPreferences();
    final updated = p.copyWith(
      windowBounds: const WindowBounds(x: 0, y: 0, width: 800, height: 600),
      windowMaximized: true,
    );
    expect(updated.windowBounds,
        const WindowBounds(x: 0, y: 0, width: 800, height: 600));
    expect(updated.windowMaximized, true);
    // 不传则保持原值。
    expect(updated.copyWith().windowBounds, updated.windowBounds);
    expect(updated.copyWith().windowMaximized, true);
  });
}
