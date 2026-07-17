// TrashDialog + sidebar 回收站入口 widget 测试（LB-15）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/trashed_items_providers.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';
import 'package:inkframe/features/studio/widgets/trash_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_repositories.dart';

/// restore 必炸的项目仓储（失败 snackbar 路径）。
class _FailingRestoreRepo extends InMemoryProjectRepository {
  @override
  Future<int> restore(String id) async => throw const LocalIOError();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('空态文案', (tester) async {
    final repo = InMemoryProjectRepository();
    await _pump(
      tester,
      const TrashDialog(),
      overrides: [
        projectRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('软删项目渲染（名+删除时间）→ 恢复后行消失、工作库可见', (tester) async {
    final repo = InMemoryProjectRepository();
    final p1 = await repo.create(name: 'Doomed');
    await repo.create(name: 'Alive');
    await repo.softDelete(p1);

    await _pump(
      tester,
      const TrashDialog(),
      overrides: [
        projectRepositoryProvider.overrideWith((ref) async => repo),
        canvasRepositoryProvider
            .overrideWith((ref) async => InMemoryCanvasRepository()),
        // riverpod 2.6.1 怪癖：invalidate 从未被读过的 autoDispose provider，
        // 树收尾时元素双重 complete（Bad state）。真实 app 中 sidebar 常驻监听
        // 本 provider 不会踩到；测试给个良性 stub 绕开。
        workspaceProjectsProvider
            .overrideWith((ref) async => const <ProjectWithCanvases>[]),
      ],
    );

    expect(find.text('Doomed'), findsOneWidget);
    expect(find.textContaining('Deleted '), findsOneWidget);
    expect(find.text('Alive'), findsNothing); // 活项目不进回收站。

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Doomed'), findsNothing);
    expect(find.text('Trash is empty'), findsOneWidget);
    // 仓储层确认恢复生效（deleted_at 已清，回到活列表）。
    final alive = await repo.listAll();
    expect(alive.map((r) => r['name']), containsAll(<String>['Doomed', 'Alive']));
    expect(await repo.listTrashed(), isEmpty);
  });

  testWidgets('读侧 error → InkErrorBanner（LB-06 规范）', (tester) async {
    await _pump(
      tester,
      const TrashDialog(),
      overrides: [
        trashedProjectsProvider.overrideWith(
          (ref) => throw const LocalIOError(),
        ),
      ],
    );
    // LocalIOError → errorLocalIO 文案。
    expect(find.textContaining('Local disk I/O error'), findsOneWidget);
  });

  testWidgets('恢复失败 InkError → snackbar，行保留', (tester) async {
    final repo = _FailingRestoreRepo();
    final p1 = await repo.create(name: 'Stuck');
    await repo.softDelete(p1);

    await _pump(
      tester,
      const TrashDialog(),
      overrides: [
        projectRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't restore"), findsOneWidget);
    expect(find.text('Stuck'), findsOneWidget);
  });

  testWidgets('sidebar footer 回收站入口 → 弹 TrashDialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = InMemoryProjectRepository();
    await _pump(
      tester,
      const LibrarySidebar(),
      overrides: [
        projectRepositoryProvider.overrideWith((ref) async => repo),
        canvasRepositoryProvider
            .overrideWith((ref) async => InMemoryCanvasRepository()),
      ],
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(TrashDialog), findsOneWidget);
  });
}
