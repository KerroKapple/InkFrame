import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/controllers/studio_state.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('LibrarySidebar 渲染 section labels + footer icons (空 projects)',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      surfaceSize: const Size(400, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) async => const []),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('ARCHIVE'), findsOneWidget);
    expect(find.text('Archived Projects'), findsOneWidget);
    // currentStudioProvider 默认 null → en 兜底 studioDefaultName。
    expect(find.text('My Studio'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('LibrarySidebar 显示 project 行 + 点击切换 selectedProjectIdProvider',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final projects = <ProjectWithCanvases>[
      ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha Project',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const [],
      ),
      ProjectWithCanvases(
        id: 'p2',
        name: 'Beta Project',
        createdAt: DateTime.utc(2026, 5, 2),
        canvases: const [],
      ),
    ];
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith((_) async => projects),
    ]);
    addTearDown(container.dispose);

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

    expect(find.text('Alpha Project'), findsOneWidget);
    expect(find.text('Beta Project'), findsOneWidget);
    expect(container.read(selectedProjectIdProvider), isNull);

    await tester.tap(find.text('Alpha Project'));
    await tester.pump();
    expect(container.read(selectedProjectIdProvider), 'p1');

    await tester.tap(find.text('Beta Project'));
    await tester.pump();
    expect(container.read(selectedProjectIdProvider), 'p2');
  });

  testWidgets('LibrarySidebar loading 状态展示 CircularProgressIndicator',
      (tester) async {
    final completer = Completer<List<ProjectWithCanvases>>();
    addTearDown(() => completer.complete(const <ProjectWithCanvases>[]));
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      surfaceSize: const Size(400, 900),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith((_) => completer.future),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
