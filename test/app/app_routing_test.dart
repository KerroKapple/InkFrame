// Shell 路由 widget test：验证外壳（InkShell）在 ShellState 切换时把哪个 surface
// 摆上台、哪个保活在台下。
//
// 【T7 起断言语义变了】五（现为七）例全部改走 expectShellSurface 的三条正交通道：
// 在树（skipOffstage: false）/ 在台（默认 skipOffstage）/ 可命中。
// 只写「在台」通道会漏掉保活回归，只写「在树」通道会漏掉切换回归——两条都要。
//
// find.byType 默认 skipOffstage: true 会跳过 Offstage 子树：任何不显式写
// skipOffstage: false 的保活断言都是假绿。反向变异（把在树通道改回默认）
// 必须【不红】，见 task-7-report.md。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/showcase/widgets/built_in_showcase_screen.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';

import '../_harness/shell_app.dart';
import '../_harness/shell_expect.dart';

void main() {
  testWidgets('unlocked + studio 标签 → Studio 在台；设置浮层槽从未物化',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_studio_');
    await pumpInkShell(tester, paths: paths);

    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
      reason: '默认标签就是 studio',
    );
    expectShellSurface<SettingsScreen>(
      mounted: false,
      onstage: false,
      hittable: false,
      reason: '从未打开过设置，浮层槽应是 SizedBox.shrink',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('unlocked + settings 浮层 → 设置在台，Studio 保活离台', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_settings_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    expectShellSurface<SettingsScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
      reason: 'tab 仍是 studio（浮层不改 tab）⇒ 槽已物化，但被浮层盖住',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('unlocked + gallery 标签 → 画廊在台；Studio 槽从未物化', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_gallery_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
        tab: ShellTab.gallery,
        project: ProjectRef(id: 'p1', name: 'Alpha'),
      ),
    );

    expectShellSurface<GalleryScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    // 懒物化：初始标签是 gallery，studio 槽这辈子还没被点过 ⇒ 真的不在树里。
    // 这一条是 V4 成立的物理前提（宿主 eager 建五子的变异必须打红它）。
    expectShellSurface<StudioHomeScreen>(
      mounted: false,
      onstage: false,
      hittable: false,
      reason: '从未激活过 studio 标签 ⇒ 槽内仍是 SizedBox.shrink',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // 评审 P1-2：ShellOverlay.showcase 此前 shell 路由零覆盖——把分支改成渲染别的
  // 页，全量测试照样绿。本例与下一例把它钉死。
  testWidgets('unlocked + showcase 浮层 → 示例页在台，Studio 保活离台', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_showcase_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.showcase),
    );

    expectShellSurface<BuiltInShowcaseScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // T6 fix round 1（R25）起本例断「浮层赢」；T7 把语义进一步说清楚：不是
  // 「画布输了」，而是【浮层永远在上、画布保活在下】——所以画布必须 mounted。
  testWidgets('浮层在上、画布保活在下：canvasId 非空 + showcase', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_showcase_prio_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.showcase,
        canvasId: 'cv-1',
      ),
    );

    expectShellSurface<BuiltInShowcaseScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    expectShellSurface<CanvasScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
      reason: '浮层盖住 ⇒ 画布离台且点不穿，但仍在树里（保活）',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // R25：画布已打开时 openOverlay(settings) 不是死键。
  testWidgets('画布已打开 + openOverlay(settings) → 设置在台，画布保活在下',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_settings_over_canvas_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.settings,
        canvasId: 'cv-1',
      ),
    );

    expectShellSurface<SettingsScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    expectShellSurface<CanvasScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  // R33（T6 fix round 2）：画布态 goTab(studio) 必须真的换台。
  // T7 起追加保活断言：画布【不再消失】，而是离台但仍在树里——这正是本 PR 的
  // 核心行为变更，也是「切标签时把非活动槽换回 SizedBox.shrink」那条变异的靶子。
  testWidgets('画布态 goTab(studio) → Studio 在台，画布离台但保活', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_route_canvas_back_to_studio_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );

    expectShellSurface<CanvasScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
      reason: '起始态：画布在台',
    );

    readShellContainer(tester)
        .read(shellControllerProvider.notifier)
        .goTab(ShellTab.studio);
    await tester.pump();
    await tester.pump();

    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
    );
    expectShellSurface<CanvasScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
      reason: 'V1 保活：切走标签不销毁画布子树',
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
