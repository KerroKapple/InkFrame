import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/widgets/studio_provider_banner.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: Scaffold(body: child),
      );

  testWidgets('渲染 message + actionLabel 并在点击 action 时回调', (tester) async {
    var actionTaps = 0;
    await tester.pumpWidget(host(StudioProviderBanner(
      message: 'No provider configured.',
      actionLabel: 'Set up provider',
      onAction: () => actionTaps += 1,
    )));

    expect(find.text('No provider configured.'), findsOneWidget);
    expect(find.text('Set up provider'), findsOneWidget);

    await tester.tap(find.text('Set up provider'));
    await tester.pump();
    expect(actionTaps, 1);
  });

  testWidgets('提供 onDismiss 时点击关闭按钮回调', (tester) async {
    var dismissTaps = 0;
    await tester.pumpWidget(host(StudioProviderBanner(
      message: 'No provider configured.',
      actionLabel: 'Set up provider',
      onAction: () {},
      onDismiss: () => dismissTaps += 1,
    )));

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(dismissTaps, 1);
  });
}
