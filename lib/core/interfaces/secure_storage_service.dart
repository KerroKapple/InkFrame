/// 平台安全密钥存储服务（macOS Keychain / Windows Credential Manager）。
///
/// 唯一允许存取 API Key 与代理密码的入口，详见 ARCHITECTURE §9。
abstract class SecureStorageService {
  Future<void> store(String key, String value);

  Future<String?> retrieve(String key);

  Future<void> delete(String key);

  Future<bool> exists(String key);
}
