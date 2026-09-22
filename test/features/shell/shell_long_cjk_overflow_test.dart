// 超长中文假数据不溢出容器（用户 2026-09-22 要求）。
//
// 画布 golden 里中文是方框（测试字体栈没有 CJK），字宽稳定但字形不出——中文换行、
// 省略号截断、混排基线三类回归 golden 抓不到。本文件是普通 widget test，Windows 也能跑：
// 把稿上标了 text-overflow: ellipsis 的位置（画布树 / 节点列表 / 节点卡标题 / 队列任务名 /
// 队列模型 / 面包屑 / 画布头 / 泳道标题 / 检查器输入源名）全部灌一段 60 字中文，断言：
//   1. 整个外壳 1600×1000 下没有任何 RenderFlex 溢出（flutter_test 会把溢出当异常抛）；
//   2. 每处长文本都是单行 + 省略号；
//   3. 每处长文本的渲染框都落在外壳边界内。
import 'dart:async';

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
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/ink_shell.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:postgres/postgres.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_secure_storage.dart';
import '../../_harness/shell_app.dart';

const Size _surface = Size(1600, 1000);

/// 60 个中文字（按 12px 字号约 720px 宽），比任何一个容器都宽。
const String _long = '晨雾中的山径光线从左上穿过松林形成丁达尔光束人物背影逐渐清晰镜头缓慢推进直到山脊线被第一缕光切开为止再回望空镜收尾';
const String _projectName = '项目$_long';
const String _canvasName = '画布$_long';
const String _laneName = '泳道$_long';
const String _shotName = '分镜$_long';
const String _imageName = '图像$_long';
const String _videoName = '视频$_long';
const String _providerId = 'provider-$_long';

class _SeedableJobsRegistry extends JobsRegistry {
  _SeedableJobsRegistry(this._seed);
  final List<JobState> _seed;

  @override
  List<JobState> build() => List<JobState>.unmodifiable(_seed);
}

void main() {
  testWidgets('稿上的省略号位置灌 60 字中文：不溢出、单行省略、框在外壳内', (tester) async {
    final InMemoryProjectRepository projects = InMemoryProjectRepository();
    final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
    final InMemoryStyleLaneRepository lanes = InMemoryStyleLaneRepository();
    final InMemoryNodeRepository nodes = InMemoryNodeRepository();
    final InMemoryEdgeRepository edges = InMemoryEdgeRepository();

    final String projectId = await projects.create(name: _projectName);
    final String canvasId = await canvases.create(projectId: projectId, name: _canvasName);
    final String laneId = await lanes.create(canvasId: canvasId, label: _laneName, stylePrompt: _long);
    Future<String> node(String label, CanvasNodeType type, double x, Map<String, Object?> cfg) =>
        nodes.create(
          canvasId: canvasId,
          type: type.name,
          nodeRole: NodeRole.config.name,
          label: label,
          laneId: laneId,
          positionX: x,
          positionY: 80,
          width: kNodeCardSize.width,
          height: kNodeCardSize.height,
          typeConfig: cfg,
        );
    final String shotId = await node(_shotName, CanvasNodeType.shot, 40, <String, Object?>{'shot_notes': _long});
    final String imageId = await node(_imageName, CanvasNodeType.image, 340, <String, Object?>{'prompt': _long});
    final String videoId = await node(_videoName, CanvasNodeType.video, 640, <String, Object?>{'prompt': _long});
    await edges.create(canvasId: canvasId, sourceNodeId: shotId, targetNodeId: imageId, edgeType: 'data');
    await edges.create(
      canvasId: canvasId,
      sourceNodeId: imageId,
      targetNodeId: videoId,
      edgeType: 'data',
      role: CanvasEdgeMapping.roleToDb(EdgeRole.firstFrame),
    );

    final AppPaths paths = await setupTempPaths(tester, 'ink_long_cjk_');
    await tester.binding.setSurfaceSize(_surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
          preferencesServiceProvider.overrideWithValue(
            InMemoryPreferencesService(
              const AppPreferences(onboardingCompleted: true, localeCode: 'zh'),
            ),
          ),
          anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
          orphanReapStartupProvider.overrideWith((_) async {}),
          pgMigratedPoolProvider.overrideWith((ref) => Completer<Pool<void>>().future),
          projectRepositoryProvider.overrideWith((_) async => projects),
          canvasRepositoryProvider.overrideWith((_) async => canvases),
          styleLaneRepositoryProvider.overrideWith((_) async => lanes),
          nodeRepositoryProvider.overrideWith((_) async => nodes),
          edgeRepositoryProvider.overrideWith((_) async => edges),
          batchResultRepositoryProvider.overrideWith((_) async => FakeBatchResultRepo()),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
          ffmpegLocatorProvider.overrideWithValue(FakeFfmpegLocator()),
          customProviderStoreProvider.overrideWithValue(const EmptyCustomProviderStore()),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(appName: 'InkFrame', packageName: 'inkframe', version: '0.0.0', buildNumber: '0'),
          ),
          // 队列一行：任务名 = 源节点名（超长），模型列 = providerId（超长）。
          jobsRegistryProvider.overrideWith(
            () => _SeedableJobsRegistry(<JobState>[
              JobState.running(
                jobId: 'job-1',
                providerId: _providerId,
                canvasId: canvasId,
                sourceNodeId: videoId,
                progress: 0.4,
              ),
            ]),
          ),
          shellControllerProvider.overrideWith(
            () => ShellNavigator(
              initial: ShellState(
                tab: ShellTab.canvas,
                canvasId: canvasId,
                project: ProjectRef(id: projectId, name: _projectName),
              ),
            ),
          ),
        ],
        child: const InkFrameApp(),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    // 选中视频节点：检查器输入区会列出「起始帧 ← <超长图像名>」。
    ProviderScope.containerOf(tester.element(find.byType(InkShell)))
        .read(canvasSelectionControllerProvider(canvasId).notifier)
        .select(videoId);
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    // 1. 没有任何布局溢出异常。
    expect(tester.takeException(), isNull);

    // 2 + 3. 每一处超长文本：单行省略，且渲染框在外壳内。
    final Rect shellRect = tester.getRect(find.byType(InkShell));
    final Finder longTexts = find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data?.contains(_long) ?? false),
      description: 'Text containing the 60-char CJK string',
    );
    expect(longTexts, findsWidgets);
    final List<String> problems = <String>[];
    for (final Element e in longTexts.evaluate()) {
      final Text t = e.widget as Text;
      final String head = t.data!.substring(0, 2);
      if (t.overflow != TextOverflow.ellipsis) {
        problems.add('「$head…」overflow=${t.overflow}（要 ellipsis）');
      }
      // 节点图区的提示词摘要按稿是两行 clamp，其余都是单行；都必须有行数上限。
      if (t.maxLines == null || t.maxLines! > 2) {
        problems.add('「$head…」maxLines=${t.maxLines}（要 1 或 2）');
      }
      final RenderBox box = e.renderObject! as RenderBox;
      final Rect r = box.localToGlobal(Offset.zero) & box.size;
      if (r.right > shellRect.right + 0.5 || r.left < shellRect.left - 0.5) {
        problems.add('「$head…」渲染框 $r 越出外壳 $shellRect');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 覆盖面：面包屑 / 画布头 / 画布树 / 节点列表 / 泳道 / 节点卡 / 检查器 / 队列——至少这么多处。
    expect(longTexts.evaluate().length, greaterThanOrEqualTo(8),
        reason: '超长文本出现的位置少于预期，说明某处没有渲染出来（或改用了别的 widget）');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
