// Shell 路由 widget test：验证 _UnlockedShell 在 currentScreenProvider 切换时
// 正确渲染 StudioHomeScreen / SettingsScreen。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/features/gallery/providers/current_gallery_project.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:postgres/postgres.dart';

import '../_harness/fake_batch_result.dart';
import '../_harness/fake_repositories.dart';

/// 密封 LB-09 的 DB-ready gate：pgMigratedPoolProvider 停在 loading，_StartupGate
/// 照常进 _UnlockedShell，boot 测试不触发真 PG/dart:io（否则覆盖率收集永挂）。
Override _sealDbReady() =>
    pgMigratedPoolProvider.overrideWith((ref) => Completer<Pool<void>>().future);

Future<AppPaths> _setupPaths(WidgetTester tester, String prefix) async {
  final Directory tmp = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => tmp.deleteSync(recursive: true));
  final AppPaths paths = DefaultAppPaths.forRoot(tmp);
  await tester.runAsync(() => paths.ensureInitialized());
  return paths;
}

/// 本文件只测路由，非首启路径：跳过 ON-1 向导。
Override _onboardingDone() => preferencesServiceProvider.overrideWithValue(
      InMemoryPreferencesService(
        const AppPreferences(onboardingCompleted: true),
      ),
    );

/// 固定命中的 ffmpeg 探测（ON-3 行在 SettingsScreen 内,禁真 spawn）。
class _FakeFfmpegLocator implements FfmpegLocator {
  @override
  Future<String?> locate() async => 'ffmpeg';
  @override
  void invalidate() {}
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
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.studio),
          currentCanvasIdProvider.overrideWith((_) => null),
          // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io（否则 coverage 收集永挂）。
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          // 密封：boot 渲染唯一碰 DB 的链路，断在此处——避免真起内嵌 PG。
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
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
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.settings),
          currentCanvasIdProvider.overrideWith((_) => null),
          // 密封 ON-3 ffmpeg 探测：不真 spawn `ffmpeg -version`。
          ffmpegLocatorProvider.overrideWithValue(_FakeFfmpegLocator()),
          // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io（否则 coverage 收集永挂）。
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          // 密封：boot 渲染唯一碰 DB 的链路，断在此处——避免真起内嵌 PG。
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(StudioHomeScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('unlocked + gallery target → 渲染 GalleryScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_gallery_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.studio),
          currentCanvasIdProvider.overrideWith((_) => null),
          // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io（否则 coverage 收集永挂）。
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          currentGalleryProjectProvider
              .overrideWith((_) => (id: 'p1', name: 'Alpha')),
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
          // 密封：画廊读仓储不真起内嵌 PG。
          canvasRepositoryProvider
              .overrideWith((_) async => InMemoryCanvasRepository()),
          nodeRepositoryProvider
              .overrideWith((_) async => InMemoryNodeRepository()),
          batchResultRepositoryProvider
              .overrideWith((_) async => FakeBatchResultRepo()),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(find.byType(StudioHomeScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
