import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/secure_storage_keys.dart';
import '../interfaces/secure_storage_service.dart';
import '../../services/platform_secure_storage_service.dart';
import 'providers.dart';

/// app-scoped 单实例：SecureStorage 是平台级资源，进程内共享。
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return PlatformSecureStorageService();
});

/// 是否已配置至少一把 provider API key。Studio 软 banner 据此提示去配置；
/// 不再作为进入应用的硬门槛（首屏 Lock 已移除）。
///
/// 候选 scope 从 registry 注册表经 scopeOf 派生——新接 Provider 自动纳入，
/// 不再维护手写过期列表。
final anyProviderKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  final registry = ref.watch(providerRegistryProvider);
  final scopes = registry.ids.map(SecureStorageKeys.scopeOf).toSet();
  for (final scope in scopes) {
    try {
      // scopeOf 幂等：scope 直接作为 providerApiKey 入参等价于家族任一成员。
      if (await storage.exists(SecureStorageKeys.providerApiKey(scope))) {
        return true;
      }
    } catch (_) {
      // storage 异常视作未配置，由 banner 提示用户去 Settings 配置。
    }
  }
  return false;
});
