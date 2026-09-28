// 设置浮层（Screens 稿第 3 屏）的外形与关闭途径。
//
// 走 pumpInkShell 而非整页 pump：StoragePathSection 在本 toolchain 下留
// pending frame，外壳 harness 只做固定次数 pump()，不 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/settings/widgets/api_keys_section.dart';
import 'package:inkframe/features/settings/widgets/startup_section.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/shell_app.dart';

void main() {
  // R50 的后继：横栏曾是 InkToolBar(44)（换回 AppBar(56) 会让 960×600 下内容区掉回 444）。
  // 浮层形态下标题栏是稿的 40 + 1px 下沿；AppBar 仍然禁止出现。这条断言不能指望
  // settings_screen 那张 golden——它在重铸清单上，重铸会把回归一起烤进新基线。
  testWidgets('设置是居中对话框：标题栏 40+1、没有 AppBar；默认落在常规页（含启动开关）',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_dialog_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    expect(tester.getSize(find.byKey(SettingsScreen.titleBarKey)).height, 41);
    expect(
      find.byType(AppBar, skipOffstage: false),
      findsNothing,
      reason: '换回 AppBar = 三层横栏 156，内容区掉回 444',
    );
    // 稿的对话框是 1120×740（content-box）；1440×900 的外壳放得下，不该被压扁。
    final Size dialog = tester.getSize(find.byKey(SettingsScreen.titleBarKey));
    expect(dialog.width, SettingsScreen.dialogWidth);
    // T12 卫生项(c)：StartupSection 是常规页的接线，删掉它用户就再也改不了那个开关。
    expect(find.byType(StartupSection), findsOneWidget);
    expect(find.byType(ApiKeysSection), findsNothing, reason: '一次只挂一页');
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('左导航切页：点「API 密钥」→ Key 表在台，常规页离树', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_nav_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    await tester.tap(find.byKey(SettingsScreen.navKey(SettingsPage.apiKeys)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ApiKeysSection), findsOneWidget);
    expect(find.byType(StartupSection), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('✕ 关闭浮层', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_close_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    await tester.tap(find.byKey(SettingsScreen.closeKey));
    await tester.pump();
    await tester.pump();

    expect(readShellContainer(tester).read(shellControllerProvider).overlay, isNull);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing, reason: '浮层不保活');
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('底部条「完成」关闭浮层', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_settings_done_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(overlay: ShellOverlay.settings),
    );

    await tester.tap(find.byKey(SettingsScreen.doneKey));
    await tester.pump();
    await tester.pump();

    expect(readShellContainer(tester).read(shellControllerProvider).overlay, isNull);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
