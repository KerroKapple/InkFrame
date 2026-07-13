// CanvasAppearanceSection 测试——色板点选写入控制器并持久化，「主题默认」清空。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/canvas_style.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/settings/widgets/canvas_appearance_section.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppPreferences initial = const AppPreferences(),
  }) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: CanvasAppearanceSection()),
      ),
      overrides: [
        preferencesServiceProvider
            .overrideWithValue(InMemoryPreferencesService(initial)),
      ],
      surfaceSize: const Size(1000, 900),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(CanvasAppearanceSection)),
      listen: false,
    );
  }

  Finder swatchOf(Color c) => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).color == c &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle);

  testWidgets('点连线色板 → 控制器更新并落偏好', (tester) async {
    final container = await pump(tester);
    final target = InkPalette.canvasEdgeColorChoices[1];

    await tester.tap(swatchOf(target));
    await tester.pump();

    expect(container.read(canvasStyleControllerProvider).edgeColor, target);
    expect(
      container.read(preferencesServiceProvider).current.canvasEdgeColor,
      target.toARGB32(),
    );
  });

  testWidgets('点「主题默认」→ 清空回主题', (tester) async {
    final container = await pump(
      tester,
      initial: AppPreferences(
        canvasEdgeColor: InkPalette.canvasEdgeColorChoices[0].toARGB32(),
      ),
    );
    expect(
        container.read(canvasStyleControllerProvider).edgeColor, isNotNull);

    await tester.tap(find.text('Theme default').first);
    await tester.pump();

    expect(container.read(canvasStyleControllerProvider).edgeColor, isNull);
    expect(
      container.read(preferencesServiceProvider).current.canvasEdgeColor,
      isNull,
    );
  });
}
