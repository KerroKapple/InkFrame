// 库面板（Screens 稿第 1 屏）：「库」标题 + 全部项目（计数）/ 回收站（计数）+ 底部「设置」。
// 稿上的「最近打开 / 归档 / 最近画布」无数据不画；旧的 project 树行与 LIBRARY 大写标题退役。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';
import 'package:inkframe/features/studio/widgets/trash_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

List<ProjectWithCanvases> _two() => <ProjectWithCanvases>[
      ProjectWithCanvases(id: 'p1', name: 'Alpha Project', createdAt: DateTime.utc(2026, 5, 1), canvases: const []),
      ProjectWithCanvases(id: 'p2', name: 'Beta Project', createdAt: DateTime.utc(2026, 5, 2), canvases: const []),
    ];

void main() {
  testWidgets('渲染「库」+ 全部项目（计数 2）+ 回收站 + 设置；旧树行 / 大写标题不再出现', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      surfaceSize: const Size(400, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) async => _two()),
        projectRepositoryProvider.overrideWith((_) async => InMemoryProjectRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('All projects'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: '全部项目的计数');
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    expect(find.text('LIBRARY'), findsNothing);
    expect(find.text('My Studio'), findsNothing);
    expect(find.text('Alpha Project'), findsNothing, reason: '稿上库面板不列项目');
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('「设置」行点击打开设置层（shellControllerProvider）', (tester) async {
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith((_) async => const []),
      projectRepositoryProvider.overrideWith((_) async => InMemoryProjectRepository()),
    ]);
    addTearDown(container.dispose);

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LibrarySidebar()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(container.read(shellControllerProvider).overlay, isNull);
    await tester.tap(find.byKey(LibrarySidebar.settingsKey));
    await tester.pump();
    expect(container.read(shellControllerProvider).overlay, ShellOverlay.settings);
  });

  testWidgets('「回收站」行点击打开回收站对话框', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      surfaceSize: const Size(600, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) async => const []),
        projectRepositoryProvider.overrideWith((_) async => InMemoryProjectRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LibrarySidebar.trashKey));
    await tester.pumpAndSettle();
    expect(find.byType(TrashDialog), findsOneWidget);
  });

  testWidgets('loading 态：计数先不出，行照常渲染', (tester) async {
    final completer = Completer<List<ProjectWithCanvases>>();
    addTearDown(() => completer.complete(const <ProjectWithCanvases>[]));
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      surfaceSize: const Size(400, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) => completer.future),
        projectRepositoryProvider.overrideWith((_) async => InMemoryProjectRepository()),
      ],
    );
    await tester.pump();
    expect(find.text('All projects'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
