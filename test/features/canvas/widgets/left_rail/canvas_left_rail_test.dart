// 画布左栏导航条（PR-4）：外壳级 pump，真点、真按。
//
// 钉的是派工单 §1 / §2 / §6 / §7 的交互：页键（点非当前页 = 展开并切页，点当前页 = 收起）、
// 收起键开合、Ctrl+\ 开合且打字时让位、收起后舞台左沿与导航条右沿相接、快捷键键落在设置的
// 快捷键页；再加原 canvas_project_panel_tab_test 搬过来的那条：角色页只在有活动项目时才是角色库。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/left_rail_state.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/character_library_panel.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_panel.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/canvas_left_rail.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/left_rail_panel.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/outline_panel.dart';
import 'package:inkframe/features/settings/providers/settings_page.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/a11y.dart';
import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_character.dart';
import '../../../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

List<Override> _overrides() => <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      characterRepositoryProvider.overrideWith((_) async => FakeCharacterRepo()),
      characterAssetServiceProvider.overrideWithValue(FakeCharacterAssetService()),
    ];

Future<ProviderContainer> _pump(WidgetTester tester, {ProjectRef? project = _alpha}) async {
  final paths = await setupTempPaths(tester, 'ink_left_rail_');
  await pumpInkShell(
    tester,
    paths: paths,
    initial: ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: project),
    extraOverrides: _overrides(),
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump();
  }
  return readShellContainer(tester);
}

Future<void> _tapRail(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(CanvasLeftRail.keyOf(id)));
  await tester.pump();
  await tester.pump();
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CanvasLeftRail)));

void main() {
  testWidgets('页键：点非当前页 → 展开并切页；点当前页 → 收起；收着时点页键 → 展开', (tester) async {
    final ProviderContainer c = await _pump(tester);
    expect(find.byType(OutlinePanel), findsOneWidget, reason: '默认展开在大纲页');

    await _tapRail(tester, LeftRailPage.assets.name);
    expect(c.read(leftRailProvider), const LeftRailState(page: LeftRailPage.assets));
    expect(find.byType(AssetsPanel), findsOneWidget);
    expect(find.byType(OutlinePanel), findsNothing);

    await _tapRail(tester, LeftRailPage.assets.name);
    expect(c.read(leftRailProvider).expanded, isFalse, reason: '点展开着的当前页 = 收起');
    expect(find.byType(AssetsPanel), findsNothing);
    expect(tester.getSize(find.byType(CanvasLeftRailPanel)).width, 0, reason: '收起后面板不占宽');

    await _tapRail(tester, LeftRailPage.characters.name);
    expect(c.read(leftRailProvider), const LeftRailState(page: LeftRailPage.characters));
    expect(find.byType(CharacterLibraryPanel), findsOneWidget);

    await _tapRail(tester, LeftRailPage.outline.name);
    expect(find.byType(OutlinePanel), findsOneWidget);
    expect(find.byType(CharacterLibraryPanel), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('收起键开合、页不变；tooltip 带键位（非 macOS：Ctrl+\\）', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _tapRail(tester, LeftRailPage.assets.name);
    final AppLocalizations l = _l(tester);

    final Tooltip open = tester.widget<Tooltip>(
      find.descendant(of: find.byKey(CanvasLeftRail.keyOf('toggle')), matching: find.byType(Tooltip)),
    );
    expect(open.message, '${l.leftRailCollapse}  ' r'Ctrl+\');

    await _tapRail(tester, 'toggle');
    expect(c.read(leftRailProvider), const LeftRailState(page: LeftRailPage.assets, expanded: false));
    expect(find.byType(AssetsPanel), findsNothing);
    final Tooltip closed = tester.widget<Tooltip>(
      find.descendant(of: find.byKey(CanvasLeftRail.keyOf('toggle')), matching: find.byType(Tooltip)),
    );
    expect(closed.message, '${l.leftRailExpand}  ' r'Ctrl+\', reason: '收着时这一键是「展开」');

    await _tapRail(tester, 'toggle');
    expect(c.read(leftRailProvider), const LeftRailState(page: LeftRailPage.assets));
    expect(find.byType(AssetsPanel), findsOneWidget, reason: '再展开回到原页');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('收起键键盘可达：聚焦后回车走同一条开合', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await activateByKey(tester, activatableFocus(tester, CanvasLeftRail.keyOf('toggle')));
    await tester.pump();
    expect(c.read(leftRailProvider).expanded, isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(r'Ctrl+\ 开合左栏；在筛选框里打字时让位，不收左栏', (tester) async {
    final ProviderContainer c = await _pump(tester);
    expect(c.read(leftRailProvider).expanded, isTrue);

    await sendCtrl(tester, LogicalKeyboardKey.backslash);
    await tester.pump();
    expect(c.read(leftRailProvider).expanded, isFalse);
    expect(find.byType(OutlinePanel), findsNothing);

    await sendCtrl(tester, LogicalKeyboardKey.backslash);
    await tester.pump();
    expect(c.read(leftRailProvider).expanded, isTrue);
    expect(find.byType(OutlinePanel), findsOneWidget);

    // 焦点进大纲的筛选框：这时 Ctrl+\ 是文本框的事，左栏不能被收起来。
    await tester.tap(
      find.descendant(of: find.byKey(OutlinePanel.filterKey), matching: find.byType(TextField)),
    );
    await tester.pump();
    await sendCtrl(tester, LogicalKeyboardKey.backslash);
    await tester.pump();
    expect(c.read(leftRailProvider).expanded, isTrue, reason: '打字时 Ctrl+\\ 让位给文本编辑');
    expect(find.byType(OutlinePanel), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('导航条 43 宽；展开时面板 241 夹在中间；收起后舞台左沿与导航条右沿相接', (tester) async {
    final ProviderContainer c = await _pump(tester);
    final Rect rail = tester.getRect(find.byType(CanvasLeftRail));
    expect(rail.width, CanvasLeftRail.width);

    Rect stage = tester.getRect(find.byType(CanvasView));
    expect(stage.left, closeTo(rail.right + CanvasLeftRailPanel.width, 0.5));

    c.read(leftRailProvider.notifier).toggle();
    await tester.pump();
    await tester.pump();
    stage = tester.getRect(find.byType(CanvasView));
    expect(stage.left, closeTo(rail.right, 0.5), reason: '收起后舞台直接贴导航条');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('快捷键键：打开设置浮层并落在「快捷键」页', (tester) async {
    final ProviderContainer c = await _pump(tester);
    expect(c.read(settingsPageProvider), isNot(SettingsPage.shortcuts), reason: '前置：默认不在快捷键页');

    await _tapRail(tester, 'shortcuts');
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings);
    expect(c.read(settingsPageProvider), SettingsPage.shortcuts);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // 原 canvas_project_panel_tab_test 的两条：角色页 ↔ 正文的接线。
  testWidgets('角色页 + 有活动项目 → 正文真的是角色库', (tester) async {
    await _pump(tester);
    await _tapRail(tester, LeftRailPage.characters.name);
    expect(find.byType(CharacterLibraryPanel), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('角色页 + 无活动项目 → 没有数据源：不画角色库，给一句说明', (tester) async {
    await _pump(tester, project: null);
    await _tapRail(tester, LeftRailPage.characters.name);
    expect(find.byType(CharacterLibraryPanel), findsNothing);
    expect(find.text(_l(tester).leftRailCharactersNoProject), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
