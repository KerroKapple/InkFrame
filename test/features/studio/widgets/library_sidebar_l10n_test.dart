import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

void main() {
  testWidgets('zh locale 下库面板显示本地化文案「全部项目 / 回收站 / 设置」', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      locale: const Locale('zh'),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (ref) async => <ProjectWithCanvases>[
            ProjectWithCanvases(id: 'p1', name: 'Demo', createdAt: DateTime.utc(2026, 5, 1), canvases: const <CanvasRef>[]),
          ],
        ),
        projectRepositoryProvider.overrideWith((_) async => InMemoryProjectRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('全部项目'), findsOneWidget);
    expect(find.text('回收站'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('All projects'), findsNothing);
  });
}
