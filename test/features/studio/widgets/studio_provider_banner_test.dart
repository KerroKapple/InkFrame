import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/studio/widgets/studio_provider_banner.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StudioProviderBanner()),
    ),
  );
}

void main() {
  testWidgets('未配置 key → 显示 banner', (tester) async {
    final container = ProviderContainer(overrides: <Override>[
      anyProviderKeyConfiguredProvider.overrideWith((_) async => false),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pump();
    expect(find.textContaining('provider API key'), findsOneWidget);
    expect(find.text('Configure in Settings'), findsOneWidget);
  });

  testWidgets('已配置 key → 不显示 banner', (tester) async {
    final container = ProviderContainer(overrides: <Override>[
      anyProviderKeyConfiguredProvider.overrideWith((_) async => true),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pump();
    expect(find.text('Configure in Settings'), findsNothing);
  });

  testWidgets('点 action → currentScreen 切到 settings', (tester) async {
    final container = ProviderContainer(overrides: <Override>[
      anyProviderKeyConfiguredProvider.overrideWith((_) async => false),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pump();
    expect(container.read(currentScreenProvider), AppScreen.studio);
    await tester.tap(find.text('Configure in Settings'));
    await tester.pump();
    expect(container.read(currentScreenProvider), AppScreen.settings);
  });
}
