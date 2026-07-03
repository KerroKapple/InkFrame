// customProviderSourceProvider：默认空实现（测试/无配置即可用）；
// main 启动时用已完成 load() 的 CustomProvidersFileService 覆盖（见 lib/main.dart）。
//
// 本切片契约：configs 会话内不变（改 json 重启生效）——providerRegistryProvider
// watch 本 provider 但永不因此重建（不可 invalidate，见 PROVIDER-API §13.5）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/custom_providers_file_service.dart';
import '../interfaces/custom_provider_source.dart';

final customProviderSourceProvider = Provider<CustomProviderSource>(
  (ref) => const EmptyCustomProviderSource(),
  name: 'customProviderSourceProvider',
);
