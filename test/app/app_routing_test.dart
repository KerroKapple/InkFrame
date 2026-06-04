// Shell 路由 widget test：验证 _UnlockedShell 在 currentScreenProvider 切换时
// 正确渲染 StudioHomeScreen / SettingsScreen。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';

Future<AppPaths> _setupPaths(WidgetTester tester, String prefix) async {
  final Directory tmp = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => tmp.deleteSync(recursive: true));
  final AppPaths paths = DefaultAppPaths.forRoot(tmp);
  await tester.runAsync(() => paths.ensureInitialized());
  return paths;
}

void main() {
  testWidgets('unlocked + studio screen → 渲染 StudioHomeScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_studio_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.studio),
          currentCanvasIdProvider.overrideWith((_) => null),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(StudioHomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('unlocked + settings screen → 渲染 SettingsScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_settings_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.settings),
          currentCanvasIdProvider.overrideWith((_) => null),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(StudioHomeScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
