// FakeSecureStorage：内存版 SecureStorageService。
//
// 真实现走 macOS Keychain / Windows Credential Manager——CI / headless test
// 无法访问，必须 fake。所有 API Key / 代理密码相关单测都该用这个。

import 'package:inkframe/core/interfaces/secure_storage_service.dart';

class FakeSecureStorage implements SecureStorageService {
  FakeSecureStorage([Map<String, String>? seed])
      : _store = <String, String>{...?seed};

  final Map<String, String> _store;

  /// 直接读字典——断言用。
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_store);

  @override
  Future<void> store(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> retrieve(String key) async => _store[key];

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<bool> exists(String key) async => _store.containsKey(key);
}
