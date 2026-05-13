// CanvasNodeCard 最小测试：渲染类型标签 + 标题 + ID/分辨率行。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_node_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('CanvasNodeCard shows type label + title + id + resolution',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: CanvasNodeCard(
          type: CanvasNodeType.character,
          title: 'Elara',
          id: 'chr_0042',
          resolution: '1024x576',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Elara'), findsOneWidget);
    expect(find.text('Character'), findsOneWidget);
    expect(find.text('chr_0042'), findsOneWidget);
    expect(find.text('1024x576'), findsOneWidget);
  });
}
