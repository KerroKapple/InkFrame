// 外壳级 widget test 启动器。
//
// 两条硬纪律：
// 1. orphanReapStartupProvider 必须与 pgMigratedPoolProvider【分开单独 override】
//    ——前者直接 await nodeRepositoryProvider，不吃 pool 封印。
// 2. 全外壳测试【禁止 pumpAndSettle】，只固定次数 pump()
//    ——StoragePathSection 留 pending frame。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/interfaces/custom_provider_store.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/ink_shell.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:postgres/postgres.dart';

import 'fake_batch_result.dart';
import 'fake_repositories.dart';

/// 固定命中的 ffmpeg 探测（ON-3 行在 SettingsScreen 内，禁真 spawn）。
class FakeFfmpegLocator implements FfmpegLocator {
  @override
  Future<String?> locate() async => 'ffmpeg';
  @override
  void invalidate() {}
}

/// 恒空的自定义服务商 store（GAP-1 区在 SettingsScreen 内）。
class EmptyCustomProviderStore implements CustomProviderStore {
  const EmptyCustomProviderStore();
  @override
  Future<List<CustomProviderConfig>> list() async =>
      const <CustomProviderConfig>[];
  @override
  Future<void> upsert(CustomProviderConfig config) async {}
  @override
  Future<void> remove(String id) async {}
}

/// 封住一切会去起真内嵌 PostgreSQL 的链路。任何新增的 eager 仓储读都要加进来，
/// 否则测试会挂到 isolate 超时、覆盖率收集永挂。
List<Override> sealedShellOverrides({required AppPaths paths}) => <Override>[
      appPathsProvider.overrideWithValue(paths),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(
          const AppPreferences(onboardingCompleted: true),
        ),
      ),
      anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
      orphanReapStartupProvider.overrideWith((_) async {}),
      pgMigratedPoolProvider.overrideWith((ref) => Completer<Pool<void>>().future),
      workspaceProjectsProvider
          .overrideWith((_) async => const <ProjectWithCanvases>[]),
      projectRepositoryProvider
          .overrideWith((_) async => InMemoryProjectRepository()),
      canvasRepositoryProvider
          .overrideWith((_) async => InMemoryCanvasRepository()),
      nodeRepositoryProvider.overrideWith((_) async => InMemoryNodeRepository()),
      edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
      styleLaneRepositoryProvider
          .overrideWith((_) async => InMemoryStyleLaneRepository()),
      batchResultRepositoryProvider
          .overrideWith((_) async => FakeBatchResultRepo()),
      ffmpegLocatorProvider.overrideWithValue(FakeFfmpegLocator()),
      customProviderStoreProvider
          .overrideWithValue(const EmptyCustomProviderStore()),
    ];

/// 用 ShellState 播种整个外壳。**不要** override currentCanvasIdProvider /
/// activeProjectProvider（见 test/quality/shell_projection_override_test.dart）。
Future<void> pumpInkShell(
  WidgetTester tester, {
  ShellState initial = const ShellState(),
  required AppPaths paths,
  List<Override> extraOverrides = const <Override>[],
  Size surfaceSize = const Size(1440, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...sealedShellOverrides(paths: paths),
        shellControllerProvider
            .overrideWith(() => ShellNavigator(initial: initial)),
        ...extraOverrides,
      ],
      child: const InkFrameApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// 点某个标签。标签条在 DragToMoveArea 之外，所以【不需要】400ms 的
/// kDoubleTapTimeout workaround——一帧落地。
/// 若你发现这里必须加 pump(400ms) 才稳，说明标签条被挪进 chrome 了，回退。
Future<void> tapShellTab(WidgetTester tester, ShellTab tab) async {
  await tester.tap(find.byKey(ValueKey<String>('shellTab-${tab.name}')));
  await tester.pump();
  await tester.pump();
}

/// 临时 AppPaths（每个用例独立目录，自动清理）。
Future<AppPaths> setupTempPaths(WidgetTester tester, String prefix) async {
  final Directory tmp = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => tmp.deleteSync(recursive: true));
  final AppPaths paths = DefaultAppPaths.forRoot(tmp);
  await tester.runAsync(() => paths.ensureInitialized());
  return paths;
}

/// 发送带 Ctrl 修饰的按键。快捷键表跨平台同时注册 meta + control 双变体，
/// 测试环境统一用 Ctrl 变体驱动（与 canvas_shortcuts_test.dart 一致）。
Future<void> sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// ⌘ 系快捷键在测试里就是 Ctrl 变体（见 sendCtrl）。
Future<void> sendMeta(WidgetTester tester, LogicalKeyboardKey key) =>
    sendCtrl(tester, key);

/// 拿到外壳所在的 ProviderContainer，用来在测试里直接驱动 / 读回 provider。
ProviderContainer readShellContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(InkShell)));
