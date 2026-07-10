// OnboardingDialog（ON-1）widget 测试：三步流转 / 跳过落标记 / 语言复用 /
// 第三步创建示例项目。fake PreferencesService + FakeSecureStorage，零磁盘。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/locale.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/studio/widgets/onboarding_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_secure_storage.dart';

/// 宿主：真实 Navigator 下经 showOnboardingDialog 打开向导。
Future<ProviderContainer> _pumpAndOpen(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOnboardingDialog(context),
            child: const Text('open-onboarding'),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open-onboarding'));
  await tester.pumpAndSettle();
  return container;
}

List<Override> _baseOverrides(InMemoryPreferencesService prefs) => <Override>[
      preferencesServiceProvider.overrideWithValue(prefs),
      secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
    ];

void main() {
  testWidgets('三步流转：语言 → API Keys → 起步；Start empty 落标记并关闭',
      (tester) async {
    final prefs = InMemoryPreferencesService();
    await _pumpAndOpen(tester, overrides: _baseOverrides(prefs));

    // 步骤 1：语言（复用 LanguageSection）
    expect(find.text('Welcome to InkFrame'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // 步骤 2：API Keys（复用 ApiKeysSection）
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('API Keys'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // 步骤 3：起步方式
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Create sample project'), findsOneWidget);

    await tester.tap(find.text('Start empty'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to InkFrame'), findsNothing);
    expect(prefs.current.onboardingCompleted, isTrue);
  });

  testWidgets('第一步 Skip：立即关闭且落 onboardingCompleted 标记', (tester) async {
    final prefs = InMemoryPreferencesService();
    await _pumpAndOpen(tester, overrides: _baseOverrides(prefs));

    expect(prefs.current.onboardingCompleted, isFalse);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to InkFrame'), findsNothing);
    expect(prefs.current.onboardingCompleted, isTrue);
  });

  testWidgets('语言步：点「中文」→ LocaleController 切 zh 并写偏好', (tester) async {
    final prefs = InMemoryPreferencesService();
    final container =
        await _pumpAndOpen(tester, overrides: _baseOverrides(prefs));

    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider)?.languageCode, 'zh');
    expect(prefs.current.localeCode, 'zh');
  });

  testWidgets('第三步「Create sample project」：建项目+画布、切画布、落标记、关向导',
      (tester) async {
    final prefs = InMemoryPreferencesService();
    final projects = InMemoryProjectRepository();
    final canvases = InMemoryCanvasRepository();
    final container = await _pumpAndOpen(tester, overrides: <Override>[
      ..._baseOverrides(prefs),
      projectRepositoryProvider.overrideWith((_) async => projects),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
    ]);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create sample project'));
    await tester.pumpAndSettle();

    expect(projects.rows.values.single['name'], 'Sample Project');
    expect(canvases.rows.values.single['name'], 'Canvas 1');
    expect(container.read(currentCanvasIdProvider), isNotNull);
    expect(prefs.current.onboardingCompleted, isTrue);
    expect(find.text('Welcome to InkFrame'), findsNothing);
  });
}
