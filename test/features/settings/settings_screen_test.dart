// 设置页返回键（shell 路由）单测。
//
// 返回键抽成独立小件测（不整页 pump）：StoragePathSection 在本 toolchain 下有
// ticker 挂起坑（见 storage_path_section_test 头注）。横栏形态那条走 pumpInkShell
// ——外壳 harness 只做固定次数 pump()，不 pumpAndSettle，同样绕开那个坑。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/settings/widgets/startup_section.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/theme/components/ink_tool_bar.dart';

import '../../_harness/shell_app.dart';
import '../../_harness/test_app.dart';

void main() {
  // R50：`InkToolBar` 全仓零测试引用——把它换回 `AppBar` 跑全量一片绿。
  // 后果是 960×600 下内容区从 500 掉回 444（chrome 56 + 标签条 44 + AppBar 56），
  // 正是用户明确拍板不可接受的那个数。唯一会察觉的是 settings_screen 那张
  // golden，**而它正在 T13 的重铸清单上**——重铸会把回归一起烤进新基线，
  // 从此再无人发现。所以这条断言必须在这里，不能指望 golden。
  //
  // 走 pumpInkShell 而非整页 pump：StoragePathSection 在本 toolchain 下留
  // pending frame，外壳 harness 只做固定次数 pump()，不 pumpAndSettle。
  testWidgets('设置浮层的横栏是 InkToolBar(44)，不是 AppBar(56)', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_toolbar_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    expect(find.byType(InkToolBar), findsOneWidget);
    expect(tester.getSize(find.byType(InkToolBar)).height, 44);
    expect(
      find.byType(AppBar, skipOffstage: false),
      findsNothing,
      reason: '换回 AppBar = 三层横栏 156，内容区掉回 444',
    );
    // T12 卫生项(c)：StartupSection 是本 PR 新增的接线（settings_screen.dart:70），
    // 删掉它用户就再也改不了那个开关，而门禁全绿——只给这一个新增 section 补
    // 存在性断言，其余九个是既有状态，批量补属于范围蔓延（另开卡）。
    expect(find.byType(StartupSection), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('返回键点击 → 关闭浮层', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: SettingsBackButton()),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsBackButton)),
      listen: false,
    );
    container
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.settings);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(container.read(shellControllerProvider).overlay, isNull);
  });
}
