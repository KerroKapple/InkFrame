import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('shows label and fires onEdit', (tester) async {
    var edited = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'a', canvasId: 'c', label: 'Day'),
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('Day'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    expect(edited, isTrue);
  });

  testWidgets('shows laneUntitled when label is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'b', canvasId: 'c', label: ''),
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));
    // en locale fallback: "Untitled lane"
    expect(find.text('Untitled lane'), findsOneWidget);
  });

  testWidgets('delete button fires onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'c', canvasId: 'c', label: 'Night'),
          onEdit: () {},
          onDelete: () => deleted = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    expect(deleted, isTrue);
  });
}
