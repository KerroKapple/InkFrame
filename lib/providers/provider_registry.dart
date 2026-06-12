// CachingProviderRegistry：providerId → Submittable 的缓存实现。
//
// 所有 Provider 必须在 lib/core/di/providers.dart 注册到全局 registry。
// UI / Service 层取 Provider 只走 registry.get(id)，不 import 具体实现。
//
// 实例按 providerId 缓存（app-scoped）：
// - Dio 每个 Provider 只建一次，不再每次 get() 泄漏新连接池
// - 同步 Provider 的 _inlineCache（submit 暂存 / poll 消费）跨调用方一致
// - RateLimiter 单例不变量由缓存天然保证

import '../core/errors/ink_error.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/interfaces/provider_registry.dart';
import '../core/models/provider_capabilities.dart';

export '../core/interfaces/provider_registry.dart';

class CachingProviderRegistry implements ProviderRegistry {
  CachingProviderRegistry(Map<String, ProviderFactory> entries)
      : _factories = Map.unmodifiable(entries) {
    assert(
      entries.keys.every((k) => k.isNotEmpty),
      'providerId must not be empty',
    );
  }

  final Map<String, ProviderFactory> _factories;
  final Map<String, Submittable> _instances = {};

  @override
  Submittable get(String providerId) {
    final cached = _instances[providerId];
    if (cached != null) return cached;
    final factory = _factories[providerId];
    if (factory == null) {
      // providerId 来自持久化任务 / 画布配置——属运行期数据错误，
      // 走 InkError 链路冒泡到 UI，而非编程断言。
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {
          'provider_id': providerId,
          'reason': 'provider_not_registered',
        },
      );
    }
    return _instances[providerId] = factory();
  }

  @override
  Iterable<String> get ids => _factories.keys;

  @override
  bool contains(String providerId) => _factories.containsKey(providerId);

  @override
  List<ProviderCapabilities> listCapabilities() =>
      ids.map((id) => get(id).capabilities).toList(growable: false);
}
