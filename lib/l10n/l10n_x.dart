// BuildContext.l10n 快捷访问：widget 读 context.l10n.xxx 而非 AppLocalizations.of(context).xxx。
import 'package:flutter/widgets.dart';

import '../core/errors/ink_error.dart';
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
