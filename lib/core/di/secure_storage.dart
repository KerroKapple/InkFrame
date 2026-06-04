import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/secure_storage_keys.dart';
import '../interfaces/secure_storage_service.dart';
import '../../services/platform_secure_storage_service.dart';

/// app-scoped 单实例：SecureStorage 是平台级资源，进程内共享。
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return PlatformSecureStorageService();
});

/// 是否已配置至少一把 provider API key。Studio 软 banner 据此提示去配置；
/// 不再作为进入应用的硬门槛（首屏 Lock 已移除）。
final anyProviderKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  for (final providerId in const <String>[
    'gemini-image',
    'wanx-image',
    'kling-v3',
  ]) {
    try {
      if (await storage.exists(SecureStorageKeys.providerApiKey(providerId))) {
        return true;
      }
    } catch (_) {
      // storage 异常视作未配置，由 banner 提示用户去 Settings 配置。
    }
  }
  return false;
});
