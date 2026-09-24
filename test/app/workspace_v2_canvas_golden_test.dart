// 画布标签整屏 golden（用户 2026-09-22 拍板：画布是视觉重做的基线，后续 Studio /
// 画廊接线都复用壳 chrome——chrome 任何改动都要让这张变红）。
//
// 场景 = docs/design/handoff-2026-09/replica/workspace_v2_wired_1600x1000.png 那一屏：
// 同一份稿数据（seedWorkspaceFixtureInto）播进内存仓储，1600×1000，zh，选中「镜头 03」。
// 真机截图与本 golden 的唯一差别是字体光栅化：那张 PNG 是 Windows 上截的，golden 基线
// 在 CI ubuntu 生成（详见 node_card_golden_test 头注释），所以不能把那张 PNG 直接当基线。
//
// 确定性：状态栏会画 appPaths.projects.path 与版本号——两者钉死。
// 全外壳测试不许 pumpAndSettle（见 shell_app.dart），这里固定次数 pump。
@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/di/orphan_reaper.dart';
import 'package:inkframe/core/di/package_info.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/ink_shell.dart';
import 'package:inkframe/features/workspace/dev/dev_capture.dart';
import 'package:inkframe/features/workspace/models/workspace_fixture.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:postgres/postgres.dart';

import '../_harness/fake_batch_result.dart';
import '../_harness/fake_repositories.dart';
import '../_harness/fake_secure_storage.dart';
import '../_harness/fake_unit_of_work.dart';
import '../_harness/shell_app.dart';

final bool _goldensPresent =
    File('test/app/goldens/workspace_v2_canvas.png').existsSync();
final bool _skipGolden = !_goldensPresent && !autoUpdateGoldenFiles;

/// 与真机截图同尺寸（docs/design/handoff-2026-09/README.md 的比对尺寸）。
const Size _surface = Size(1600, 1000);

void main() {
  testWidgets('Workspace v2 画布标签整屏基线（稿数据 / zh / 选中镜头 03）',
      (tester) async {
    // 稿数据播进内存仓储——与 dev_capture 真机截图共用同一份播种代码。
    final InMemoryProjectRepository projects = InMemoryProjectRepository();
    final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
    final InMemoryStyleLaneRepository lanes = InMemoryStyleLaneRepository();
    final InMemoryNodeRepository nodes = InMemoryNodeRepository();
    final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
    final WorkspaceFixtureIds ids = await seedWorkspaceFixtureInto(
      FakeRepositoryScope(
        projects: projects,
        canvas: canvases,
        styleLanes: lanes,
        nodes: nodes,
        edges: edges,
      ),
    );

    final AppPaths pinned = DefaultAppPaths.forRoot(
      Directory('${Directory.systemTemp.path}/inkframe_golden_root'),
    );

    await tester.binding.setSurfaceSize(_surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(pinned),
          preferencesServiceProvider.overrideWithValue(
            InMemoryPreferencesService(
              const AppPreferences(
                onboardingCompleted: true,
                localeCode: 'zh',
              ),
            ),
          ),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          orphanReapStartupProvider.overrideWith((_) async {}),
          pgMigratedPoolProvider
              .overrideWith((ref) => Completer<Pool<void>>().future),
          projectRepositoryProvider.overrideWith((_) async => projects),
          canvasRepositoryProvider.overrideWith((_) async => canvases),
          styleLaneRepositoryProvider.overrideWith((_) async => lanes),
          nodeRepositoryProvider.overrideWith((_) async => nodes),
          edgeRepositoryProvider.overrideWith((_) async => edges),
          batchResultRepositoryProvider
              .overrideWith((_) async => FakeBatchResultRepo()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
          ffmpegLocatorProvider.overrideWithValue(FakeFfmpegLocator()),
          customProviderStoreProvider
              .overrideWithValue(const EmptyCustomProviderStore()),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'InkFrame',
              packageName: 'inkframe',
              version: '0.0.0',
              buildNumber: '0',
            ),
          ),
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: ShellState(
                tab: ShellTab.canvas,
                canvasId: ids.canvasId,
                project: ProjectRef(
                  id: ids.projectId,
                  name: WorkspaceFixture.breadcrumb[1],
                ),
              ),
            ),
          ),
        ],
        child: const InkFrameApp(),
      ),
    );
    // 内存仓储在微任务里就绪；多 pump 几帧让节点 / 边 / 泳道 / 项目树全部落地。
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    ProviderScope.containerOf(tester.element(find.byType(InkShell)))
        .read(canvasSelectionControllerProvider(ids.canvasId).notifier)
        .select(ids.videoId);
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    await expectLater(
      find.byType(InkShell),
      matchesGoldenFile('goldens/workspace_v2_canvas.png'),
    );
  }, skip: _skipGolden);
}
