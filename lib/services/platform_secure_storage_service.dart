import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/secure_storage_service.dart';

/// flutter_secure_storage 平台实现。
///
/// - macOS：Keychain（kSecClassGenericPassword）
/// - Windows：Credential Manager
///
/// 平台层 PlatformException 在此边界统一翻译为 [LocalIOError]；
/// extra 只携带操作名与 key 名，绝不携带明文 value。
class PlatformSecureStorageService implements SecureStorageService {
  PlatformSecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<T> _guard<T>(String op, String key, Future<T> Function() run) async {
    try {
      return await run();
    } on PlatformException catch (e, st) {
      throw LocalIOError(
        cause: e,
        stackTrace: st,
        extra: <String, Object?>{'op': op, 'key': key},
      );
    }
  }

  @override
  Future<void> store(String key, String value) =>
      _guard('store', key, () => _storage.write(key: key, value: value));

  @override
  Future<String?> retrieve(String key) =>
      _guard('retrieve', key, () => _storage.read(key: key));

  @override
  Future<void> delete(String key) =>
      _guard('delete', key, () => _storage.delete(key: key));

  @override
  Future<bool> exists(String key) =>
      _guard('exists', key, () => _storage.containsKey(key: key));
}
