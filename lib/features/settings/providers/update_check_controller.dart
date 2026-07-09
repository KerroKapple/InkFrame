// UpdateCheckController：应用内检查更新的状态编排（UPD-1）。
//
// 两条入口共用一个 app 级状态（NotifierProvider,非 autoDispose——更新提示
// 要在设置页关开之间存活）：
//   - checkNow()：About 区手动触发,绕过节流,loading/error 全量反馈到 UI;
//   - maybeCheckOnStartup()：main 启动 fire-and-forget,受偏好开关 + 6h 节流
//     约束（GitHub 匿名限流 60/h）,失败只落 INFO 日志、绝不打扰 UI。
// UpdateCheckPrefController：启动检查偏好开关（默认开）,持久化到 preferences.json。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/clock.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/preferences.dart';
import '../../../core/di/update_check.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/update_check_result.dart';

/// 启动静默检查的节流窗口（UPD-1 卡面拍定 6h,防匿名限流 60/h）。
const Duration kUpdateCheckThrottle = Duration(hours: 6);

const String _kLogModule = 'update.check';

class UpdateCheckController extends Notifier<AsyncValue<UpdateCheckResult?>> {
  @override
  AsyncValue<UpdateCheckResult?> build() =>
      const AsyncData<UpdateCheckResult?>(null);

  /// 手动检查：不受偏好开关与节流约束,状态全量走 AsyncValue。
  Future<void> checkNow() async {
    state = const AsyncLoading<UpdateCheckResult?>();
    try {
      final UpdateCheckResult result =
          await ref.read(updateCheckServiceProvider).check();
      await _recordCheckedAt();
      state = AsyncData<UpdateCheckResult?>(result);
    } on InkError catch (e, st) {
      state = AsyncError<UpdateCheckResult?>(e, st);
    }
  }

  /// 启动静默检查：偏好关 / 6h 内已查 → 直接返回;失败仅 INFO,不动 state。
  Future<void> maybeCheckOnStartup() async {
    final prefs = ref.read(preferencesServiceProvider).current;
    if (!prefs.updateCheckEnabled) return;
    final String? iso = prefs.lastUpdateCheckAtIso;
    final DateTime? last = iso == null ? null : DateTime.tryParse(iso);
    final DateTime now = ref.read(clockProvider).nowUtc();
    if (last != null && now.difference(last) < kUpdateCheckThrottle) return;
    try {
      final UpdateCheckResult result =
          await ref.read(updateCheckServiceProvider).check();
      await _recordCheckedAt();
      state = AsyncData<UpdateCheckResult?>(result);
    } on InkError catch (e) {
      ref.read(loggerProvider).info(
            _kLogModule,
            'startup update check failed',
            extra: e.toLogJson(),
          );
    }
  }

  Future<void> _recordCheckedAt() {
    final String nowIso =
        ref.read(clockProvider).nowUtc().toIso8601String();
    return ref
        .read(preferencesServiceProvider)
        .update((p) => p.copyWith(lastUpdateCheckAtIso: nowIso));
  }
}

final updateCheckControllerProvider =
    NotifierProvider<UpdateCheckController, AsyncValue<UpdateCheckResult?>>(
  UpdateCheckController.new,
  name: 'updateCheckControllerProvider',
);

/// 启动静默检查偏好开关（默认开）。与 LocaleController 同模式：seed 自偏好,
/// setter 即时更新状态并异步落盘。
class UpdateCheckPrefController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(preferencesServiceProvider).current.updateCheckEnabled;

  void setEnabled(bool enabled) {
    state = enabled;
    unawaited(
      ref
          .read(preferencesServiceProvider)
          .update((p) => p.copyWith(updateCheckEnabled: enabled)),
    );
  }
}

final updateCheckPrefControllerProvider =
    NotifierProvider<UpdateCheckPrefController, bool>(
  UpdateCheckPrefController.new,
  name: 'updateCheckPrefControllerProvider',
);
