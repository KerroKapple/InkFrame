// CustomProviderSource：自定义 Provider 配置的只读源（PROVIDER-API §13.5）。
//
// 消费方（providerRegistryProvider / providerCapabilitiesListProvider）要求
// 同步可读；加载是具体实现（CustomProvidersFileService）的 bootstrap 职责，
// 在 main() 构建容器前完成。本切片契约：会话内 configs 不变。

import '../models/custom_provider_config.dart';

abstract class CustomProviderSource {
  /// 已通过校验的配置列表；启动期加载完成后同步可读。
  List<CustomProviderConfig> get configs;
}
