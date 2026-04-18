/// SecureStorage 的 key 命名约定（ARCHITECTURE §9.2）。
///
/// 所有 key 必须经此处构造，禁止散落字面量。
class SecureStorageKeys {
  const SecureStorageKeys._();

  /// `provider.{providerId}.api_key`
  static String providerApiKey(String providerId) =>
      'provider.$providerId.api_key';

  /// 全局代理密码（无 provider 维度）。
  static const String proxyPassword = 'network.proxy.password';
}
