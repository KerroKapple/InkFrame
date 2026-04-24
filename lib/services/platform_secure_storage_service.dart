import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/interfaces/secure_storage_service.dart';

/// flutter_secure_storage 平台实现。
///
/// - macOS：Keychain（kSecClassGenericPassword）
/// - Windows：Credential Manager
class PlatformSecureStorageService implements SecureStorageService {
  PlatformSecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                // ad-hoc / 个人 Dev cert 签名下 DataProtectionKeychain 需 entitlement，
                // 切回传统文件型 Keychain（Keychain Access.app 能看到），不要 entitlement。
                usesDataProtectionKeychain: false,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<void> store(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> retrieve(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<bool> exists(String key) => _storage.containsKey(key: key);
}
