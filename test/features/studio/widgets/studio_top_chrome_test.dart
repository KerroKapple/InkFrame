import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/widgets/studio_top_chrome.dart';

import '../../../_harness/test_app.dart';

void main() {
  testWidgets('StudioTopChrome 渲染 logo + breadcrumb + ⌘K + Settings + avatar',
      (tester) async {
    var settingsTaps = 0;
    await pumpInkApp(
      tester,
      Scaffold(
        body: StudioTopChrome(
          studioName: 'Kerro Studio',
          breadcrumbTail: 'All',
          onOpenSettings: () => settingsTaps += 1,
        ),
      ),
      surfaceSize: const Size(1440, 200),
    );

    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Kerro Studio'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    // 非 macOS 平台（测试默认 android）显示 Ctrl 修饰键。
    expect(find.text('Ctrl K'), findsOneWidget);
    expect(find.text('K'), findsWidgets);

    final size = tester.getSize(find.byType(StudioTopChrome));
    expect(size.height, 56);

    final settingsButton =
        find.byKey(StudioTopChrome.settingsButtonKey);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(settingsTaps, 1);
  });

  testWidgets('StudioTopChrome onOpenSettings 为 null 时仍渲染但不响应',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: StudioTopChrome(
          studioName: 'Kerro Studio',
          breadcrumbTail: 'All',
        ),
      ),
      surfaceSize: const Size(1440, 200),
    );
    expect(find.byKey(StudioTopChrome.settingsButtonKey), findsOneWidget);
  });

  testWidgets('macOS 平台 ⌘K chip 显示 ⌘ 修饰键', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await pumpInkApp(
      tester,
      const Scaffold(
        body: StudioTopChrome(
          studioName: 'Kerro Studio',
          breadcrumbTail: 'All',
        ),
      ),
      surfaceSize: const Size(1440, 200),
    );
    expect(find.text('⌘ K'), findsOneWidget);
    // 必须在测试体内复位，否则 binding 不变量检查报错。
    debugDefaultTargetPlatformOverride = null;
  });
}
