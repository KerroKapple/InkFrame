import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_nav.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

Widget _wrap(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: EpisodeViewNav())),
      ),
    );

void main() {
  testWidgets('渲染全部 5 个视图标签', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    for (final label in <String>['Canvas', 'Storyboard', 'Script', 'Generation', 'Queue']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('点击 Storyboard 标签切换 currentEpisodeViewProvider', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    expect(c.read(currentEpisodeViewProvider), EpisodeView.canvas);
    await tester.tap(find.byKey(EpisodeViewNav.tabKey(EpisodeView.storyboard)));
    await tester.pump();
    expect(c.read(currentEpisodeViewProvider), EpisodeView.storyboard);
  });
}
