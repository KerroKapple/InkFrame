
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/showcase/widgets/built_in_showcase_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

/// 穿透 ResizeImage 找到指定 asset 的 Image widget。
Finder _findAsset(String assetName) => find.byWidgetPredicate((w) {
      if (w is! Image) return false;
      final provider = w.image;
      final inner = provider is ResizeImage ? provider.imageProvider : provider;
      return inner is AssetImage && inner.assetName == assetName;
    });

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
        'AI-generated sample images bundled with the app for offline preview. '
        'They are not project generation records and need no API key.',
      ),
      findsOneWidget,
    );
    // cacheWidth 让 Image.asset 包一层 ResizeImage（ME-26 解码上限）——
    // 断言穿透到内层 AssetImage 的 assetName。
    expect(_findAsset('assets/showcase/ink-wash-mountains-square.jpg'),
        findsOneWidget);
    expect(_findAsset('assets/showcase/ink-wash-storyboard-wide.jpg'),
        findsOneWidget);
  });

  testWidgets('窄屏（<960）走单栏 Column 分支（评审 P3-2）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
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

    // 单栏判据：两卡标题的 y 明显错开（双栏时两者 y 相同）。
    final y1 = tester.getTopLeft(find.text('Mountain study')).dy;
    final y2 =
        tester.getTopLeft(find.text('Storyboard establishing shot')).dy;
    expect(y2 - y1, greaterThan(200), reason: '单栏应上下排布,非并排');
  });

  // 资产缺失的兜底：真触发 errorBuilder 需要绕开 Image.asset 的 bundle 解析链
  // （DefaultAssetBundle 覆盖不被采纳,实测真资产照常加载）——退一步钉住
  // 「每张图都挂了 errorBuilder」这个不变量,拦住有人顺手删掉兜底（评审 P3-2）。
  testWidgets('每张示例图都挂 errorBuilder 兜底', (tester) async {
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

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    for (final img in images) {
      expect(img.errorBuilder, isNotNull, reason: '资产缺失时必须有占位兜底');
      // cacheWidth 被吸收进 ResizeImage provider——按显示宽解码的证据（ME-26）。
      expect(img.image, isA<ResizeImage>(), reason: 'ME-26：按显示宽解码');
    }
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

