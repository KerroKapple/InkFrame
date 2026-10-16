// Key 存在哪：macOS 叫钥匙串，Windows 叫凭据管理器——同一句话在两个平台上各说各的叫法。
import 'package:flutter/foundation.dart';

import '../../../l10n/generated/app_localizations.dart';

/// [platform] 测试注入用；null 时读 defaultTargetPlatform。非 macOS 一律按 Windows 说（本产品只发这两个平台）。
String secureStoreName(AppLocalizations l10n, {TargetPlatform? platform}) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.macOS
        ? l10n.secureStoreNameMac
        : l10n.secureStoreNameWindows;
