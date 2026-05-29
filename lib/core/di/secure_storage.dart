import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/secure_storage_keys.dart';
import '../interfaces/secure_storage_service.dart';
import '../../services/platform_secure_storage_service.dart';

/// app-scoped 单实例：SecureStorage 是平台级资源，进程内共享。
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return PlatformSecureStorageService();
});

/// 至少存在一把 provider API key 即视为已配置；Studio 横幅据此决定是否软提示去配置。
final apiKeyUnlockedProvider = FutureProvider<bool>((ref) async {
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
      // storage 异常视作"未配置"，由 Studio 横幅提示用户去配置。
    }
  }
  return false;
});
