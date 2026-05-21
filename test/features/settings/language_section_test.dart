// LanguageSection widget test — 切换 locale 反映到 controller。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/locale.dart';
import 'package:inkframe/features/settings/widgets/language_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('点击中文 → controller.state 切换到 zh', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: ref.watch(localeControllerProvider),
              home: const Scaffold(
                body: SingleChildScrollView(child: LanguageSection()),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), isNull);

    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider)?.languageCode, 'zh');
    // 切到 zh 后标题文案变中文
    expect(find.text('语言'), findsOneWidget);
  });

  testWidgets('点击 English → controller.state 切回 en', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [],
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: ref.watch(localeControllerProvider),
              home: const Scaffold(
                body: SingleChildScrollView(child: LanguageSection()),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(localeControllerProvider.notifier)
        .setLocale(const Locale('zh'));
    await tester.pumpAndSettle();
    expect(find.text('中文'), findsWidgets);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider)?.languageCode, 'en');
  });
}
