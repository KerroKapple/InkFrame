// Studio 首页恢复条「继续」的可达性（BOARD 214）。
//
// 它是首页上最常用的一个动作（上次离开的那张画布），此前点击壳是手搓的
// `Semantics + MouseRegion + GestureDetector`——键盘到不了。换成 theme 层的
// InkActivatable 后钉两件：能 Tab 到、Enter 走的是同一条 openCanvas。
//
// 恢复条本身此前没有任何用例（grep `studio.resume` 在 test/ 下零命中），所以这里
// 顺带把"它在什么条件下出现"也当作前提断言了一次——否则测试可能在恢复条压根没
// 渲染的情况下"全绿"。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../../_harness/a11y.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/test_app.dart';

/// 恢复条只在「开关开着 + 记录指向列表里仍存在的项目/画布」时出现。
final List<ProjectWithCanvases> _projects = <ProjectWithCanvases>[
  ProjectWithCanvases(
    id: 'p1',
    name: 'Alpha',
    createdAt: DateTime.utc(2026, 5, 1),
    canvases: const <CanvasRef>[CanvasRef(id: 'cv1', name: 'Scene 1')],
  ),
];

Future<ShellState> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const StudioHomeScreen(),
    surfaceSize: const Size(1440, 900),
    overrides: <Override>[
      workspaceProjectsProvider.overrideWith((_) async => _projects),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(
          const AppPreferences(lastProjectId: 'p1', lastCanvasId: 'cv1'),
        ),
      ),
      canvasRepositoryProvider.overrideWith(
        (_) async => InMemoryCanvasRepository(),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(StudioHomeScreen)),
  ).read(shellControllerProvider);
}

void main() {
  testWidgets('恢复条「继续」Tab 到得了', (tester) async {
    await _pump(tester);
    // 前提：恢复条真的在树上（否则下面测的是个不存在的控件）。
    expect(find.byKey(StudioHomeScreen.resumeKey), findsOneWidget);

    expect(
      await tabUntilFocused(
        tester,
        activatableFocus(tester, StudioHomeScreen.resumeKey),
      ),
      isTrue,
      reason: '首页最常用的动作不可聚焦 ⇒ 键盘用户进不去上次那张画布',
    );
  });

  testWidgets('Enter 激活 → 走的是同一条 openCanvas', (tester) async {
    final ShellState before = await _pump(tester);
    expect(before.tab, ShellTab.studio);

    await activateByKey(
      tester,
      activatableFocus(tester, StudioHomeScreen.resumeKey),
    );
    await tester.pumpAndSettle();

    final ShellState after = ProviderScope.containerOf(
      tester.element(find.byType(StudioHomeScreen)),
    ).read(shellControllerProvider);
    expect(after.tab, ShellTab.canvas, reason: '回车必须和鼠标点击走同一条 openCanvas');
    expect(after.canvasId, 'cv1');
    expect(after.project?.id, 'p1');
  });
}
