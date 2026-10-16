// 设置页的页名：设置浮层左导航与引导底部「打开设置 › 〈页名〉」共用同一份——链接上写的就是
// 用户点过去在左导航上看到的那个字。
import '../../../l10n/generated/app_localizations.dart';
import '../providers/settings_page.dart';

String settingsPageLabel(AppLocalizations l10n, SettingsPage page) => switch (page) {
      SettingsPage.general => l10n.settingsNavGeneral,
      SettingsPage.apiKeys => l10n.settingsApiKeysSection,
      SettingsPage.shortcuts => l10n.settingsNavShortcuts,
      SettingsPage.performance => l10n.settingsNavPerformance,
      SettingsPage.nodeLayout => l10n.settingsNavNodeLayout,
      SettingsPage.network => l10n.settingsNavNetwork,
      SettingsPage.storage => l10n.settingsStorageSection,
      SettingsPage.about => l10n.settingsAboutSection,
    };
