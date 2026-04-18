import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/secure_storage_service.dart';
import '../../services/platform_secure_storage_service.dart';

/// app-scoped 单实例：SecureStorage 是平台级资源，进程内共享。
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return PlatformSecureStorageService();
});
