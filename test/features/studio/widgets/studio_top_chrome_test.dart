import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/widgets/studio_top_chrome.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('StudioTopChrome 渲染 logo + breadcrumb + ⌘K + avatar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: StudioTopChrome(
          studioName: 'Kerro Studio',
          breadcrumbTail: 'All',
        ),
      ),
    ));

    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Kerro Studio'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('⌘ K'), findsOneWidget);
    expect(find.text('K'), findsWidgets);

    final size = tester.getSize(find.byType(StudioTopChrome));
    expect(size.height, 56);
  });
}
