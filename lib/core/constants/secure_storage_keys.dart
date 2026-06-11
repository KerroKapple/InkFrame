/// SecureStorage 的 key 命名约定（ARCHITECTURE §9.2）。
///
/// 所有 key 必须经此处构造，禁止散落字面量。
///
/// Provider family：同一家 API 提供商（如阿里云 DashScope）的多个 Provider
/// 实际共用一把 Key——通过 [scopeOf] 折叠到家族 scope，避免用户重复配置。
class SecureStorageKeys {
  const SecureStorageKeys._();

  /// DashScope 家族成员（Wanx / Kling v3 均走阿里云 DashScope API Key）。
  static const Set<String> _dashscopeMembers = <String>{
    'wanx-image',
    'wanx-t2v',
    'wanx-i2v',
    'wanx-r2v',
    'kling-v3',
    'kling-v3-omni',
  };

  /// 每个 Provider 家族的显示名——Settings UI 渲染用。
  static const Map<String, String> _familyDisplayNames = <String, String>{
    'dashscope': 'DashScope',
    'stability-image-core': 'Stable Image Core',
  };

  /// 解析 providerId → storage scope（家族成员共用 scope）。
  static String scopeOf(String providerId) {
    if (_dashscopeMembers.contains(providerId)) return 'dashscope';
    return providerId;
  }

  /// scope → 显示名。未登记 family 直接回 scope 本身（自然即 providerId）。
  static String displayNameOf(String scope) =>
      _familyDisplayNames[scope] ?? scope;

  /// `provider.{scope}.api_key`——scope 可能是 providerId 或家族名。
  static String providerApiKey(String providerId) =>
      'provider.${scopeOf(providerId)}.api_key';

  /// 全局代理密码（无 provider 维度）。
  static const String proxyPassword = 'network.proxy.password';
}
