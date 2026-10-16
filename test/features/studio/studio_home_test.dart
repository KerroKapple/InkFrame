import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:inkframe/core/di/asset_bundle.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/studio/widgets/project_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/fake_asset_bundle.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_toast_service.dart';
import '../../_harness/fake_unit_of_work.dart';
import '../../_harness/test_app.dart';
import '../../helpers/recording_logger.dart';

/// create 必抛 LocalIOError 的画布仓储——驱动打开画布失败分支。
class _FailingCreateCanvasRepository extends InMemoryCanvasRepository {
  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async {
    throw const LocalIOError(extra: {'op': 'create'});
  }
}

/// update 必抛 LocalIOError 的项目仓储——驱动重命名项目失败分支。
class _FailingUpdateProjectRepository extends InMemoryProjectRepository {
  @override
  Future<int> update(String id, Map<String, Object?> patch) async =>
      throw const LocalIOError(extra: {'op': 'update'});
}

/// run 永远抛错的 UoW——驱动新建项目失败分支（项目 + 首画布在单事务里建）。
class _ThrowingUnitOfWork implements UnitOfWork {
  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async =>
      throw const LocalIOError(extra: {'op': 'create'});
}

void main() {
  testWidgets('StudioHome 数据态：渲染库面板 + 工具行 + 卡片 + 虚线新建格',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('All projects'), findsNWidgets(2), reason: '库面板行 + 工具行标题');
    expect(find.text('New Project'), findsOneWidget); // 网格末位的虚线格
    expect(find.text('Alpha'), findsOneWidget, reason: '库面板不再列项目，只有卡片');
  });

  testWidgets('ProjectCard meta 行：真实 updatedAt 相对时间 + 画布数徽标（无捏造 EP/日期）',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 12),
              updatedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
              canvases: const <CanvasRef>[
                CanvasRef(id: 'c1', name: 'A'),
                CanvasRef(id: 'c2', name: 'B'),
              ],
            ),
            ProjectWithCanvases(
              id: 'p2',
              name: 'Beta',
              createdAt: DateTime.utc(2025, 11, 3),
              updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
              canvases: const <CanvasRef>[CanvasRef(id: 'c3', name: 'C')],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('2 h ago'), findsOneWidget);
    expect(find.text('2 canvases'), findsOneWidget);
    expect(find.text('3 d ago'), findsOneWidget);
    expect(find.text('1 canvas'), findsOneWidget);
    expect(find.textContaining('EP 01'), findsNothing);
  });

  testWidgets('StudioHome 空态：渲染 empty card + CTA + 隐藏 FAB',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('No projects yet'), findsOneWidget);
    expect(
      find.text('Create your first project to start building storyboards.'),
      findsOneWidget,
    );
    // CTA 文本 = studioNewProject = 'New Project'：empty 态 only 1 个，FAB 不渲染
    expect(find.text('New Project'), findsOneWidget);
  });

  testWidgets('StudioHome 空态：示例项目入口与 New Project 并存（ON-2）',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Create sample project'), findsOneWidget);
  });

  testWidgets('空态点击示例项目入口：createSample 建项目+画布并切 currentCanvasId（ON-2）',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = InMemoryProjectRepository();
    final canvases = InMemoryCanvasRepository();
    final lanes = InMemoryStyleLaneRepository();
    final nodes = InMemoryNodeRepository();
    final edges = InMemoryEdgeRepository();
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith(
        (_) async => const <ProjectWithCanvases>[],
      ),
      // 示例项目要往数据根写成片：必须钉临时根（appPathsProvider 本身就带
      // 「没被 override」的硬断言，这里顺着它走），bundle 给空的——成片本身
      // 由 canvas_bootstrap_controller_test 覆盖，这里只看建项目那条链。
      appPathsProvider.overrideWithValue(
        DefaultAppPaths.forRoot(
          Directory.systemTemp.createTempSync('ink_studio_sample_'),
        ),
      ),
      assetBundleProvider
          .overrideWithValue(FakeAssetBundle(const <String, List<int>>{})),
      unitOfWorkProvider.overrideWith(
        (_) async => FakeUnitOfWork(FakeRepositoryScope(
          projects: projects,
          canvas: canvases,
          styleLanes: lanes,
          nodes: nodes,
          edges: edges,
        )),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StudioHomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create sample project'));
    await tester.pumpAndSettle();

    // 示例项目 + 首画布落库（i18n 样例名），并直达画布
    expect(projects.rows.values.single['name'], 'Sample Project');
    expect(canvases.rows.values.single['name'], 'Canvas 1');
    expect(container.read(currentCanvasIdProvider), isNotNull);
    // ON-2b：演示内容一并种入（1 泳道 + 两镜预填 prompt 的 image config 节点 + 一条叙事边）
    expect(lanes.rows.values.single['label'], 'Ink Style');
    expect(nodes.rows, hasLength(2));
    for (final Map<String, Object?> node in nodes.rows.values) {
      expect(node['type'], 'image');
      expect(node['lane_id'], lanes.rows.keys.single);
      expect(
        (node['type_config'] as Map<String, Object?>)['prompt'],
        isNotEmpty,
      );
    }
    // 两镜的节点名都走 ARB（sampleSeedOf）
    expect(
      nodes.rows.values.map((Map<String, Object?> n) => n['label']).toSet(),
      <String>{'First Shot', 'Second Shot'},
    );
    expect(edges.rows.values.single['edge_type'], 'narrative');
  });

  testWidgets('StudioHome loading 态：CircularProgressIndicator',
      (tester) async {
    final completer = Completer<List<ProjectWithCanvases>>();
    addTearDown(() => completer.complete(const <ProjectWithCanvases>[]));
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) => completer.future),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('StudioHome 错误态：渲染 InkErrorBanner + Retry 按钮可点',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) => Future<List<ProjectWithCanvases>>.error(
            StateError('boom'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load projects'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
  });

  testWidgets('StudioHome empty CTA 点击：打开 New Project Dialog 并校验空名',
      (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();

    expect(find.text('Create new project'), findsOneWidget);
    expect(find.text('Project name'), findsOneWidget);

    // 直接点 Create → 触发空名校验
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Project name is required'), findsOneWidget);

    // Cancel 关闭弹窗
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Create new project'), findsNothing);
  });

  testWidgets('打开画布失败：InkError 收窄捕获 → error toast + logger.error 留痕',
      (tester) async {
    final toast = RecordingToastService();
    final logger = RecordingLogger();
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              // 无画布 → onTap 走 createCanvas → 仓储抛 LocalIOError
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
        canvasRepositoryProvider
            .overrideWith((_) async => _FailingCreateCanvasRepository()),
        toastServiceProvider.overrideWithValue(toast),
        loggerProvider.overrideWithValue(logger),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StudioProjectCard));
    await tester.pumpAndSettle();

    // 用户可见：error toast
    expect(toast.shown, hasLength(1));
    expect(toast.shown.single.title, "Couldn't open canvas");
    expect(toast.shown.single.kind, ToastKind.error);
    expect(toast.shown.single.chime, isFalse,
        reason: '打开画布是用户刚点的那一下，失败是即时回应，不是后台事件');
    // 可观测性：失败必须留 error 日志且保留原始 cause（裸 catch 吞错是缺陷）
    final errors = logger.byLevel(InkLogLevel.error);
    expect(errors, hasLength(1),
        reason: '打开画布失败必须写 error 日志，不能只弹 toast');
    expect(errors.single.module, 'studio.home');
    expect(errors.single.cause, isA<LocalIOError>());
    expect(errors.single.stackTrace, isNotNull);
  });

  testWidgets('create 流程：dialog 提交 → controller 建项目 + 首画布并刷新列表',
      (tester) async {
    final projects = InMemoryProjectRepository();
    final canvases = InMemoryCanvasRepository();
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        projectRepositoryProvider.overrideWith((_) async => projects),
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        unitOfWorkProvider.overrideWith(
          (_) async => FakeUnitOfWork(
            FakeRepositoryScope(projects: projects, canvas: canvases),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Heist');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // 编排在 controller：项目 + 首画布（i18n 默认名）一起建出
    expect(projects.rows.values.single['name'], 'Heist');
    expect(canvases.rows.values.single['name'], 'Untitled Canvas');
    // 列表刷新后卡片可见（sidebar + card 各一处）
    expect(find.text('Heist'), findsOneWidget, reason: '只在卡片上；库面板不列项目');
  });

  // 下面两条：新建 / 重命名失败走通知卡（toastServiceProvider）。两者都是用户
  // 刚点的那一下的即时回应，不是后台事件，所以不响。
  testWidgets('create 失败：InkError → error toast（不响）', (tester) async {
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        unitOfWorkProvider.overrideWith((_) async => _ThrowingUnitOfWork()),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Heist');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(toast.titles, <String>['Failed to create project']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(toast.shown.single.chime, isFalse,
        reason: '建项目是用户刚点的那一下，失败是即时回应，不是后台事件');
  });

  testWidgets('重命名项目失败：InkError → error toast（不响）', (tester) async {
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
        projectRepositoryProvider
            .overrideWith((_) async => _FailingUpdateProjectRepository()),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    await tester.pumpAndSettle();

    // 菜单键的类型参数是私有枚举，byType 配不上 ⇒ 按 tooltip 定位。
    await tester.tap(
      find.descendant(
        of: find.byType(StudioProjectCard),
        matching: find.byTooltip('Project options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename project').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alpha 2');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(toast.titles, <String>['Failed to rename project']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(toast.shown.single.chime, isFalse);
  });
}
