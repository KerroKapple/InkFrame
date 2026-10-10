// 画布视口尺寸在保活槽里不丢（去掉 canvasViewportSizeProvider 的 keepAlive 之前
// 必须先把这条钉死）。
//
// 【为什么这条必须在外壳级而不是画布级】视口尺寸的 provider 没有任何 watcher，
// 全部读点都在回调里（缩放、新建节点落点）。它过去靠 ref.keepAlive() 活着，
// 于是"切走标签再切回来尺寸还在"是**免费的**；换成"订阅锚挂在 CanvasShortcuts"
// 之后，这件事改由"保活槽让画布标签始终挂载"来保证——而那是外壳的性质，
// 画布级 pump 测不到。
//
// 两种不可见都要覆盖，且走的是同一个谓词（ShellState.isTabVisible）：
// ① 切走标签  ② 浮层盖住。不可见 ≠ 卸载，所以两种都不该丢尺寸。
//
// 【实测变异】把 CanvasShortcuts.build 里那条
//   `if (canvasId != null) ref.watch(canvasViewportSizeProvider(canvasId));`
// 删掉 ⇒ 两条用例都在「前置」那一步就红（Expected: not Size(0.0, 0.0)），
// 因为没有订阅者的 entry 在 setSize 后的下一拍就被回收并复位 Size.zero。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/shell_app.dart';

Size _viewport(ProviderContainer c) =>
    c.read(canvasViewportSizeProvider('cv-1'));

void main() {
  testWidgets('切走画布标签再切回：视口尺寸不丢', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_viewport_tab_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );
    final ProviderContainer container = readShellContainer(tester);
    final ShellNavigator nav = container.read(shellControllerProvider.notifier);

    final Size reported = _viewport(container);
    expect(
      reported,
      isNot(Size.zero),
      reason: '前置：画布标签在台 ⇒ 舞台层 LayoutBuilder 已把视口尺寸上报',
    );

    nav.goTab(ShellTab.studio);
    await tester.pump();
    await tester.pump();

    expect(
      _viewport(container),
      reported,
      reason: '画布只是离台、没被卸载 ⇒ 订阅锚仍在 ⇒ 尺寸不该被回收',
    );

    nav.goTab(ShellTab.canvas);
    await tester.pump();
    await tester.pump();

    expect(
      _viewport(container),
      reported,
      reason: '切回来必须还是原尺寸——复位成 Size.zero 会让 ⌘± 围绕 (0,0) 缩放、'
          '新建节点落点也回退到旧的固定随机区',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('浮层盖住画布再关掉：视口尺寸不丢', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_viewport_overlay_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );
    final ProviderContainer container = readShellContainer(tester);
    final ShellNavigator nav = container.read(shellControllerProvider.notifier);

    final Size reported = _viewport(container);
    expect(reported, isNot(Size.zero), reason: '前置：视口已上报');

    nav.openOverlay(ShellOverlay.settings);
    await tester.pump();
    await tester.pump();
    nav.closeOverlay();
    await tester.pump();
    await tester.pump();

    expect(
      _viewport(container),
      reported,
      reason: '开关一次设置浮层不该让画布忘掉自己的视口尺寸',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
