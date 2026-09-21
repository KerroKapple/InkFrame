// Shell 路由 widget test：验证 _UnlockedShell 在 ShellState 切换时
// 正确渲染 StudioHomeScreen / SettingsScreen。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/interfaces/custom_provider_store.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/showcase/widgets/built_in_showcase_screen.dart';
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

/// 恒空的自定义服务商 store（GAP-1 区在 SettingsScreen 内）。
class _EmptyStore implements CustomProviderStore {
  const _EmptyStore();
  @override
  Future<List<CustomProviderConfig>> list() async => const [];
  @override
  Future<void> upsert(CustomProviderConfig config) async {}
  @override
  Future<void> remove(String id) async {}
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
          shellControllerProvider
              .overrideWith(() => ShellNavigator(initial: const ShellState())),
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
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(overlay: ShellOverlay.settings),
            ),
          ),
          // 密封 ON-3 ffmpeg 探测：不真 spawn `ffmpeg -version`。
          ffmpegLocatorProvider.overrideWithValue(_FakeFfmpegLocator()),
          // 密封 GAP-1 自定义服务商编辑区：默认 store 抛 UnimplementedError。
          customProviderStoreProvider
              .overrideWithValue(const _EmptyStore()),
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
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(
                tab: ShellTab.gallery,
                project: ProjectRef(id: 'p1', name: 'Alpha'),
              ),
            ),
          ),
          // 密封 LB-13 孤儿回收启动读：boot 测试不触发真 PG/dart:io（否则 coverage 收集永挂）。
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
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

  // 评审 P1-2：新增 ShellOverlay.showcase 此前 shell 路由零覆盖——把 app.dart
  // 的分支改成渲染别的页,全量测试照样绿。本例与下一例把它钉死。
  testWidgets('unlocked + showcase → 渲染 BuiltInShowcaseScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_showcase_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(overlay: ShellOverlay.showcase),
            ),
          ),
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(BuiltInShowcaseScreen), findsOneWidget);
    expect(find.byType(StudioHomeScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  // fix round 1（R25）：此例原名"画布优先级高于 showcase"，断言画布赢——那是
  // 旧系统里【不可达的合成态】：旧 `_openSettings`/`_openShowcase` 落笔前都会
  // 先清 canvasId，"overlay=showcase 且 canvasId 非空"这个组合根本出不来。
  // 它形式上钉住了旧判序，却把一条真实可达的路径（画布打开时按 ⌘K 开示例页）
  // 压成了回归——ShellState.openOverlay 刻意保留 canvasId（保活语义），
  // 若判序仍 canvasId-first，浮层入口在画布上会变成死键。
  // overlay-first 才是目标架构（spec 的外层 IndexedStack 是"浮层槽 vs 标签
  // 宿主"二选一，浮层盖住宿主的同时画布仍在宿主里活着）——本例改断浮层赢。
  testWidgets('浮层优先级高于画布：canvasId 非空时 showcase 仍可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_showcase_prio_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          // overlay=showcase 且画布已打开 → 浮层赢（app.dart 路由优先级）。
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(
                overlay: ShellOverlay.showcase,
                canvasId: 'cv-1',
              ),
            ),
          ),
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
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

    expect(find.byType(BuiltInShowcaseScreen), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  // R25 新增：画布已打开时 openOverlay(settings) → SettingsScreen 可见（不再
  // 是死键）。变异证明见 task-6-report.md「R25 变异证明」——把 app.dart 判序
  // 改回 canvasId-first 时，本例会转红（SettingsScreen findsNothing）。
  testWidgets('画布已打开 + openOverlay(settings) → SettingsScreen 可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_settings_over_canvas_');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          _onboardingDone(),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: const ShellState(
                overlay: ShellOverlay.settings,
                canvasId: 'cv-1',
              ),
            ),
          ),
          // 密封 ON-3 ffmpeg 探测：不真 spawn `ffmpeg -version`。
          ffmpegLocatorProvider.overrideWithValue(_FakeFfmpegLocator()),
          // 密封 GAP-1 自定义服务商编辑区：默认 store 抛 UnimplementedError。
          customProviderStoreProvider.overrideWithValue(const _EmptyStore()),
          orphanReapStartupProvider.overrideWith((_) async {}),
          _sealDbReady(),
          workspaceProjectsProvider
              .overrideWith((_) async => const <ProjectWithCanvases>[]),
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

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(CanvasScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  // fix round 2（R33）：画布分支必须带 tab==canvas 判据，否则 goTab() 保留
  // canvasId（标签保活语义）导致"回 Studio"后画面纹丝不动——本次会话一旦
  // 打开过画布，canvasId 就再也不会变回 null（ShellState 没有能清它的公共
  // 动词，resetSession() 除外）。等价于复评员 PROBE A：画布态 → goTab(studio)
  // → 断 StudioHomeScreen 可见且 CanvasScreen 不可见。
  testWidgets('画布态 goTab(studio) 后 → StudioHomeScreen 可见，CanvasScreen 不可见',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = await _setupPaths(tester, 'ink_route_canvas_back_to_studio_');

    final container = ProviderContainer(
      overrides: <Override>[
        appPathsProvider.overrideWithValue(paths),
        _onboardingDone(),
        anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
        shellControllerProvider.overrideWith(
          () => ShellNavigator(
            initial: const ShellState(
              tab: ShellTab.canvas,
              canvasId: 'cv-1',
            ),
          ),
        ),
        orphanReapStartupProvider.overrideWith((_) async {}),
        _sealDbReady(),
        workspaceProjectsProvider
            .overrideWith((_) async => const <ProjectWithCanvases>[]),
        canvasRepositoryProvider
            .overrideWith((_) async => InMemoryCanvasRepository()),
        nodeRepositoryProvider
            .overrideWith((_) async => InMemoryNodeRepository()),
        batchResultRepositoryProvider
            .overrideWith((_) async => FakeBatchResultRepo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const InkFrameApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 起始态：画布可见。
    expect(find.byType(CanvasScreen), findsOneWidget);

    container.read(shellControllerProvider.notifier).goTab(ShellTab.studio);
    await tester.pump();
    await tester.pump();

    expect(find.byType(StudioHomeScreen), findsOneWidget);
    expect(find.byType(CanvasScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
