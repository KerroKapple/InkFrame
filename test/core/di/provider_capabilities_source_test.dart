// providerCapabilitiesListProvider：直接读 const 能力，不实例化 Provider；
// 且 const 列表与 registry 注册项严格一致（防漂移）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';

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

void main() {
  test('下拉能力 = const 列表（不实例化 Provider），且与 registry.ids 对齐', () {
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
}
