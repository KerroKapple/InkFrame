// 删除入口必须同时让外壳上下文失效（BOARD「删掉正在打开的画布 / 项目后外壳上下文悬空」）。
//
// 钉的是【接线】那一半：Studio 的「管理画布」对话框与项目卡「删除」，删成功后
// 必须让 ShellState 不再指着被删对象。效果那一半（保活槽真被销毁、各标签不再
// 指着它）在 test/features/shell/shell_close_context_test.dart。
//
// 两条反向用例同样重要：删【别的】画布 / 项目时外壳一动不动——无条件清上下文
// 会把用户正在编辑的那张画布连带关掉，比原 bug 更难查。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/studio/widgets/project_card.dart';

import '../../_harness/fake_repositories.dart';
import '../../_harness/test_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

/// 只记 id：InMemory 版的 softDelete 要求行已存在，而本用例的库是
/// workspaceProjectsProvider 直接播种的（没有真实行）。
class _RecordingCanvasRepo extends InMemoryCanvasRepository {
  final List<String> softDeleted = <String>[];

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    return 1;
  }
}

class _RecordingProjectRepo extends InMemoryProjectRepository {
  final List<String> softDeleted = <String>[];

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    return 1;
  }
}

List<ProjectWithCanvases> _library() => <ProjectWithCanvases>[
      ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha',
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 2),
        canvases: const <CanvasRef>[
          CanvasRef(id: 'cv-1', name: 'Open one'),
          CanvasRef(id: 'cv-2', name: 'Other one'),
        ],
      ),
      ProjectWithCanvases(
        id: 'p2',
        name: 'Beta',
        createdAt: DateTime.utc(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 2),
        canvases: const <CanvasRef>[CanvasRef(id: 'cv-9', name: 'Beta one')],
      ),
    ];

/// 返回外壳容器，供用例读回 ShellState。
Future<ProviderContainer> _pumpStudio(
  WidgetTester tester, {
  required ShellState initial,
  required _RecordingCanvasRepo canvases,
  required _RecordingProjectRepo projects,
}) async {
  await pumpInkApp(
    tester,
    const StudioHomeScreen(),
    surfaceSize: const Size(1440, 900),
    overrides: <Override>[
      shellControllerProvider
          .overrideWith(() => ShellNavigator(initial: initial)),
      workspaceProjectsProvider.overrideWith((_) async => _library()),
      projectRepositoryProvider.overrideWith((_) async => projects),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StudioHomeScreen)));
}

/// 打开某项目卡的 ⋯ 菜单并点一项。卡片按 updatedAt 倒序，Alpha 在前。
Future<void> _cardMenu(WidgetTester tester, String item,
    {int cardIndex = 0}) async {
  // 菜单键的类型参数是私有枚举，byType 配不上 ⇒ 按 tooltip 定位。
  await tester.tap(
    find.descendant(
      of: find.byType(StudioProjectCard).at(cardIndex),
      matching: find.byTooltip('Project options'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

/// 在「管理画布」对话框里删掉某画布（行内垃圾桶 → 确认）。
Future<void> _deleteCanvasRow(WidgetTester tester, String canvasName) async {
  await tester.tap(
    find.descendant(
      of: find.ancestor(
        of: find.text(canvasName),
        matching: find.byType(Row),
      ).first,
      matching: find.byIcon(Icons.delete_outline),
    ),
  );
  await tester.pumpAndSettle();
  // 确认框：标题 'Delete canvas?' + 'Delete' 按钮。
  expect(find.text('Delete canvas?'), findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton, 'Delete'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('删掉正在打开的那张画布：外壳不再指着它（project 不动）',
      (tester) async {
    final canvases = _RecordingCanvasRepo();
    final container = await _pumpStudio(
      tester,
      initial: const ShellState(
          tab: ShellTab.studio, canvasId: 'cv-1', project: _alpha),
      canvases: canvases,
      projects: _RecordingProjectRepo(),
    );

    await _cardMenu(tester, 'Manage canvases');
    await _deleteCanvasRow(tester, 'Open one');

    expect(canvases.softDeleted, contains('cv-1'), reason: '前置：软删真发生了');
    final ShellState s = container.read(shellControllerProvider);
    expect(s.canvasId, isNull,
        reason: '否则用户点回「画布」标签还能继续编辑一张刚删掉的画布');
    expect(s.project, _alpha,
        reason: '删一张画布不等于离开项目——画廊应留在原项目上');
  });

  testWidgets('删掉别的画布：外壳上下文一动不动（反向）', (tester) async {
    final canvases = _RecordingCanvasRepo();
    final container = await _pumpStudio(
      tester,
      initial: const ShellState(
          tab: ShellTab.studio, canvasId: 'cv-1', project: _alpha),
      canvases: canvases,
      projects: _RecordingProjectRepo(),
    );

    await _cardMenu(tester, 'Manage canvases');
    await _deleteCanvasRow(tester, 'Other one');

    expect(canvases.softDeleted, contains('cv-2'), reason: '前置：软删真发生了');
    expect(
      container.read(shellControllerProvider),
      const ShellState(
          tab: ShellTab.studio, canvasId: 'cv-1', project: _alpha),
      reason: '无条件清上下文会把用户正在编辑的画布连带关掉，比原 bug 更难查',
    );
  });

  testWidgets('删掉当前项目：project 与 canvasId 一起清',
      (tester) async {
    final projects = _RecordingProjectRepo();
    final container = await _pumpStudio(
      tester,
      initial: const ShellState(
          tab: ShellTab.gallery, canvasId: 'cv-1', project: _alpha),
      canvases: _RecordingCanvasRepo(),
      projects: projects,
    );

    await _cardMenu(tester, 'Delete project');
    expect(find.text('Delete project?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(projects.softDeleted, contains('p1'), reason: '前置：软删真发生了');
    final ShellState s = container.read(shellControllerProvider);
    expect(s.project, isNull,
        reason: '画廊 / 序列 / 导出 / 面包屑 / ⌘K 全读 ShellState.project');
    expect(s.canvasId, isNull,
        reason: 'canvasId 属于被删项目，只清 project 等于把悬空换个字段放');
  });

  testWidgets('删掉别的项目：外壳上下文一动不动（反向）', (tester) async {
    final projects = _RecordingProjectRepo();
    final container = await _pumpStudio(
      tester,
      initial: const ShellState(
          tab: ShellTab.gallery, canvasId: 'cv-1', project: _alpha),
      canvases: _RecordingCanvasRepo(),
      projects: projects,
    );

    // 卡片按 updatedAt 倒序 ⇒ index 1 是 Beta。
    await _cardMenu(tester, 'Delete project', cardIndex: 1);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(projects.softDeleted, contains('p2'), reason: '前置：软删真发生了');
    expect(
      container.read(shellControllerProvider),
      const ShellState(
          tab: ShellTab.gallery, canvasId: 'cv-1', project: _alpha),
      reason: '删的是 Beta，Alpha 的项目上下文与画布都不该被碰',
    );
  });
}
