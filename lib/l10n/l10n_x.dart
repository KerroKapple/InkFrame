// BuildContext.l10n 快捷访问：widget 读 context.l10n.xxx 而非 AppLocalizations.of(context).xxx。
import 'package:flutter/widgets.dart';

import '../core/errors/ink_error.dart';
import 'generated/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// InkError → 用户可读的本地化字符串。复用 messageKey 做 switch，全 ARB key 一一映射。
String l10nError(BuildContext context, InkError e) {
  final l = context.l10n;
  return switch (e.messageKey) {
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
