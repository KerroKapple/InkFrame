// ShellChrome：全树唯一 chrome 的内容契约 + ⚙ 设置浮层入口。
//
// 「⚙ 点击 → overlay=settings」这条用例【搬运】自 studio_home_test.dart
// （原名「StudioHome 顶栏 Settings 入口」）——⚙ 只是从 Studio 顶栏上移到外壳
// chrome，覆盖面不许随 StudioTopChrome 一起消失。Key 取值也原样保留。
//
// logo / 面包屑三条断言搬运自已删除的 studio_top_chrome_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_chrome.dart';

import '../../_harness/shell_app.dart';

void main() {
  testWidgets('chrome 渲染 Ink/Frame logo + 面包屑 + ⌘K chip', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_chrome_content_');
    await pumpInkShell(tester, paths: paths);

    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    // 未选项目 ⇒ 面包屑第二段是 shellBreadcrumbNoProject。
    expect(find.text('No project'), findsOneWidget);
    // 非 macOS 平台（测试默认 android）显示 Ctrl 修饰键。
    expect(find.text('Ctrl K'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('面包屑带项目名；canvasId 为 null 时不出画布段', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_chrome_project_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(project: ProjectRef(id: 'p1', name: 'Alpha')),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('No project'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('⚙ 点击 → overlay 变成 settings', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_chrome_settings_');
    await pumpInkShell(tester, paths: paths);
    final container = readShellContainer(tester);

    expect(container.read(shellControllerProvider).overlay, isNull);
    final settingsButton = find.byKey(ShellChrome.settingsButtonKey);
    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton, warnIfMissed: false);
    // chrome 在 DragToMoveArea 里：单击需过 kDoubleTapTimeout(300ms) 仲裁窗口。
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container.read(shellControllerProvider).overlay,
      ShellOverlay.settings,
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
