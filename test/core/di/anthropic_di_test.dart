// Claude DI：Key 现取自 SecureStorage、Claude 不进生成注册表、校验方按 scope 分派。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/anthropic.dart';
import 'package:inkframe/core/di/key_validation.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/anthropic_client.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_providers.dart';
import '../../_harness/fake_secure_storage.dart';

void main() {
  test('没配 Claude Key ⇒ createMessage 抛 invalidKey（不发请求）', () async {
    final ProviderContainer c = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
    ]);
    addTearDown(c.dispose);
    await expectLater(
      c.read(anthropicClientProvider).createMessage(
            ClaudeRequest(messages: <ClaudeMessageParam>[ClaudeMessageParam.userText('hi')]),
          ),
      throwsA(isA<ProviderError>()
          .having((e) => e.code, 'code', InkErrorCode.invalidKey)
          .having((e) => e.extra['reason'], 'reason', 'key_not_configured')),
    );
  });

  test('apiKeyValidatorProvider：anthropic → AnthropicClient；其它 → 注册表 Provider', () {
    final FakeProvider fake = FakeProvider(capabilities: fakeImageCapabilities(id: 'p'));
    final ProviderContainer c = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
      providerRegistryProvider.overrideWithValue(CachingProviderRegistry({'p': () => fake})),
    ]);
    addTearDown(c.dispose);
    expect(
      c.read(apiKeyValidatorProvider(SecureStorageKeys.anthropicScope)),
      isA<AnthropicClient>(),
    );
    expect(c.read(apiKeyValidatorProvider('p')), same(fake));
  });

  test('只有 Claude Key ⇒ anyProviderKeyConfigured 仍为 false（Studio 横幅 / 引导不认它）', () async {
    final ProviderContainer c = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(
        FakeSecureStorage(<String, String>{SecureStorageKeys.anthropicApiKey: 'sk-ant-x'}),
      ),
    ]);
    addTearDown(c.dispose);
    expect(await c.read(anyProviderKeyConfiguredProvider.future), isFalse);
    expect(
      c.read(providerRegistryProvider).ids.map(SecureStorageKeys.scopeOf),
      isNot(contains(SecureStorageKeys.anthropicScope)),
    );
  });
}
