import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/showcase/widgets/built_in_showcase_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('内置示例页展示方图、16:9 图和来源说明', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BuiltInShowcaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Built-in image samples'), findsOneWidget);
    expect(
      find.text(
        "Generated with Codex's built-in image tool and bundled for local preview. These are not project generation records.",
      ),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/showcase/ink-wash-mountains-square.jpg'),
      ),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/showcase/ink-wash-storyboard-wide.jpg'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('返回按钮切回 Studio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentScreenProvider.notifier).state = AppScreen.showcase;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BuiltInShowcaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
