import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/lock/lock_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('LockScreen renders logo + unlock CTA', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LockScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('A DESK FOR STORYBOARDERS'), findsOneWidget);
  });
}
