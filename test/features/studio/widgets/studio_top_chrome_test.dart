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
    expect(find.text('⌘ K'), findsOneWidget);
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
}
