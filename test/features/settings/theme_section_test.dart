// ThemeSection widget test — 选中态切换 + textScale 滑块。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/theme.dart';
import 'package:inkframe/features/settings/widgets/theme_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('默认 dark，点击 Light 切换 variant', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(child: ThemeSection()),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(themeModeControllerProvider).variant,
        InkThemeVariant.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeControllerProvider).variant,
        InkThemeVariant.light);
  });

  testWidgets('点击 High contrast 切到 highContrast variant', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(child: ThemeSection()),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeControllerProvider).variant,
        InkThemeVariant.highContrast);
  });

  testWidgets('Section 渲染含 textScale 滑块', (tester) async {
    await tester.pumpWidget(_host(const ThemeSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
  });
}
