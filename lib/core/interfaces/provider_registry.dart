// ProviderRegistry 抽象契约：providerId → Submittable 的查找入口。
//
// UI / Service 层只依赖本接口（DIP），具体实现见
// lib/providers/provider_registry.dart。

import '../models/provider_capabilities.dart';
import 'generation_provider.dart';

/// Provider 工厂签名：返回已接线好 keySource / RateLimiter 的实例。
typedef ProviderFactory = Submittable Function();

abstract class ProviderRegistry {
  /// 按 id 取 Provider。未注册抛 ProviderError(invalidParameter)。
  Submittable get(String providerId);

  /// 全部已注册 ID（按插入顺序）。
  Iterable<String> get ids;

  /// 是否已注册。
  bool contains(String providerId);

  /// 列出所有 Provider 的 capabilities——UI 下拉菜单数据源。
  List<ProviderCapabilities> listCapabilities();
}
