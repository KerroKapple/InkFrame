// SettingsTopChrome 顶栏测试。
//
// 注：SettingsScreen 整体含 StoragePathSection，其 Ink* ticker 会让 pump 在
// teardown 留 pending frame 触发 isolate 超时，故只 pump 被改动的真实单元
// SettingsTopChrome（不含 section）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/settings/widgets/settings_top_chrome.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SettingsTopChrome()),
      ),
    );

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('用 InkWindowChrome 提供窗口控制，而非 Material AppBar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(InkWindowChrome), findsOneWidget);
    // 窗口三键之最小化键存在（语义标签 Minimize）
    expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('点击返回键把 currentScreenProvider 切回 studio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    container.read(currentScreenProvider.notifier).state = AppScreen.settings;
    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(container.read(currentScreenProvider), AppScreen.settings);
    // DragToMoveArea 的 onDoubleTap 会把单击识别延迟 kDoubleTapTimeout(300ms)，
    // pump 越过它让单击落地。
    await tester.tap(find.byKey(SettingsTopChrome.backButtonKey));
    await tester.pump(const Duration(milliseconds: 350));
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
