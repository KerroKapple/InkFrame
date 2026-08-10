// CanvasAddNodeFab 测试：菜单含 image / video / shot 三项，点选 shot 创建 shot 节点；
// SB-2 后另加「导入脚本」一项——它不建节点，而是打开脚本导入对话框。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_add_node_fab.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

void main() {
  const canvasId = 'cv1';
  late InMemoryNodeRepository nodeRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        floatingActionButton:
            CanvasAddNodeFab(canvasId: canvasId, random: Random(1)),
      ),
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
      ],
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasAddNodeFab)),
    );
    await container.read(canvasNodesControllerProvider(canvasId).future);
    await tester.pump();
  }

  testWidgets('菜单展示 image / video / shot 三项', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add image node'), findsOneWidget);
    expect(find.text('Add video node'), findsOneWidget);
    expect(find.text('Add shot node'), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
  });

  testWidgets('点选 shot → 创建 shot config 节点', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add shot node'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, hasLength(1));
    final row = nodeRepo.rows.values.single;
    expect(row['type'], 'shot');
    expect(row['node_role'], 'config');
  });

  testWidgets('菜单含「导入脚本」→ 打开脚本导入对话框（不建节点）', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Import script…'), findsOneWidget);

    await tester.tap(find.text('Import script…'));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptImportDialog), findsOneWidget);
    expect(nodeRepo.rows, isEmpty, reason: '打开对话框本身不该建节点');
  });

  testWidgets('点选 image → 创建 image 节点（既有路径不回归）', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add image node'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows.values.single['type'], 'image');
  });
}
