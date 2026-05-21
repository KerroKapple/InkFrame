// ToastService：通过 ScaffoldMessenger key 走 SnackBar。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('show 把 message 投到 ScaffoldMessenger', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = container.read(toastMessengerKeyProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          scaffoldMessengerKey: key,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    container.read(toastServiceProvider).show(
          'Generated',
          kind: ToastKind.success,
        );
    await tester.pump();

    expect(find.text('Generated'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('未接通 messenger key 时静默不抛', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 不接 key 到 MaterialApp.scaffoldMessengerKey。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ),
    );
    expect(
      () => container.read(toastServiceProvider).show('hi'),
      returnsNormally,
    );
  });
}
