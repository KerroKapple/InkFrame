// CanvasProjectPanel 页签 ↔ 页面体的接线（P4 回归）。
//
// 钉的是 a11e8ef 留下的一个死分支：角色页的 when 子句里带了 `project.id == '__never__'`，
// 条件恒假，页签点亮了、正文却永远落回画布页——上线前的接线验收截图才发现。
// 既有的 character_library_panel_test 直接 pump 面板本体，绕过了这个 switch，测不到。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/project_panel_tab.dart';
import 'package:inkframe/features/canvas/widgets/canvas_project_panel.dart';
import 'package:inkframe/features/canvas/widgets/character_library_panel.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kProjectId = 'p1';
const String _kCanvasId = 'c1';

List<Override> _overrides({required bool withProject}) => <Override>[
  shellControllerProvider.overrideWith(
    () => ShellNavigator(
      initial: ShellState(
        canvasId: _kCanvasId,
        project: withProject
            ? const ProjectRef(id: _kProjectId, name: '山径破晓')
            : null,
      ),
    ),
  ),
  characterRepositoryProvider.overrideWith((_) async => FakeCharacterRepo()),
  characterAssetServiceProvider.overrideWithValue(FakeCharacterAssetService()),
  canvasRepositoryProvider.overrideWith((_) async => InMemoryCanvasRepository()),
  nodeRepositoryProvider.overrideWith((_) async => InMemoryNodeRepository()),
  edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
  batchResultRepositoryProvider.overrideWith((_) async => FakeBatchResultRepo()),
];

Future<void> _pump(WidgetTester tester, {required bool withProject}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasProjectPanel(canvasId: _kCanvasId)),
    overrides: _overrides(withProject: withProject),
    surfaceSize: const Size(400, 700),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CanvasProjectPanel)));

void main() {
  testWidgets('默认页 = 画布页，不画角色库', (WidgetTester tester) async {
    await _pump(tester, withProject: true);
    expect(find.byType(CharacterLibraryPanel), findsNothing);
  });

  testWidgets('选中角色页 + 有活动项目 → 正文真的换成角色库', (WidgetTester tester) async {
    await _pump(tester, withProject: true);

    _containerOf(
      tester,
    ).read(projectPanelTabProvider.notifier).select(ProjectPanelTab.characters);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterLibraryPanel), findsOneWidget);
  });

  testWidgets('无活动项目时角色页没有数据源 → 退回画布页，不画空壳', (WidgetTester tester) async {
    await _pump(tester, withProject: false);

    _containerOf(
      tester,
    ).read(projectPanelTabProvider.notifier).select(ProjectPanelTab.characters);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterLibraryPanel), findsNothing);
  });
}
