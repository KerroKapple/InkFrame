// StartupSection 测试——开关自偏好播种、拨动即落盘，且【不清】会话记录。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/settings/widgets/startup_section.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../_harness/test_app.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppPreferences initial = const AppPreferences(),
  }) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: StartupSection())),
      overrides: [
        preferencesServiceProvider
            .overrideWithValue(InMemoryPreferencesService(initial)),
      ],
      surfaceSize: const Size(1000, 600),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(StartupSection)),
      listen: false,
    );
  }

  testWidgets('默认开：开关自偏好播种为 on', (tester) async {
    await pump(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('偏好为 false → 开关播种为 off', (tester) async {
    await pump(tester,
        initial: const AppPreferences(shellKeepLastCanvas: false));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('关掉开关 → 落偏好 false，但 lastCanvasId/lastProjectId 不动',
      (tester) async {
    final container = await pump(
      tester,
      initial: const AppPreferences(lastCanvasId: 'cv1', lastProjectId: 'p1'),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    final prefs = container.read(preferencesServiceProvider).current;
    expect(prefs.shellKeepLastCanvas, isFalse);
    expect(prefs.lastCanvasId, 'cv1', reason: '关开关 ≠ 清记录');
    expect(prefs.lastProjectId, 'p1', reason: '关开关 ≠ 清记录');
  });
}
