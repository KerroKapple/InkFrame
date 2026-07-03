// 自定义 Provider 启动期注册（PROVIDER-API §13.5）：
// registry 合并 custom factory、每 providerId 独享 RateLimiter、
// capabilities 合并源同步可读、displayNames 透传。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/custom_provider_source.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';
import 'package:inkframe/providers/openai_compatible_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';
import 'package:inkframe/providers/sync_provider_base.dart';

class _NoopSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async {}
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

class _FakeSource implements CustomProviderSource {
  const _FakeSource(this.configs);
  @override
  final List<CustomProviderConfig> configs;
}

const _config = CustomProviderConfig(
  id: 'my-endpoint',
  displayName: 'My Endpoint',
  template: kOpenAIImageTemplateId,
  baseUrl: 'https://example.com/v1',
  modelId: 'flux-pro',
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      customProviderSourceProvider
          .overrideWithValue(const _FakeSource([_config])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('默认源为空实现 → registry 仅内置 9 款（现有容器零影响）', () {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(customProviderSourceProvider).configs, isEmpty);
    expect(container.read(providerRegistryProvider).ids, hasLength(9));
  });

  test('custom factory 并入 registry：内置 9 款 + custom:<id>', () {
    final registry = _container().read(providerRegistryProvider);

    expect(registry.ids, hasLength(10));
    expect(registry.contains('custom:my-endpoint'), isTrue);
    expect(registry.contains('openai-image'), isTrue);
  });

  test('registry.get 返回缓存的 OpenAICompatibleImageProvider', () {
    final registry = _container().read(providerRegistryProvider);

    final a = registry.get('custom:my-endpoint');
    final b = registry.get('custom:my-endpoint');
    expect(a, isA<OpenAICompatibleImageProvider>());
    expect(identical(a, b), isTrue, reason: '实例必须按 providerId 缓存');
  });

  test('custom Provider 独享 RateLimiter，且与内置隔离', () {
    final registry = _container().read(providerRegistryProvider);

    final custom =
        registry.get('custom:my-endpoint') as OpenAICompatibleImageProvider;
    final again =
        registry.get('custom:my-endpoint') as OpenAICompatibleImageProvider;
    expect(
      identical(custom.rateLimiterForTesting, again.rateLimiterForTesting),
      isTrue,
      reason: 'RateLimiter 必须在 get() 之间共享',
    );

    final limiters = <ProviderRateLimiter>{
      // 与同为 SyncProviderBase 的同步系内置对比，断言跨 providerId 隔离。
      for (final id in const [
        'custom:my-endpoint',
        'openai-image',
        'gemini-image',
      ])
        _limiterOf(registry.get(id)),
    };
    expect(limiters, hasLength(3), reason: '跨 providerId 不得共享桶');
  });

  test('providerCapabilitiesListProvider 同步合并：内置在前，custom 派生在后', () {
    final caps = _container().read(providerCapabilitiesListProvider);

    expect(caps, hasLength(10));
    expect(
      caps.take(9).map((c) => c.providerId),
      kAllProviderCapabilities.map((c) => c.providerId),
    );
    final custom = caps.last;
    expect(custom.providerId, 'custom:my-endpoint');
    expect(custom.displayName, 'My Endpoint');
    expect(custom, deriveCustomProviderCapabilities(_config));
  });

  test('providerDisplayNamesProvider 含 custom 显示名', () {
    final names = _container().read(providerDisplayNamesProvider);
    expect(names['custom:my-endpoint'], 'My Endpoint');
  });
}

ProviderRateLimiter _limiterOf(Object provider) {
  if (provider is SyncProviderBase) return provider.rateLimiterForTesting;
  fail('非 SyncProviderBase：${provider.runtimeType}');
}
