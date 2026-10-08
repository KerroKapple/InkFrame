// 设置浮层（Screens 稿第 3 屏）的外形与关闭途径。
//
// 走 pumpInkShell 而非整页 pump：StoragePathSection 在本 toolchain 下留
// pending frame，外壳 harness 只做固定次数 pump()，不 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/settings/widgets/about_section.dart';
import 'package:inkframe/features/settings/widgets/api_keys_section.dart';
import 'package:inkframe/features/settings/widgets/backup_section.dart';
import 'package:inkframe/features/settings/widgets/canvas_appearance_section.dart';
import 'package:inkframe/features/settings/widgets/custom_providers_section.dart';
import 'package:inkframe/features/settings/widgets/diagnostics_section.dart';
import 'package:inkframe/features/settings/widgets/language_section.dart';
import 'package:inkframe/features/settings/widgets/network_section.dart';
import 'package:inkframe/features/settings/widgets/performance_section.dart';
import 'package:inkframe/features/settings/widgets/shortcuts_section.dart';
import 'package:inkframe/features/settings/widgets/startup_section.dart';
import 'package:inkframe/features/settings/widgets/storage_path_section.dart';
import 'package:inkframe/features/settings/widgets/theme_section.dart';
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

  // 九个既有 section 的存在性断言（StartupSection 已在第一条覆盖，不重复）。
  // 各 section 自身行为有独立单测，但从 _PageBody 的某页里删掉一个，那些单测照样
  // 全绿——用户却再也进不去那块设置。一次只挂一页，所以逐页经左导航切过去再断言；
  // 常规页排在最后，确保它也是「切回来」而不是默认落地时断言的。
  // 每个 section 一条 expect，失败时 reason 直接点名缺的是哪一个。
  const Map<SettingsPage, List<(Type, String)>> sectionsByPage =
      <SettingsPage, List<(Type, String)>>{
    SettingsPage.apiKeys: <(Type, String)>[
      (ApiKeysSection, 'ApiKeysSection 缺席 → 无处填 provider API key'),
      (CustomProvidersSection, 'CustomProvidersSection 缺席 → 无法管理自定义 OpenAI 兼容端点'),
    ],
    SettingsPage.shortcuts: <(Type, String)>[
      (ShortcutsSection, 'ShortcutsSection 缺席 → 查不到键位清单'),
    ],
    SettingsPage.performance: <(Type, String)>[
      (PerformanceSection, 'PerformanceSection 缺席 → 看不到并发与配额上限'),
    ],
    SettingsPage.nodeLayout: <(Type, String)>[
      (CanvasAppearanceSection, 'CanvasAppearanceSection 缺席 → 无法调连线/卡片颜色'),
    ],
    SettingsPage.network: <(Type, String)>[
      (NetworkSection, 'NetworkSection 缺席 → 看不到 env 代理当前状态'),
    ],
    SettingsPage.storage: <(Type, String)>[
      (StoragePathSection, 'StoragePathSection 缺席 → 看不到数据库目录'),
      (BackupSection, 'BackupSection 缺席 → 无法备份/还原数据库'),
    ],
    SettingsPage.about: <(Type, String)>[
      (AboutSection, 'AboutSection 缺席 → 看不到版本/许可/更新检查'),
      (DiagnosticsSection, 'DiagnosticsSection 缺席 → 打不开日志目录、导不出诊断包'),
    ],
    SettingsPage.general: <(Type, String)>[
      (ThemeSection, 'ThemeSection 缺席 → 无法切换主题/文字缩放'),
      (LanguageSection, 'LanguageSection 缺席 → 无法切换界面语言'),
    ],
  };

  test('存在性断言表覆盖每一页、合计十二个 section', () {
    expect(sectionsByPage.keys.toSet(), SettingsPage.values.toSet(),
        reason: '新增页却没进表 = 该页 section 无存在性断言');
    // 九个既有 + P7 的快捷键 / 性能 / 网络三个。
    expect(sectionsByPage.values.expand((l) => l).length, 12);
  });

  for (final MapEntry<SettingsPage, List<(Type, String)>> entry
      in sectionsByPage.entries) {
    testWidgets('左导航切到「${entry.key.name}」→ 该页 section 各在台',
        (tester) async {
      final paths = await setupTempPaths(
          tester, 'ink_settings_presence_${entry.key.name}_');
      await pumpInkShell(
        tester,
        paths: paths,
        initial: const ShellState(overlay: ShellOverlay.settings),
      );
      if (entry.key == SettingsPage.general) {
        // 常规页是默认页：先切走，再经导航切回来。
        await tester.tap(find.byKey(SettingsScreen.navKey(SettingsPage.about)));
        await tester.pump();
        await tester.pump();
        expect(find.byType(ThemeSection), findsNothing);
      }

      await tester.tap(find.byKey(SettingsScreen.navKey(entry.key)));
      await tester.pump();
      await tester.pump();

      for (final (Type type, String reason) in entry.value) {
        expect(find.byType(type), findsOneWidget, reason: reason);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));
  }

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
