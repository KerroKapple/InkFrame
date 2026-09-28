// 设置浮层接线的四条拍板（用户 2026-09-24，README §5）：
//   ① Esc 分层：编辑框开着时 Esc 只关编辑框；没有编辑框时 Esc 关浮层，且标签 / 画布状态不变。
//   ② 打开 / 关闭浮层不写路由：画布上缩放 + 选中 → 开设置再关 → 视口与选中集与打开前一致。
//   ③ Studio 无 Key 引导条的「前往设置」打开的是浮层（原界面遮暗可见、点不穿）。
// 全外壳测试禁 pumpAndSettle（见 test/_harness/shell_app.dart）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/studio/widgets/studio_provider_banner.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';
import '../../_harness/shell_expect.dart';

List<Override> _canvasOverrides() => <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ];

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');
const ShellState _onCanvas = ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha);

Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer, skipOffstage: false))
    .transformationController!
    .value;

Future<void> _pumpFrames(WidgetTester tester, [int n = 4]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _pumpFrames(tester);
}

void main() {
  testWidgets('Esc 分层 ①：自定义服务商编辑框开着时，Esc 只关编辑框，浮层不动', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_esc_editor_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );
    await tester.tap(find.byKey(SettingsScreen.navKey(SettingsPage.apiKeys)));
    await _pumpFrames(tester);
    await tester.tap(find.text('Add custom provider…'));
    await _pumpFrames(tester);
    expect(find.text('Add custom provider'), findsOneWidget, reason: '前置：编辑框（对话框标题）已打开');

    await _escape(tester);

    expect(find.text('Add custom provider'), findsNothing, reason: 'Esc 关掉的是编辑框');
    expect(
      readShellContainer(tester).read(shellControllerProvider).overlay,
      ShellOverlay.settings,
      reason: 'D11 那条债的靶子：编辑框和浮层不能一起退出',
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Esc 分层 ②：没有编辑框时 Esc 关浮层；标签与画布状态保持不变', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_esc_overlay_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1', project: _alpha, overlay: ShellOverlay.settings),
      extraOverrides: _canvasOverrides(),
    );
    await _pumpFrames(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await _escape(tester);

    final ShellState s = readShellContainer(tester).read(shellControllerProvider);
    expect(s.overlay, isNull);
    expect(s.tab, ShellTab.canvas, reason: '关浮层不切标签');
    expect(s.canvasId, 'c1', reason: '关浮层不清 canvasId');
    expect(s.project, _alpha);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('不写路由：画布缩放 + 选中两个节点 → 开设置再 Esc 关 → 视口与选中集不变', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_no_route_');
    await pumpInkShell(tester, paths: paths, initial: _onCanvas, extraOverrides: _canvasOverrides());
    final ProviderContainer c = readShellContainer(tester);
    c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['a', 'b']);
    await _pumpFrames(tester);
    await sendCtrl(tester, LogicalKeyboardKey.equal);
    await _pumpFrames(tester);
    final Matrix4 before = _ivTransform(tester);
    expect(before, isNot(initialCanvasTransform()), reason: '前提：⌘+ 真的改了变换，否则"矩阵不变"恒真');
    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a', 'b'});

    c.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);
    await _pumpFrames(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(c.read(shellControllerProvider).canvasId, 'c1', reason: '开浮层不清 canvasId');
    expect(c.read(shellControllerProvider).tab, ShellTab.canvas, reason: '开浮层不切标签');

    await _escape(tester);

    expect(c.read(shellControllerProvider).overlay, isNull);
    final Matrix4 after = _ivTransform(tester);
    for (int i = 0; i < 16; i++) {
      expect(after.storage[i], before.storage[i], reason: '视口变换第 $i 项');
    }
    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a', 'b'}, reason: '选中集不变');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Studio「前往设置」打开的是浮层：Studio 遮暗可见、点不穿', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_from_banner_');
    await pumpInkShell(
      tester,
      paths: paths,
      extraOverrides: <Override>[
        // 无 Key ⇒ 引导条出现。
        anyProviderKeyConfiguredProvider.overrideWith((_) async => false),
      ],
    );
    await _pumpFrames(tester);
    expect(find.byKey(StudioProviderBanner.actionKey), findsOneWidget, reason: '前置：无 Key 引导条在');

    await tester.tap(find.byKey(StudioProviderBanner.actionKey));
    await _pumpFrames(tester);

    expect(readShellContainer(tester).read(shellControllerProvider).overlay, ShellOverlay.settings);
    expectShellSurface<SettingsScreen>(mounted: true, onstage: true, hittable: true);
    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: true,
      hittable: false,
      reason: '浮层形态：原界面在下遮暗可见，被 ModalBarrier 挡住',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
