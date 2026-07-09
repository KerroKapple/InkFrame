import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/studio/widgets/project_card.dart';
import 'package:inkframe/features/studio/widgets/studio_top_chrome.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_unit_of_work.dart';
import '../../_harness/test_app.dart';
import '../../helpers/recording_logger.dart';

class _RecordingToastService implements ToastService {
  final List<({String message, ToastKind kind})> calls =
      <({String message, ToastKind kind})>[];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    calls.add((message: message, kind: kind));
  }
}

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

void main() {
  testWidgets('StudioHome 数据态：渲染 sidebar + Recent Projects 标题 + 卡片 + FAB',
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

    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget); // FAB
    // Alpha 既出现在 sidebar tree row 也出现在 ProjectCard
    expect(find.text('Alpha'), findsNWidgets(2));
  });

  testWidgets('ProjectCard meta 行：真实 createdAt 月份 + 画布数（无捏造 EP/日期）',
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
              canvases: const <CanvasRef>[
                CanvasRef(id: 'c1', name: 'A'),
                CanvasRef(id: 'c2', name: 'B'),
              ],
            ),
            ProjectWithCanvases(
              id: 'p2',
              name: 'Beta',
              createdAt: DateTime.utc(2025, 11, 3),
              canvases: const <CanvasRef>[CanvasRef(id: 'c3', name: 'C')],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('May 2026 · 2 canvases'), findsOneWidget);
    expect(find.text('Nov 2025 · 1 canvas'), findsOneWidget);
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
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith(
        (_) async => const <ProjectWithCanvases>[],
      ),
      projectRepositoryProvider.overrideWith((_) async => projects),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
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

  testWidgets('StudioHome 顶栏 Settings 入口：点击后 studioOpenSettingsIntent 计数 +1',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith(
        (_) async => const <ProjectWithCanvases>[],
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

    expect(container.read(currentScreenProvider), AppScreen.studio);
    final settingsButton =
        find.byKey(StudioTopChrome.settingsButtonKey);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(container.read(currentScreenProvider), AppScreen.settings);
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
    final toast = _RecordingToastService();
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
    expect(toast.calls, hasLength(1));
    expect(toast.calls.single.message, "Couldn't open canvas");
    expect(toast.calls.single.kind, ToastKind.error);
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
    expect(find.text('Heist'), findsNWidgets(2));
  });
}
