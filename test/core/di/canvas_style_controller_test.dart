// CanvasStyleController 单测——偏好 seed / setter 持久化 / 清空回默认。
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/canvas_style.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/services/file_preferences_service.dart';

void main() {
  ProviderContainer build(AppPreferences initial) {
    final container = ProviderContainer(overrides: <Override>[
      preferencesServiceProvider
          .overrideWithValue(InMemoryPreferencesService(initial)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('启动从偏好 seed；无偏好 → 双 null（跟随主题）', () {
    final c = build(const AppPreferences());
    final s = c.read(canvasStyleControllerProvider);
    expect(s.edgeColor, isNull);
    expect(s.cardColor, isNull);

    final seeded = build(
      const AppPreferences(canvasEdgeColor: 0xFFE8A87C),
    );
    expect(
      seeded.read(canvasStyleControllerProvider).edgeColor,
      const Color(0xFFE8A87C),
    );
  });

  test('setEdgeColor / setCardColor 更新状态并落盘', () async {
    final c = build(const AppPreferences());
    final ctrl = c.read(canvasStyleControllerProvider.notifier);

    ctrl.setEdgeColor(const Color(0xFF7CB8E8));
    ctrl.setCardColor(const Color(0xFF20262E));
    await Future<void>.delayed(Duration.zero);

    final s = c.read(canvasStyleControllerProvider);
    expect(s.edgeColor, const Color(0xFF7CB8E8));
    expect(s.cardColor, const Color(0xFF20262E));

    final persisted = c.read(preferencesServiceProvider).current;
    expect(persisted.canvasEdgeColor, 0xFF7CB8E8);
    expect(persisted.canvasCardColor, 0xFF20262E);
  });

  test('setEdgeColor(null) 清空并从偏好移除', () async {
    final c = build(const AppPreferences(canvasEdgeColor: 0xFF7CB8E8));
    final ctrl = c.read(canvasStyleControllerProvider.notifier);

    ctrl.setEdgeColor(null);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(canvasStyleControllerProvider).edgeColor, isNull);
    expect(c.read(preferencesServiceProvider).current.canvasEdgeColor, isNull);
  });
}
