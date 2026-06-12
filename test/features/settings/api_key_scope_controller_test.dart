// ApiKeyScopeController 单测 —— 设置页 key scope 状态机（family by providerId）。
//
// 覆盖：build 反映存量、save 验证→落盘三分支（valid / invalid / networkError）、
// clear、存储层 LocalIOError 透传、DashScope 家族 scope 折叠。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/features/settings/providers/api_key_scope_controller.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_providers.dart';

class _MemorySecure implements SecureStorageService {
  final Map<String, String> box = {};
  bool throwOnStore = false;

  @override
  Future<void> store(String key, String value) async {
    if (throwOnStore) {
      throw const LocalIOError(extra: {'op': 'store'});
    }
    box[key] = value;
  }

  @override
  Future<String?> retrieve(String key) async => box[key];

  @override
  Future<void> delete(String key) async {
    box.remove(key);
  }

  @override
  Future<bool> exists(String key) async => box.containsKey(key);
}

void main() {
  const id = 'test-provider';
  final storageKey = SecureStorageKeys.providerApiKey(id);

  late _MemorySecure secure;
  late FakeProvider fake;
  late ProviderContainer container;

  ProviderContainer build({
    Future<KeyValidationResult> Function(String)? onValidate,
    String providerId = id,
  }) {
    fake = FakeProvider(
      capabilities: fakeImageCapabilities(id: providerId),
      onValidate: onValidate,
    );
    return ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(secure),
      providerRegistryProvider.overrideWithValue(
        ProviderRegistry({providerId: () => fake}),
      ),
    ]);
  }

  setUp(() {
    secure = _MemorySecure();
  });

  tearDown(() => container.dispose());

  test('build：存量存在 → state true；不存在 → false', () async {
    secure.box[storageKey] = 'sk-existing';
    container = build();
    expect(
      await container.read(apiKeyScopeControllerProvider(id).future),
      isTrue,
    );

    secure.box.clear();
    container.invalidate(apiKeyScopeControllerProvider(id));
    expect(
      await container.read(apiKeyScopeControllerProvider(id).future),
      isFalse,
    );
  });

  test('save valid → 验证后落盘，state=true，outcome=saved', () async {
    container = build();
    await container.read(apiKeyScopeControllerProvider(id).future);

    final outcome = await container
        .read(apiKeyScopeControllerProvider(id).notifier)
        .save('sk-good');

    expect(outcome, ApiKeySaveOutcome.saved);
    expect(secure.box[storageKey], 'sk-good');
    expect(fake.validatedKeys, ['sk-good']);
    expect(
      container.read(apiKeyScopeControllerProvider(id)).value,
      isTrue,
    );
  });

  test('save invalid → 不落盘，state 保持 false，outcome=rejected', () async {
    container = build(
      onValidate: (_) async => const KeyValidationResult.invalid(
        reason: KeyInvalidReason.invalidKey,
      ),
    );
    await container.read(apiKeyScopeControllerProvider(id).future);

    final outcome = await container
        .read(apiKeyScopeControllerProvider(id).notifier)
        .save('sk-bad');

    expect(outcome, ApiKeySaveOutcome.rejected);
    expect(secure.box, isEmpty);
    expect(
      container.read(apiKeyScopeControllerProvider(id)).value,
      isFalse,
    );
  });

  test('save networkError → 照常落盘，outcome=savedUnverified', () async {
    container = build(
      onValidate: (_) async =>
          const KeyValidationResult.networkError(message: 'offline'),
    );
    await container.read(apiKeyScopeControllerProvider(id).future);

    final outcome = await container
        .read(apiKeyScopeControllerProvider(id).notifier)
        .save('sk-maybe');

    expect(outcome, ApiKeySaveOutcome.savedUnverified);
    expect(secure.box[storageKey], 'sk-maybe');
    expect(
      container.read(apiKeyScopeControllerProvider(id)).value,
      isTrue,
    );
  });

  test('validateApiKey 抛 InkError → 视作不可判定，照常落盘', () async {
    container = build(
      onValidate: (_) async =>
          throw const NetworkError(code: InkErrorCode.networkTimeout),
    );
    await container.read(apiKeyScopeControllerProvider(id).future);

    final outcome = await container
        .read(apiKeyScopeControllerProvider(id).notifier)
        .save('sk-x');

    expect(outcome, ApiKeySaveOutcome.savedUnverified);
    expect(secure.box[storageKey], 'sk-x');
  });

  test('store 抛 LocalIOError → save 透传，state 不变', () async {
    container = build();
    await container.read(apiKeyScopeControllerProvider(id).future);
    secure.throwOnStore = true;

    await expectLater(
      container.read(apiKeyScopeControllerProvider(id).notifier).save('sk-x'),
      throwsA(isA<LocalIOError>()),
    );
    expect(
      container.read(apiKeyScopeControllerProvider(id)).value,
      isFalse,
    );
  });

  test('clear → 删除存量，state=false', () async {
    secure.box[storageKey] = 'sk-existing';
    container = build();
    await container.read(apiKeyScopeControllerProvider(id).future);

    await container.read(apiKeyScopeControllerProvider(id).notifier).clear();

    expect(secure.box, isEmpty);
    expect(
      container.read(apiKeyScopeControllerProvider(id)).value,
      isFalse,
    );
  });

  test('DashScope 家族成员 → storage key 折叠到家族 scope', () async {
    container = build(providerId: 'kling-v3');
    await container.read(apiKeyScopeControllerProvider('kling-v3').future);

    await container
        .read(apiKeyScopeControllerProvider('kling-v3').notifier)
        .save('sk-ds');

    expect(secure.box.keys, ['provider.dashscope.api_key']);
  });
}
