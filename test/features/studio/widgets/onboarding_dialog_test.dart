// OnboardingDialog（ON-1，Screens 稿第 4 屏左）widget 测试。
//
// 钉行为而非存在性：步骤条的「只有当前步填琥珀」「已到过的步才可点」、
// Provider 行的「无适配器那行点不动」、Key 验证三态（落盘 / 不落盘 + 错误码原串 /
// 离线照常落盘），以及两个出口都必须落 onboardingCompleted。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/asset_bundle.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/core/di/locale.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/settings/providers/settings_page.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/util/onboarding_provider_choices.dart';
import 'package:inkframe/features/studio/widgets/onboarding_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_asset_bundle.dart';
import '../../../_harness/fake_providers.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_secure_storage.dart';
import '../../../_harness/fake_unit_of_work.dart';

/// 按仓库真实注册顺序做的最小注册表：Gemini + DashScope 家族两员；fal.ai 缺席。
const String _geminiId = 'gemini-image';
const String _dashscopeMemberId = 'wanx-image';
const String _dashscopeOtherId = 'kling-v3';

final String _geminiStorageKey = SecureStorageKeys.providerApiKey(_geminiId);
final String _dashscopeStorageKey =
    SecureStorageKeys.providerApiKey(_dashscopeMemberId);

List<ProviderCapabilities> _caps() => <ProviderCapabilities>[
      fakeImageCapabilities(id: _geminiId),
      fakeImageCapabilities(id: _dashscopeMemberId, region: ProviderRegion.cn),
      fakeVideoCapabilities(id: _dashscopeOtherId, region: ProviderRegion.cn),
    ];

List<Override> _overrides({
  required InMemoryPreferencesService prefs,
  required FakeSecureStorage secure,
  Future<KeyValidationResult> Function(String)? onValidate,
  List<Override> extra = const <Override>[],
}) {
  final List<ProviderCapabilities> caps = _caps();
  return <Override>[
    preferencesServiceProvider.overrideWithValue(prefs),
    secureStorageServiceProvider.overrideWithValue(secure),
    providerCapabilitiesListProvider.overrideWithValue(caps),
    providerRegistryProvider.overrideWithValue(
      CachingProviderRegistry(<String, ProviderFactory>{
        for (final ProviderCapabilities c in caps)
          c.providerId: () =>
              FakeProvider(capabilities: c, onValidate: onValidate),
      }),
    ),
    ...extra,
  ];
}

/// 宿主：真实 Navigator 下经 showOnboardingDialog 打开向导。
Future<ProviderContainer> _pumpAndOpen(
  WidgetTester tester, {
  required List<Override> overrides,
  Size surfaceSize = const Size(1440, 900),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: textScale),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
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

/// 到第 2 步（配置密钥）。
Future<void> _gotoKeysStep(WidgetTester tester) async {
  await tester.tap(find.byKey(OnboardingDialog.nextKey));
  await tester.pumpAndSettle();
}

/// 输入 Key 并走一帧——空输入时「验证」是真禁用（不捕获点击），
/// 和真人一样要等这一帧过去按钮才活。
Future<void> _typeKey(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Widget? _underlineFill(WidgetTester tester, int step) =>
    tester.widget<SizedBox>(find.byKey(OnboardingDialog.stepUnderlineKey(step)))
        .child;

Color _stepUnderlineColor(WidgetTester tester, int step) =>
    tester
        .widget<ColoredBox>(find.descendant(
          of: find.byKey(OnboardingDialog.stepUnderlineKey(step)),
          matching: find.byType(ColoredBox),
        ))
        .color;

Color _keyUnderlineColor(WidgetTester tester) {
  final Container box =
      tester.widget<Container>(find.byKey(OnboardingDialog.keyUnderlineKey));
  final BoxDecoration deco = box.decoration! as BoxDecoration;
  return (deco.border! as Border).bottom.color;
}

/// 「选中了哪一行」只看单选圈里有没有那个 6×6 实心点。
bool _radioChecked(WidgetTester tester, OnboardingProviderSlot slot) =>
    tester
        .widget<Container>(find.byKey(OnboardingDialog.providerRadioKey(slot)))
        .child !=
    null;

String _inputText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  final InkColors colors = InkColors.dark();

  group('步骤条', () {
    testWidgets('只有当前步填琥珀；其余步 2px 槽位恒留但不画', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
      );

      expect(_underlineFill(tester, 0), isNotNull);
      expect(_stepUnderlineColor(tester, 0), colors.accent);
      // 槽位必须在（否则整条页签矮 2px、文字跟着上移），但不填色。
      expect(_underlineFill(tester, 1), isNull);
      expect(_underlineFill(tester, 2), isNull);

      await _gotoKeysStep(tester);

      expect(_underlineFill(tester, 0), isNull);
      expect(_underlineFill(tester, 1), isNotNull);
      expect(_stepUnderlineColor(tester, 1), colors.accent);
    });

    testWidgets('可回退：第 3 步点第 1 格回到第 1 步', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
      );

      await _gotoKeysStep(tester);
      await tester.tap(find.byKey(OnboardingDialog.nextKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OnboardingDialog.createSampleKey), findsOneWidget);

      await tester.tap(find.byKey(OnboardingDialog.stepTabKey(0)));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to InkFrame'), findsOneWidget);
      expect(find.byKey(OnboardingDialog.createSampleKey), findsNothing);
      expect(_underlineFill(tester, 0), isNotNull);
    });

    testWidgets('不可前跳：没到过的步点不动', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
      );

      await tester.tap(find.byKey(OnboardingDialog.stepTabKey(2)));
      await tester.pumpAndSettle();

      // 仍在第 1 步：标题在场、第 3 步的主动作不在场。
      expect(find.text('Welcome to InkFrame'), findsOneWidget);
      expect(find.byKey(OnboardingDialog.createSampleKey), findsNothing);
      expect(_underlineFill(tester, 0), isNotNull);
    });

    testWidgets('回退之后能再点回到过的步', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
      );

      await _gotoKeysStep(tester);
      await tester.tap(find.byKey(OnboardingDialog.stepTabKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingDialog.stepTabKey(1)));
      await tester.pumpAndSettle();

      expect(find.byKey(OnboardingDialog.verifyKey), findsOneWidget);
    });
  });

  group('第 2 步 Provider 单选', () {
    testWidgets('fal.ai 无适配器：带「待支持」后缀，点它不改选中态',
        (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
        ),
      );
      await _gotoKeysStep(tester);

      expect(find.text('fal.ai (coming soon)'), findsOneWidget);
      expect(_radioChecked(tester, OnboardingProviderSlot.gemini), isTrue);

      await tester.tap(find.byKey(
          OnboardingDialog.providerRowKey(OnboardingProviderSlot.fal)));
      await tester.pumpAndSettle();

      // 选中态没动：Gemini 仍是选中行，fal.ai 的圈仍是空的。
      expect(_radioChecked(tester, OnboardingProviderSlot.gemini), isTrue);
      expect(_radioChecked(tester, OnboardingProviderSlot.fal), isFalse);

      // 并且 Key 仍写给 Gemini 的 scope。
      await _typeKey(tester, 'sk-gemini');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();
      expect(secure.snapshot[_geminiStorageKey], 'sk-gemini');
    });

    testWidgets('选 DashScope 后验证：Key 落家族 scope，不落成员 id',
        (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
        ),
      );
      await _gotoKeysStep(tester);

      await tester.tap(find.byKey(
          OnboardingDialog.providerRowKey(OnboardingProviderSlot.dashscope)));
      await tester.pumpAndSettle();
      await _typeKey(tester, 'sk-dashscope');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();

      expect(_dashscopeStorageKey, 'provider.dashscope.api_key');
      expect(secure.snapshot[_dashscopeStorageKey], 'sk-dashscope');
      expect(secure.snapshot.containsKey('provider.wanx-image.api_key'),
          isFalse);
      expect(secure.snapshot.containsKey(_geminiStorageKey), isFalse);
    });

    testWidgets('换 Provider 清空已输入的 Key——不把一家的 Key 存给另一家',
        (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-for-gemini');
      await tester.tap(find.byKey(
          OnboardingDialog.providerRowKey(OnboardingProviderSlot.dashscope)));
      await tester.pumpAndSettle();

      expect(_inputText(tester), isEmpty);

      // 空输入点验证 ⇒ 什么都不写。
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();
      expect(secure.snapshot, isEmpty);
    });

    testWidgets('点已选中的那一行不清输入（默认行也算已选中）',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-half-typed');
      await tester.tap(find.byKey(
          OnboardingDialog.providerRowKey(OnboardingProviderSlot.gemini)));
      await tester.pumpAndSettle();

      expect(_inputText(tester), 'sk-half-typed');
    });
  });

  group('第 2 步 Key 验证三态', () {
    testWidgets('验证通过：落盘并显示成功行', (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-good');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();

      expect(secure.snapshot[_geminiStorageKey], 'sk-good');
      expect(
        find.text('Verified · written to the system keychain'),
        findsOneWidget,
      );
      expect(_keyUnderlineColor(tester), colors.control);
    });

    testWidgets('验证被拒：不落盘、底线转 danger、下方一行是错误码原串',
        (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
          onValidate: (_) async => const KeyValidationResult.invalid(
            reason: KeyInvalidReason.invalidKey,
          ),
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-bad');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();

      expect(secure.snapshot, isEmpty);
      expect(_keyUnderlineColor(tester), colors.danger);
      expect(find.text('invalid_key'), findsOneWidget);
      // 输入保留，便于改错重试。
      expect(_inputText(tester), 'sk-bad');
    });

    testWidgets('失败后改动输入：底线回 control、错误行消失', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
          onValidate: (_) async => const KeyValidationResult.invalid(
            reason: KeyInvalidReason.invalidKey,
          ),
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-bad');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();
      expect(find.text('invalid_key'), findsOneWidget);

      await _typeKey(tester, 'sk-bad2');
      await tester.pumpAndSettle();

      expect(find.text('invalid_key'), findsNothing);
      expect(_keyUnderlineColor(tester), colors.control);
    });

    testWidgets('网络不可判定：照常落盘并提示未验证', (WidgetTester tester) async {
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: secure,
          onValidate: (_) async =>
              const KeyValidationResult.networkError(message: 'offline'),
        ),
      );
      await _gotoKeysStep(tester);

      await _typeKey(tester, 'sk-maybe');
      await tester.tap(find.byKey(OnboardingDialog.verifyKey));
      await tester.pumpAndSettle();

      expect(secure.snapshot[_geminiStorageKey], 'sk-maybe');
      expect(
        find.text(
          "Saved. The key couldn't be verified right now "
          '(network or service issue) — it will be checked on first use.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('已配置的 scope 重进第 2 步：成功行显示已配置', (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(<String, String>{
            'provider.gemini-image.api_key': 'sk-existing',
          }),
        ),
      );
      await _gotoKeysStep(tester);

      expect(find.text('Set'), findsOneWidget);
    });
  });

  group('出口', () {
    testWidgets('跳过：落 onboardingCompleted、关闭、不写任何 Key',
        (WidgetTester tester) async {
      final InMemoryPreferencesService prefs = InMemoryPreferencesService();
      final FakeSecureStorage secure = FakeSecureStorage();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(prefs: prefs, secure: secure),
      );
      expect(prefs.current.onboardingCompleted, isFalse);

      await tester.tap(find.byKey(OnboardingDialog.skipKey));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to InkFrame'), findsNothing);
      expect(prefs.current.onboardingCompleted, isTrue);
      expect(secure.snapshot, isEmpty);
    });

    // P7：底部那句「之后可在设置里调整」现在点得动。向导是 modal 路由、设置浮层
    // 在它【之下】，所以这条跳转必须先走正常出口（落 onboardingCompleted）再开浮层
    // ——否则浮层开在看不见的层里，而且标记被旁路、下次冷启又弹向导。
    testWidgets('底部「打开设置 › 性能」：落标记、关向导、浮层开在性能页',
        (WidgetTester tester) async {
      final InMemoryPreferencesService prefs = InMemoryPreferencesService();
      final ProviderContainer container = await _pumpAndOpen(
        tester,
        overrides: _overrides(prefs: prefs, secure: FakeSecureStorage()),
      );
      expect(container.read(shellControllerProvider).overlay, isNull);

      await tester.tap(find.byKey(OnboardingDialog.settingsLinkKey));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to InkFrame'), findsNothing, reason: '向导已关');
      expect(prefs.current.onboardingCompleted, isTrue);
      expect(
        container.read(shellControllerProvider).overlay,
        ShellOverlay.settings,
      );
      expect(container.read(settingsPageProvider), SettingsPage.performance);
    });

    testWidgets('第 3 步「从空白开始」：落标记并关闭', (WidgetTester tester) async {
      final InMemoryPreferencesService prefs = InMemoryPreferencesService();
      await _pumpAndOpen(
        tester,
        overrides: _overrides(prefs: prefs, secure: FakeSecureStorage()),
      );

      await _gotoKeysStep(tester);
      await tester.tap(find.byKey(OnboardingDialog.nextKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingDialog.startEmptyKey));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to InkFrame'), findsNothing);
      expect(prefs.current.onboardingCompleted, isTrue);
    });

    testWidgets('第 3 步「创建示例项目」：建项目 + 画布、切画布、落标记、关闭',
        (WidgetTester tester) async {
      final InMemoryPreferencesService prefs = InMemoryPreferencesService();
      final InMemoryProjectRepository projects = InMemoryProjectRepository();
      final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
      final InMemoryStyleLaneRepository lanes = InMemoryStyleLaneRepository();
      final InMemoryNodeRepository nodes = InMemoryNodeRepository();
      final ProviderContainer container = await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: prefs,
          secure: FakeSecureStorage(),
          extra: <Override>[
            // 示例项目要往数据根写打包成片：钉临时根 + 空 bundle（成片本身由
            // canvas_bootstrap_controller_test 覆盖，这里只看向导出口那条链）。
            appPathsProvider.overrideWithValue(
              DefaultAppPaths.forRoot(
                Directory.systemTemp.createTempSync('ink_onboarding_sample_'),
              ),
            ),
            assetBundleProvider.overrideWithValue(
              FakeAssetBundle(const <String, List<int>>{}),
            ),
            unitOfWorkProvider.overrideWith(
              (_) async => FakeUnitOfWork(FakeRepositoryScope(
                projects: projects,
                canvas: canvases,
                styleLanes: lanes,
                nodes: nodes,
              )),
            ),
          ],
        ),
      );

      await _gotoKeysStep(tester);
      await tester.tap(find.byKey(OnboardingDialog.nextKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingDialog.createSampleKey));
      await tester.pumpAndSettle();

      expect(projects.rows.values.single['name'], 'Sample Project');
      expect(canvases.rows.values.single['name'], 'Canvas 1');
      expect(container.read(currentCanvasIdProvider), isNotNull);
      expect(prefs.current.onboardingCompleted, isTrue);
      expect(find.text('Welcome to InkFrame'), findsNothing);
      // ON-2b：演示内容一并种入。
      expect(lanes.rows, hasLength(1));
      expect(nodes.rows.values.single['lane_id'], lanes.rows.keys.single);
    });

    testWidgets('卡片高固定：中文 + 1.3 字号档 + 小窗仍不溢出（正文自己滚）',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        overrides: _overrides(
          prefs: InMemoryPreferencesService(),
          secure: FakeSecureStorage(),
        ),
        // 比卡片本身（642×492）还小的窗口 + 放大字号：两个方向都压一遍。
        surfaceSize: const Size(620, 460),
        locale: const Locale('zh'),
        textScale: 1.3,
      );

      await _gotoKeysStep(tester);
      // 到这里没有抛 RenderFlex overflow / 任何 FlutterError 即为通过；
      // 再确认内容真的还在（没被整段裁掉）。
      expect(find.byKey(OnboardingDialog.verifyKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('语言步：点「中文」→ LocaleController 切 zh 并写偏好',
        (WidgetTester tester) async {
      final InMemoryPreferencesService prefs = InMemoryPreferencesService();
      final ProviderContainer container = await _pumpAndOpen(
        tester,
        overrides: _overrides(prefs: prefs, secure: FakeSecureStorage()),
      );

      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();

      expect(container.read(localeControllerProvider)?.languageCode, 'zh');
      expect(prefs.current.localeCode, 'zh');
    });
  });
}
