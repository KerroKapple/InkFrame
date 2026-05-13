import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/features/workspace/workspace_home_screen.dart'
    show workspaceProjectsProvider;
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('StudioHome renders Library + Recent Projects + New Project',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          workspaceProjectsProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: InkThemeVariant.dark,
            textScale: 1,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
  });
}
