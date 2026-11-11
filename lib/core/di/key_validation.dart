// Key scope → 谁来校验这把 Key。
//
// 生成 Provider 的 Key 由注册表里的 Provider 自己校验；Claude 不在注册表里，
// 由 AnthropicClient 校验（GET /v1/models，不耗生成额度）。设置页 Key 行与
// 首启向导只认这一个入口。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/secure_storage_keys.dart';
import '../interfaces/generation_provider.dart';
import 'anthropic.dart';
import 'providers.dart';

/// family arg = providerId（家族成员任选其一）或 [SecureStorageKeys.anthropicScope]。
/// null ⇒ 该 Provider 没有校验能力（视作有效）。
final apiKeyValidatorProvider = Provider.family<KeyValidatable?, String>(
  (ref, providerId) {
    if (SecureStorageKeys.scopeOf(providerId) ==
        SecureStorageKeys.anthropicScope) {
      return ref.watch(anthropicClientProvider);
    }
    final Submittable provider =
        ref.watch(providerRegistryProvider).get(providerId);
    return provider is KeyValidatable ? provider as KeyValidatable : null;
  },
  name: 'apiKeyValidatorProvider',
);
