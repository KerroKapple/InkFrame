import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_placeholder.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('非 Canvas 视图渲染占位屏而非 CanvasView', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentEpisodeViewProvider.notifier).state =
        EpisodeView.storyboard;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CanvasScreen(canvasName: 'Ep 02'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EpisodeViewPlaceholder), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });
}
