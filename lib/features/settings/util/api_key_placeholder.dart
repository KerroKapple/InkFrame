// API Key 输入框的占位提示按 Provider 家族给——纯函数。
//
// 为什么需要它：输入框原来一律写 `sk-...`，而 Gemini 的 Key 是 `AIza` 开头。
// 用户照着占位去找「sk- 开头的那串」，在 Google AI Studio 里是找不到的。
//
// 设置页 Key 表与首启向导第 2 步都用这里：两处是同一把 Key 的两个入口，
// 占位提示不该各说一套。判据按 SecureStorageKeys.scopeOf 折叠后的家族 scope——
// 与两处存 Key 用的是同一个口径（DashScope 六个成员共一把 Key，提示也只有一种）。
import '../../../core/constants/secure_storage_keys.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 占位提示的三种口径。
enum ApiKeyPlaceholderKind {
  /// `sk-` 开头：OpenAI / DashScope / Stability。
  skPrefixed,

  /// `AIza` 开头：Google Gemini。
  aizaPrefixed,

  /// 格式不确定（自定义 OpenAI 兼容端点、未登记的家族）：只说「粘贴 Key」，
  /// 不猜前缀——猜错比不说更误导。
  generic,
}

/// 各家族 Key 的已知前缀。未登记的一律走 [ApiKeyPlaceholderKind.generic]。
const Map<String, ApiKeyPlaceholderKind> _kindByScope =
    <String, ApiKeyPlaceholderKind>{
  'gemini-image': ApiKeyPlaceholderKind.aizaPrefixed,
  'openai-image': ApiKeyPlaceholderKind.skPrefixed,
  'dashscope': ApiKeyPlaceholderKind.skPrefixed,
  'stability-image-core': ApiKeyPlaceholderKind.skPrefixed,
};

/// providerId（家族成员 id 也行）→ 占位提示口径。先折叠到家族 scope 再查表。
ApiKeyPlaceholderKind apiKeyPlaceholderKindOf(String providerId) =>
    _kindByScope[SecureStorageKeys.scopeOf(providerId)] ??
    ApiKeyPlaceholderKind.generic;

/// providerId → 占位提示文案。两处输入框都只调这一个。
String apiKeyPlaceholderText(AppLocalizations l10n, String providerId) =>
    switch (apiKeyPlaceholderKindOf(providerId)) {
      ApiKeyPlaceholderKind.skPrefixed => l10n.settingsApiKeyPlaceholder,
      ApiKeyPlaceholderKind.aizaPrefixed =>
        l10n.settingsApiKeyPlaceholderGemini,
      ApiKeyPlaceholderKind.generic => l10n.settingsApiKeyPlaceholderGeneric,
    };
