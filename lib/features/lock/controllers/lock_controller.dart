// LockController：把用户输入的 provider key 写入 SecureStorage，并使
// apiKeyUnlockedProvider 失效以触发上层 router 重新评估解锁状态。
//
// 当前先把 key 落到 gemini-image scope（首批支持的免费 provider）；后续
// onboarding 流程接入时再扩展为多 provider 选择。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/secure_storage.dart';

final lockControllerProvider =
    AsyncNotifierProvider<LockController, bool>(LockController.new);

class LockController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<void> submit(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      state = AsyncError(
        const FormatException('key is empty'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading<bool>();
    state = await AsyncValue.guard<bool>(() async {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.store(
        SecureStorageKeys.providerApiKey('gemini-image'),
        key,
      );
      ref.invalidate(apiKeyUnlockedProvider);
      return true;
    });
  }
}
