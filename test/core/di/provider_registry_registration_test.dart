// providerRegistryProvider 注册验证——断言 Registry 暴露全部已接 Provider。
//
// 新 Provider 接入时务必同步本测试的 expected ids 清单，守住"Plan 里承诺的
// Provider 集合"不被悄悄砍掉。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';

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

void main() {
  test('providerRegistryProvider 暴露全部已接 Provider', () {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      ],
    );
    addTearDown(container.dispose);

    final ids = container.read(providerRegistryProvider).ids.toSet();
    expect(ids, <String>{
      'gemini-image',
      'wanx-image',
      'wanx-t2v',
      'wanx-i2v',
      'wanx-r2v',
      'kling-v3',
      'kling-v3-omni',
      'stability-image-core',
    });
  });

  test('capabilities list 顺序稳定（与 Registry 注册顺序一致）', () {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      ],
    );
    addTearDown(container.dispose);

    final caps = container.read(providerCapabilitiesListProvider);
    expect(caps.map((c) => c.providerId).toList(), [
      'gemini-image',
      'wanx-image',
      'wanx-t2v',
      'wanx-i2v',
      'wanx-r2v',
      'kling-v3',
      'kling-v3-omni',
      'stability-image-core',
    ]);
  });
}
