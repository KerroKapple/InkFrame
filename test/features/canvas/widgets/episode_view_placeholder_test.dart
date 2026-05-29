import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_placeholder.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('占位屏显示视图标签', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EpisodeViewPlaceholder(view: EpisodeView.storyboard),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Storyboard'), findsOneWidget);
  });
}
