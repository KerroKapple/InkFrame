// ApiKeyScopeController — 设置页单个 key scope 的状态机。
//
// family arg = 该 scope 的代表 providerId（家族成员任选其一）；
// storage key 经 SecureStorageKeys.providerApiKey 自动折叠到家族 scope。
//
// state: AsyncValue<bool> = 该 scope 是否已配置。
// save 流程：registry 取 Provider → validateApiKey →
//   valid          → 落盘 → saved
//   invalid        → 不落盘 → rejected
//   networkError   → 照常落盘（离线不阻塞配置）→ savedUnverified
// 存储层 InkError（如 LocalIOError）原样透传给 UI。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/generation_provider.dart';
import '../../../core/models/key_validation_result.dart';

/// save 的三种用户可见结局。
enum ApiKeySaveOutcome { saved, savedUnverified, rejected }

final apiKeyScopeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ApiKeyScopeController, bool, String>(ApiKeyScopeController.new);

class ApiKeyScopeController
    extends AutoDisposeFamilyAsyncNotifier<bool, String> {
  String get _storageKey => SecureStorageKeys.providerApiKey(arg);

  @override
  Future<bool> build(String providerId) =>
      ref.watch(secureStorageServiceProvider).exists(_storageKey);

  Future<ApiKeySaveOutcome> save(String value) async {
    final result = await _validate(value);
    if (result is KeyInvalid) return ApiKeySaveOutcome.rejected;

    await ref.read(secureStorageServiceProvider).store(_storageKey, value);
    // key 集合变化 → 让 Studio 软 banner 重新评估是否已配置。
    ref.invalidate(anyProviderKeyConfiguredProvider);
    state = const AsyncData(true);
    return result is KeyValid
        ? ApiKeySaveOutcome.saved
        : ApiKeySaveOutcome.savedUnverified;
  }

  Future<void> clear() async {
    await ref.read(secureStorageServiceProvider).delete(_storageKey);
    ref.invalidate(anyProviderKeyConfiguredProvider);
    state = const AsyncData(false);
  }

  Future<KeyValidationResult> _validate(String value) async {
    final provider = ref.read(providerRegistryProvider).get(arg);
    // 契约上所有 Provider 都实现 KeyValidatable；防御性兜底视作有效。
    if (provider is! KeyValidatable) return const KeyValidationResult.valid();
    try {
      return await (provider as KeyValidatable).validateApiKey(value);
    } on InkError {
      // 契约要求 validateApiKey 返回结果而非抛错；漏网的传输层错误归为不可判定。
      return const KeyValidationResult.networkError(
        message: 'validation transport failure',
      );
    }
  }
}
