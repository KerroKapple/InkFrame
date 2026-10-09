// BuildContext.l10n 快捷访问：widget 读 context.l10n.xxx 而非 AppLocalizations.of(context).xxx。
import 'package:flutter/widgets.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/database_restore_service.dart';
import '../core/models/key_validation_result.dart';
import 'generated/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// InkError → 用户可读的本地化字符串。
String l10nError(BuildContext context, InkError e) =>
    _l10nByMessageKey(context, e.messageKey);

/// InkErrorCode（如从 wire 字符串还原的裸错误码）→ 本地化文案。
/// 与 l10nError 共用同一 messageKey→ARB 映射，保持单一真相源。
String l10nErrorCode(BuildContext context, InkErrorCode code) =>
    _l10nByMessageKey(context, kInkErrorMessageKeys[code]!);

/// RestoreOutcome（非 restored）→ 失败文案（设置页 / 启动失败面共用，LB-22）。
String l10nRestoreFailure(AppLocalizations l10n, RestoreOutcome outcome) {
  return switch (outcome) {
    RestoreOutcome.failedNoBinaries => l10n.settingsBackupNoBinaries,
    RestoreOutcome.failedCorrupt => l10n.restoreFailedCorrupt,
    RestoreOutcome.failedVersionNewer => l10n.restoreFailedVersionNewer,
    RestoreOutcome.abortedPreBackup => l10n.restoreAbortedPreBackup,
    RestoreOutcome.failed || RestoreOutcome.restored => l10n.restoreFailed,
  };
}

/// Key 被拒原因 → 文案（首启向导第 2 步 / 设置页 Key 表共用）。
///
/// 为什么单独一个映射而不复用 l10nErrorCode：同一个成因在「保存 Key」语境下
/// 要说的话不一样。errorInsufficientBalance 只说"余额不足"，这里必须明说
/// 「未保存 + 去充值，换 Key 没用」——否则用户照旧去换一把好 Key。
///
/// 两处消费侧都走这一个函数，文案不会在两屏之间漂。
String l10nKeyRejectReason(AppLocalizations l10n, KeyInvalidReason reason) {
  return switch (reason) {
    KeyInvalidReason.invalidKey => l10n.settingsApiKeyRejectedInvalid,
    KeyInvalidReason.insufficientBalance => l10n.settingsApiKeyRejectedQuota,
    KeyInvalidReason.contentPolicy => l10n.settingsApiKeyRejectedPolicy,
  };
}

/// messageKey → ARB 字符串的唯一 switch（l10nError / l10nErrorCode 共用）。
String _l10nByMessageKey(BuildContext context, String messageKey) {
  final l = context.l10n;
  return switch (messageKey) {
    'errorInvalidKey' => l.errorInvalidKey,
    'errorInsufficientBalance' => l.errorInsufficientBalance,
    'errorContentPolicy' => l.errorContentPolicy,
    'errorInvalidParameter' => l.errorInvalidParameter,
    'errorNetworkTimeout' => l.errorNetworkTimeout,
    'errorNetworkOffline' => l.errorNetworkOffline,
    'errorProviderServer' => l.errorProviderServer,
    'errorProviderBusy' => l.errorProviderBusy,
    'errorProviderInvalidResponse' => l.errorProviderInvalidResponse,
    'errorPollTimeout' => l.errorPollTimeout,
    'errorDownloadFailed' => l.errorDownloadFailed,
    'errorLocalIO' => l.errorLocalIO,
    'errorCancelled' => l.errorCancelled,
    'errorCancelledOnExit' => l.errorCancelledOnExit,
    _ => l.errorUnknown,
  };
}

/// AsyncValue.error（静态类型 Object）→ 本地化文案。
/// InkError 走 l10nError 精确映射；非 InkError 兜底 errorUnknown。
String l10nAsyncError(BuildContext context, Object error) =>
    error is InkError ? l10nError(context, error) : context.l10n.errorUnknown;
