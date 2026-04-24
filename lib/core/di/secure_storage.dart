import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/secure_storage_service.dart';
import '../../services/file_secure_storage_service.dart';
import '../../services/platform_secure_storage_service.dart';
import 'paths.dart';

/// app-scoped 单实例：SecureStorage 是平台级资源，进程内共享。
///
/// Debug + macOS：走文件型实现（AppPaths.config/secrets.dev.json），
/// 绕开 Keychain 对 ad-hoc 签名缺 entitlement 的限制。
/// 其他场景（Release、Windows、任何平台）走 Platform/Keychain 实现。
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  if (kDebugMode && Platform.isMacOS) {
    return FileSecureStorageService(() => ref.read(appPathsProvider));
  }
  return PlatformSecureStorageService();
});
