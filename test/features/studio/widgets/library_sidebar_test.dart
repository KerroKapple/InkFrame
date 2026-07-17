import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/studio/controllers/studio_state.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('LibrarySidebar 渲染 LIBRARY 树；CV-1 死件（ARCHIVE/stub icons/"+"）不再出现',
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
    // currentStudioProvider 默认 null → en 兜底 studioDefaultName。
    expect(find.text('My Studio'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);

    // CV-1（D-7 d6）：ARCHIVE 死行随裁（GAP-2 激活时再回）。
    expect(find.text('ARCHIVE'), findsNothing);
    expect(find.text('Archived Projects'), findsNothing);
    // footer：接真的 settings + 回收站（LB-15/GAP-2 激活后 trash 以真入口回归）；
    // archive/people 死 stub 仍不得出现。
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // SectionLabel 的装饰性 '+'（无功能）已裁。
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('footer settings icon 点击导航到设置页（currentScreenProvider）',
      (tester) async {
    final container = ProviderContainer(overrides: <Override>[
      workspaceProjectsProvider.overrideWith((_) async => const []),
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

    expect(container.read(currentScreenProvider), AppScreen.studio);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    expect(container.read(currentScreenProvider), AppScreen.settings);
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
