// RateLimiter 单例不变量回归测试（#78）。
//
// 历史 bug：ProviderRegistry 的 factory 闭包里 inline 新建 RateLimiter，
// registry.get(id) 每次返回的 Provider 都持有全新 token bucket，限速失效。
//
// 不变量：同一 providerId，连续两次 get() 返回的 Provider 必须捕获同一个
// ProviderRateLimiter 实例（identical）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/providers/dashscope_async_provider_base.dart';
import 'package:inkframe/providers/gemini_image_provider.dart';
import 'package:inkframe/providers/openai_image_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

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

ProviderRateLimiter _limiterOf(Object provider) {
  if (provider is GeminiImageProvider) return provider.rateLimiterForTesting;
  if (provider is OpenAIImageProvider) return provider.rateLimiterForTesting;
  if (provider is DashScopeAsyncProviderBase) {
    return provider.rateLimiterForTesting;
  }
  fail('未知 Provider 类型: ${provider.runtimeType}');
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('每个 providerId 连续 get() 共享同一个 RateLimiter 实例', () {
    final registry = container.read(providerRegistryProvider);

    for (final id in registry.ids) {
      final a = registry.get(id);
      final b = registry.get(id);
      expect(
        identical(_limiterOf(a), _limiterOf(b)),
        isTrue,
        reason:
            '$id: RateLimiter 必须在 get() 之间共享，否则 token bucket 每次重置导致限速失效',
      );
    }
  });

  test('不同 providerId 持有不同的 RateLimiter（隔离）', () {
    final registry = container.read(providerRegistryProvider);
    final limiters = <ProviderRateLimiter>{};

    for (final id in registry.ids) {
      limiters.add(_limiterOf(registry.get(id)));
    }
    expect(
      limiters.length,
      registry.ids.length,
      reason: '每个 providerId 必须有独立 RateLimiter，禁止跨 Provider 共享桶',
    );
  });
}
