// ApiKeyScopeController — 设置页单个 key scope 的状态机。
//
// family arg = 该 scope 的代表 providerId（家族成员任选其一）；
// storage key 经 SecureStorageKeys.providerApiKey 自动折叠到家族 scope。
//
// state: AsyncValue<bool> = 该 scope 是否已配置。
// save 流程：registry 取 Provider → validateApiKey →
//   valid          → 落盘 → ApiKeySaved
//   invalid        → 不落盘 → ApiKeyRejected(reason)
//   networkError   → 照常落盘（离线不阻塞配置）→ ApiKeySavedUnverified
// 存储层 InkError（如 LocalIOError）原样透传给 UI。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/generation_provider.dart';
import '../../../core/models/key_validation_result.dart';

/// save 的三种用户可见结局。
///
/// 为什么是 sealed class 而不是三态枚举：被拒必须带「为什么被拒」。
/// 枚举版把 Key 无效 / 余额不足 / 内容策略压成同一个 rejected，两处消费侧
/// 只能统一记 invalid_key，于是余额不足也显示「Key 无效」——用户据此去换一把
/// 本来没问题的 Key，白费一轮。reason 做成载荷而不是再加两个枚举值，是为了
/// 以后多一种成因时 ApiKeySaveOutcome 本身不用改（OCP）。
///
/// 本层不产文案：view 层对 [KeyInvalidReason] 做 exhaustive switch 映射 ARB
/// （与 InspectorSubmitError 同款分工）。
sealed class ApiKeySaveOutcome {
  const ApiKeySaveOutcome();
}

/// 验证通过并已落盘。
final class ApiKeySaved extends ApiKeySaveOutcome {
  const ApiKeySaved();
}

/// 无法判定（网络层失败）但照常落盘——离线不该阻塞配置，首次生成时会实际校验。
final class ApiKeySavedUnverified extends ApiKeySaveOutcome {
  const ApiKeySavedUnverified();
}

/// 服务商明确拒绝，未落盘。
final class ApiKeyRejected extends ApiKeySaveOutcome {
  const ApiKeyRejected(this.reason);

  /// 原样来自 Provider 的 [KeyValidationResult.invalid]。
  /// 控制器不做任何推断或改写——分不出 quota / policy 的 Provider 自己就回
  /// [KeyInvalidReason.invalidKey]，这里不替它猜。
  final KeyInvalidReason reason;
}

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
    // reason 原样透出，不合并、不降级——它就是本层唯一知道却曾经丢掉的那一位信息。
    if (result is KeyInvalid) return ApiKeyRejected(result.reason);

    await ref.read(secureStorageServiceProvider).store(_storageKey, value);
    // key 集合变化 → 让 Studio 软 banner 重新评估是否已配置。
    ref.invalidate(anyProviderKeyConfiguredProvider);
    state = const AsyncData(true);
    return result is KeyValid
        ? const ApiKeySaved()
        : const ApiKeySavedUnverified();
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
