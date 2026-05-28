import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/studio/widgets/studio_top_chrome.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('StudioHome 数据态：渲染 sidebar + Recent Projects 标题 + 卡片 + FAB', (
    tester,
  ) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              canvases: <CanvasRef>[],
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

  testWidgets('StudioHome 空态：渲染 empty card + CTA + 隐藏 FAB', (tester) async {
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

  testWidgets('StudioHome loading 态：CircularProgressIndicator', (tester) async {
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

  testWidgets('StudioHome 错误态：渲染 InkErrorBanner + Retry 按钮可点', (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) => Future<List<ProjectWithCanvases>>.error(StateError('boom')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load projects'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
  });

  testWidgets('StudioHome 顶栏 Settings 入口：点击后 studioOpenSettingsIntent 计数 +1', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentScreenProvider), AppScreen.studio);
    final settingsButton = find.byKey(StudioTopChrome.settingsButtonKey);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(container.read(currentScreenProvider), AppScreen.settings);
  });

  // ── 未配置 provider 横幅 ──────────────────────────────────────────────────

  testWidgets('StudioHome 未配置 provider：显示横幅提示文案', (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        apiKeyUnlockedProvider.overrideWith((_) async => false),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No provider configured. Generation actions are disabled until you set one up.',
      ),
      findsOneWidget,
    );
    expect(find.text('Set up provider'), findsOneWidget);
  });

  testWidgets('StudioHome 未配置 provider：点击 action 跳转 Settings', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        apiKeyUnlockedProvider.overrideWith((_) async => false),
      ],
    );
    addTearDown(container.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentScreenProvider), AppScreen.studio);
    await tester.tap(find.text('Set up provider'));
    await tester.pumpAndSettle();
    expect(container.read(currentScreenProvider), AppScreen.settings);
  });

  testWidgets('StudioHome 已配置 provider：不显示横幅', (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        apiKeyUnlockedProvider.overrideWith((_) async => true),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No provider configured. Generation actions are disabled until you set one up.',
      ),
      findsNothing,
    );
    expect(find.text('Set up provider'), findsNothing);
  });

  testWidgets('StudioHome 未配置 provider：点击关闭后横幅消失', (tester) async {
    await pumpInkApp(
      tester,
      const StudioHomeScreen(),
      surfaceSize: const Size(1440, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        apiKeyUnlockedProvider.overrideWith((_) async => false),
      ],
    );
    await tester.pumpAndSettle();

    // 确认横幅可见
    expect(find.text('Set up provider'), findsOneWidget);

    // 点击关闭按钮
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 横幅应消失
    expect(find.text('Set up provider'), findsNothing);
  });

  // ── provider 横幅测试结束 ──────────────────────────────────────────────────

  testWidgets('StudioHome empty CTA 点击：打开 New Project Dialog 并校验空名', (
    tester,
  ) async {
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
}
