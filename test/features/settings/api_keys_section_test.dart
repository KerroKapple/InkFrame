// ApiKeysSection widget 测试 —— FakeSecureStorage + FakeProvider 覆盖
// save（valid / rejected / networkError / 存储层 InkError）与 clear 往返。
//
// 结局提示走通知卡：覆盖 toastServiceProvider 为 RecordingToastService，断言
// titles / kinds。pumpInkApp 里没有 ToastLayer，卡片文字本来就不在树上，
// 所以这里不用 find.text 找提示。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/settings/widgets/api_keys_section.dart';
import 'package:inkframe/theme/components/ink_button.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_providers.dart';
import '../../_harness/fake_toast_service.dart';
import '../../_harness/test_app.dart';

class _FakeSecure implements SecureStorageService {
  final Map<String, String> _data = {};

  /// 非 null 时 store 抛它：模拟存储层 InkError 原样透传到 UI。
  InkError? storeError;

  @override
  Future<void> store(String k, String v) async {
    final InkError? e = storeError;
    if (e != null) throw e;
    _data[k] = v;
  }

  @override
  Future<String?> retrieve(String k) async => _data[k];
  @override
  Future<void> delete(String k) async => _data.remove(k);
  @override
  Future<bool> exists(String k) async => _data.containsKey(k);
}

const _id = 'test-provider';

List<Override> _overrides(
  SecureStorageService secure, {
  Future<KeyValidationResult> Function(String)? onValidate,
  RecordingToastService? toast,
}) {
  final fake = FakeProvider(
    capabilities: fakeImageCapabilities(id: _id),
    onValidate: onValidate,
  );
  return [
    providerRegistryProvider
        .overrideWithValue(CachingProviderRegistry({_id: () => fake})),
    // 下拉数据源已与 registry 解耦（直接读 const）；测试显式覆盖展示列表。
    providerCapabilitiesListProvider
        .overrideWithValue([fakeImageCapabilities(id: _id)]),
    secureStorageServiceProvider.overrideWithValue(secure),
    toastServiceProvider.overrideWithValue(toast ?? RecordingToastService()),
  ];
}

void main() {
  testWidgets('初始态未配置，Clear 按钮 disabled', (tester) async {
    final secure = _FakeSecure();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure),
    );
    await tester.pumpAndSettle();

    expect(find.text(_id), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    // Clear 按钮 disabled
    final clearBtn = tester
        .widget<InkButton>(find.widgetWithText(InkButton, 'Clear'));
    expect(clearBtn.onPressed, isNull);
  });

  testWidgets('Save（验证通过）写入 SecureStorage 并切换到已配置 + 完成卡',
      (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure, toast: toast),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-abc');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), 'sk-abc');
    expect(find.text('Set'), findsOneWidget);
    expect(toast.titles, <String>['Saved']);
    expect(toast.kinds, <ToastKind>[ToastKind.success]);
    expect(toast.shown.single.chime, isFalse,
        reason: '用户自己刚点的保存，不是后台事件到达');
  });

  testWidgets('Save（验证拒绝 invalidKey）不落盘，保持未配置并提示「无效」', (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async => const KeyValidationResult.invalid(
          reason: KeyInvalidReason.invalidKey,
        ),
        toast: toast,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-bad');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), isNull);
    expect(find.text('Not set'), findsOneWidget);
    expect(
      toast.titles,
      <String>['The provider rejected this key as invalid. It was not saved.'],
    );
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    // 输入框保留原文，便于用户修改重试。
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'sk-bad',
    );
  });

  // 本卡的回归点：余额不足的 toast 不能再说「Key 无效」——那会让用户白白换 Key。
  testWidgets('Save（验证拒绝 insufficientBalance）提示余额不足，不提无效 Key',
      (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async => const KeyValidationResult.invalid(
          reason: KeyInvalidReason.insufficientBalance,
        ),
        toast: toast,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-broke');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(SecureStorageKeys.providerApiKey(_id)), isNull);
    // 整张列表比对：只有余额不足这一句，没有「Key 无效」。
    expect(
      toast.titles,
      <String>[
        'The key is accepted but the account balance is insufficient. '
            'It was not saved — top up the account; replacing the key will not help.',
      ],
    );
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });

  testWidgets('Save（验证拒绝 contentPolicy）提示内容策略', (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async => const KeyValidationResult.invalid(
          reason: KeyInvalidReason.contentPolicy,
        ),
        toast: toast,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-policy');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(SecureStorageKeys.providerApiKey(_id)), isNull);
    expect(
      toast.titles,
      <String>[
        'The provider blocked the check on content-policy grounds. '
            'The key was not saved.',
      ],
    );
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });

  testWidgets('Save（网络不可判定）照常落盘并提示未验证（警告卡）', (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async =>
            const KeyValidationResult.networkError(message: 'offline'),
        toast: toast,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-maybe');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), 'sk-maybe');
    expect(find.text('Set'), findsOneWidget);
    expect(
      toast.titles,
      <String>[
        "Saved. The key couldn't be verified right now (network or service issue) — it will be checked on first use.",
      ],
    );
    // 存上了但没验过：提醒，不算完成。
    expect(toast.kinds, <ToastKind>[ToastKind.warning]);
  });

  testWidgets('Save（存储层抛 InkError）→ 失败卡，不落盘、输入框保留', (tester) async {
    final secure = _FakeSecure()..storeError = const LocalIOError();
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure, toast: toast),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-disk');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(SecureStorageKeys.providerApiKey(_id)), isNull);
    expect(find.text('Not set'), findsOneWidget);
    expect(
      toast.titles,
      <String>['Local disk I/O error. Check space and permissions.'],
    );
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'sk-disk',
    );
  });

  // 失败卡不自动消失。同一行的卡共用一个去重键，改好再存时「已保存」原地换掉那张
  // 失败卡，而不是在旁边再叠一张、留着一句已经不成立的「Key 无效」。
  testWidgets('同一行的卡共用去重键：被拒之后改好再存，两张卡同一个 key',
      (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    KeyValidationResult verdict = const KeyValidationResult.invalid(
      reason: KeyInvalidReason.invalidKey,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async => verdict,
        toast: toast,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-bad');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    verdict = const KeyValidationResult.valid();
    await tester.enterText(find.byType(TextField), 'sk-good');
    await tester.tap(find.widgetWithText(InkButton, 'Save'));
    await tester.pumpAndSettle();

    expect(toast.kinds, <ToastKind>[ToastKind.error, ToastKind.success]);
    final Set<String?> keys = <String?>{
      for (final RecordedToast t in toast.shown) t.dedupeKey,
    };
    expect(keys, hasLength(1), reason: '两张卡的去重键不同 ⇒ 失败卡会留在原地');
    expect(keys.single, isNotNull);
  });

  testWidgets('Clear 删除 SecureStorage 并切回未配置 + 提示卡', (tester) async {
    final secure = _FakeSecure();
    final toast = RecordingToastService();
    final storedKey = SecureStorageKeys.providerApiKey(_id);
    await secure.store(storedKey, 'sk-existing');

    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure, toast: toast),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(storedKey), isNull);
    expect(find.text('Not set'), findsOneWidget);
    expect(toast.titles, <String>['Cleared']);
    expect(toast.kinds, <ToastKind>[ToastKind.info]);
  });

  // 演示里发现：占位提示一律 `sk-...`，Gemini 那行也是——而 Gemini 的 Key 是
  // `AIza` 开头。占位要随家族走，自定义端点不猜前缀。
  testWidgets('Key 输入框的占位提示随家族走：Gemini AIza…、DashScope sk-…、自定义不猜',
      (tester) async {
    const geminiId = 'gemini-image';
    const dashscopeId = 'wanx-image';
    const customId = 'custom:my-relay';
    final caps = [
      fakeImageCapabilities(id: geminiId),
      fakeImageCapabilities(id: dashscopeId),
      fakeImageCapabilities(id: customId).copyWith(displayName: 'My Relay'),
    ];
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: [
        providerRegistryProvider.overrideWithValue(
          CachingProviderRegistry({
            for (final c in caps) c.providerId: () => FakeProvider(capabilities: c),
          }),
        ),
        providerCapabilitiesListProvider.overrideWithValue(caps),
        secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
      ],
    );
    await tester.pumpAndSettle();

    // 行序 = 注册顺序（按 scope 折叠后的 LinkedHashMap）。
    final hints = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.decoration?.hintText)
        .toList();
    expect(hints, <String?>['AIza...', 'sk-...', 'Paste your API key']);
  });

  testWidgets('custom:* 行显示 displayName 而非裸 id（GAP-1 顺带修）', (tester) async {
    const customId = 'custom:my-relay';
    final caps = fakeImageCapabilities(id: customId)
        .copyWith(displayName: 'My Relay');
    final fake = FakeProvider(capabilities: caps);
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: [
        providerRegistryProvider.overrideWithValue(
          CachingProviderRegistry({customId: () => fake}),
        ),
        providerCapabilitiesListProvider.overrideWithValue([caps]),
        secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('My Relay'), findsOneWidget);
    // 裸 id 只允许出现在成员副标题（多成员/名不同时显示）,不做主标签
    expect(find.text(customId), findsOneWidget); // 副标题行
  });
}
