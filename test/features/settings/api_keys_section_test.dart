// ApiKeysSection widget 测试 —— FakeSecureStorage + FakeProvider 覆盖
// save（valid / rejected / networkError）与 clear 往返。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/features/settings/widgets/api_keys_section.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_providers.dart';
import '../../_harness/test_app.dart';

class _FakeSecure implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<void> store(String k, String v) async => _data[k] = v;
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
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Clear'));
    expect(clearBtn.onPressed, isNull);
  });

  testWidgets('Save（验证通过）写入 SecureStorage 并切换到已配置', (tester) async {
    final secure = _FakeSecure();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), 'sk-abc');
    expect(find.text('Set'), findsOneWidget);
  });

  testWidgets('Save（验证拒绝）不落盘，保持未配置并提示', (tester) async {
    final secure = _FakeSecure();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async => const KeyValidationResult.invalid(
          reason: KeyInvalidReason.invalidKey,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-bad');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), isNull);
    expect(find.text('Not set'), findsOneWidget);
    expect(
      find.text('The provider rejected this key. It was not saved.'),
      findsOneWidget,
    );
    // 输入框保留原文，便于用户修改重试。
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'sk-bad',
    );
  });

  testWidgets('Save（网络不可判定）照常落盘并提示未验证', (tester) async {
    final secure = _FakeSecure();
    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(
        secure,
        onValidate: (_) async =>
            const KeyValidationResult.networkError(message: 'offline'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-maybe');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final storedKey = SecureStorageKeys.providerApiKey(_id);
    expect(await secure.retrieve(storedKey), 'sk-maybe');
    expect(find.text('Set'), findsOneWidget);
    expect(
      find.text(
        'Saved, but the key could not be verified due to a network issue.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Clear 删除 SecureStorage 并切回未配置', (tester) async {
    final secure = _FakeSecure();
    final storedKey = SecureStorageKeys.providerApiKey(_id);
    await secure.store(storedKey, 'sk-existing');

    await pumpInkApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ApiKeysSection())),
      overrides: _overrides(secure),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(await secure.retrieve(storedKey), isNull);
    expect(find.text('Not set'), findsOneWidget);
  });
}
