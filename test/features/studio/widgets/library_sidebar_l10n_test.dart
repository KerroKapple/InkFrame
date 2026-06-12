// LibrarySidebar 的 "Projects" 树节点必须走 l10n —— zh locale 下应显示"项目"。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('zh locale 下 Projects 节点显示本地化文案"项目"', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      locale: const Locale('zh'),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (ref) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Demo',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('项目'), findsOneWidget);
    expect(find.text('Projects'), findsNothing);
  });
}
