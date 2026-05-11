// ProviderRegistry：providerId → Submittable 工厂的中心映射。
//
// 所有 Provider 必须在 lib/core/di/providers.dart 注册到全局 registry。
// UI / Service 层取 Provider 只走 registry.get(id)，不 import 具体实现。
//
// 启动期自检——同 providerId 出现两个实现直接 AssertionError，不让过。

import '../core/interfaces/generation_provider.dart';
import '../core/models/provider_capabilities.dart';

/// Provider 工厂签名：给定 Key，返回已接线好 RateLimiter 的实例。
typedef ProviderFactory = Submittable Function();

class ProviderRegistry {
  ProviderRegistry(Map<String, ProviderFactory> entries)
      : _entries = Map.unmodifiable(entries) {
    assert(
      entries.keys.every((k) => k.isNotEmpty),
      'providerId must not be empty',
    );
  }

  final Map<String, ProviderFactory> _entries;

  /// 按 id 取 Provider。不存在抛 ArgumentError。
  Submittable get(String providerId) {
    final factory = _entries[providerId];
    if (factory == null) {
      throw ArgumentError.value(providerId, 'providerId', 'not registered');
    }
    return factory();
  }

  /// 全部已注册 ID（按插入顺序）。
  Iterable<String> get ids => _entries.keys;

  /// 是否已注册。
  bool contains(String providerId) => _entries.containsKey(providerId);

  /// 列出所有 Provider 的 capabilities——UI 下拉菜单数据源。
  List<ProviderCapabilities> listCapabilities() =>
      _entries.values.map((f) => f().capabilities).toList(growable: false);
}
