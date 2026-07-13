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

  test('onboardingCompleted 默认 false + toMap/fromMap 往返 + 容错', () {
    expect(const AppPreferences().onboardingCompleted, isFalse);

    const done = AppPreferences(onboardingCompleted: true);
    expect(AppPreferences.fromMap(done.toMap()), done);
    expect(AppPreferences.fromMap(done.toMap()).onboardingCompleted, isTrue);

    // 类型错/缺失 → 退 false
    final bad = AppPreferences.fromMap(<String, Object?>{
      'onboarding_completed': 'yes',
    });
    expect(bad.onboardingCompleted, isFalse);

    // copyWith 置位
    expect(
      const AppPreferences().copyWith(onboardingCompleted: true)
          .onboardingCompleted,
      isTrue,
    );
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

  test('更新检查字段默认值：开关默认开、时间戳空', () {
    const p = AppPreferences();
    expect(p.updateCheckEnabled, isTrue);
    expect(p.lastUpdateCheckAtIso, isNull);
  });

  test('更新检查字段 toMap/fromMap 往返', () {
    const p = AppPreferences(
      updateCheckEnabled: false,
      lastUpdateCheckAtIso: '2026-07-09T08:00:00.000Z',
    );
    expect(AppPreferences.fromMap(p.toMap()), p);
  });

  test('更新检查字段 fromMap 容错：类型错/缺失 → 默认', () {
    final p = AppPreferences.fromMap(<String, Object?>{
      'update_check_enabled': 'yes', // 类型错
      'last_update_check_at': 42, // 类型错
    });
    expect(p.updateCheckEnabled, isTrue);
    expect(p.lastUpdateCheckAtIso, isNull);
  });

  test('copyWith 更新检查字段', () {
    const p = AppPreferences();
    final q = p.copyWith(
      updateCheckEnabled: false,
      lastUpdateCheckAtIso: '2026-07-09T08:00:00.000Z',
    );
    expect(q.updateCheckEnabled, isFalse);
    expect(q.lastUpdateCheckAtIso, '2026-07-09T08:00:00.000Z');
    // 不传时保留原值。
    expect(q.copyWith().lastUpdateCheckAtIso, '2026-07-09T08:00:00.000Z');
  });

  test('画布颜色字段默认 null（跟随主题），toMap/fromMap 往返', () {
    const p = AppPreferences();
    expect(p.canvasEdgeColor, isNull);
    expect(p.canvasCardColor, isNull);

    const q = AppPreferences(
      canvasEdgeColor: 0xFFE8A87C,
      canvasCardColor: 0xFF20262E,
    );
    expect(AppPreferences.fromMap(q.toMap()), q);
  });

  test('画布颜色 fromMap 容错：类型错 → null', () {
    final p = AppPreferences.fromMap(<String, Object?>{
      'canvas_edge_color': '#fff',
      'canvas_card_color': true,
    });
    expect(p.canvasEdgeColor, isNull);
    expect(p.canvasCardColor, isNull);
  });

  test('copyWith 画布颜色：设值 / clear 标志清空 / 不传保留', () {
    const p = AppPreferences(canvasEdgeColor: 1, canvasCardColor: 2);
    expect(p.copyWith().canvasEdgeColor, 1);
    expect(p.copyWith(canvasEdgeColor: 3).canvasEdgeColor, 3);
    expect(p.copyWith(clearCanvasEdgeColor: true).canvasEdgeColor, isNull);
    expect(p.copyWith(clearCanvasCardColor: true).canvasCardColor, isNull);
    // clear 只影响对应字段。
    expect(p.copyWith(clearCanvasEdgeColor: true).canvasCardColor, 2);
  });
}
