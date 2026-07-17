// 管理画布对话框已删区（LB-15）：渲染 + 恢复迁回活列表。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_repositories.dart';

void main() {
  testWidgets('已删区渲染软删画布 → 恢复后迁回活列表、已删区消失', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 真 fake 仓储：软删画布由 listTrashedByProject 读出，恢复真正清 deleted_at。
    final canvases = InMemoryCanvasRepository();
    final cLive = await canvases.create(projectId: 'p1', name: 'LiveCanvas');
    final cDead = await canvases.create(projectId: 'p1', name: 'DeadCanvas');
    await canvases.softDelete(cDead);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canvasRepositoryProvider.overrideWith((ref) async => canvases),
          workspaceProjectsProvider.overrideWith(
            (_) async => <ProjectWithCanvases>[
              ProjectWithCanvases(
                id: 'p1',
                name: 'Alpha',
                createdAt: DateTime.utc(2026, 5, 1),
                canvases: <CanvasRef>[CanvasRef(id: cLive, name: 'LiveCanvas')],
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 项目卡菜单 → 管理画布。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage canvases'));
    await tester.pumpAndSettle();

    // 活画布 + 已删区（Trash 标题 + 软删画布 + 删除时间）。
    expect(find.text('LiveCanvas'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('DeadCanvas'), findsOneWidget);
    expect(find.textContaining('Deleted '), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    // 已删区消失（真恢复→重取回空），行迁回活列表。
    expect(find.text('Trash'), findsNothing);
    expect(find.text('DeadCanvas'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    // 仓储确认 deleted_at 已清。
    expect(await canvases.listTrashedByProject('p1'), isEmpty);
  });
}
