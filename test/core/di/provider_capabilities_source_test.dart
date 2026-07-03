// providerCapabilitiesListProvider：同步合并源（内置 const + custom 模板派生），
// 不实例化 Provider；custom 为空时原样返回 const 列表（零分配），
// 且 const 列表与 registry 注册项严格一致（防漂移）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/custom_provider_source.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';

class _FakeSecure implements SecureStorageService {
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

void main() {
  test('custom 为空：下拉能力 = const 列表（不实例化 Provider），且与 registry.ids 对齐', () {
    final c = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
    ]);
    addTearDown(c.dispose);

    final caps = c.read(providerCapabilitiesListProvider);
    // 同一 const 实例：证明走的是 const 路径，没经 registry.listCapabilities()。
    expect(identical(caps, kAllProviderCapabilities), isTrue);
    expect(caps.length, 9);

    // 与 registry 注册项严格一致（registry.ids 只读工厂表键，不实例化）。
    final registry = c.read(providerRegistryProvider);
    expect(caps.map((e) => e.providerId).toSet(), registry.ids.toSet());
  });

  test('有 custom：同步合并（内置顺序在前 + 模板派生在后），仍与 registry.ids 对齐', () {
    const config = CustomProviderConfig(
      id: 'my-endpoint',
      displayName: 'My Endpoint',
      template: kOpenAIImageTemplateId,
      baseUrl: 'https://example.com/v1',
      modelId: 'flux-pro',
    );
    final c = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(_FakeSecure()),
      customProviderSourceProvider
          .overrideWithValue(const _FakeSource([config])),
    ]);
    addTearDown(c.dispose);

    // 同步 read——image inspector 在 initState 里依赖该契约。
    final caps = c.read(providerCapabilitiesListProvider);
    expect(caps.length, 10);
    expect(
      caps.take(9).map((e) => e.providerId).toList(),
      kAllProviderCapabilities.map((e) => e.providerId).toList(),
    );
    expect(caps.last, deriveCustomProviderCapabilities(config));

    final registry = c.read(providerRegistryProvider);
    expect(caps.map((e) => e.providerId).toSet(), registry.ids.toSet());
  });
}
