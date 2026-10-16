// API Key 输入框的占位提示按家族给。
//
// 这条测试存在的理由：输入框原来一律写 `sk-...`，而 Gemini 的 Key 是 `AIza`
// 开头——用户照着占位去找「sk- 开头的那串」，在 Google AI Studio 里找不到。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/features/settings/util/api_key_placeholder.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

void main() {
  group('apiKeyPlaceholderKindOf', () {
    test('Gemini 是 AIza 前缀，不是 sk-', () {
      expect(
        apiKeyPlaceholderKindOf('gemini-image'),
        ApiKeyPlaceholderKind.aizaPrefixed,
      );
    });

    test('OpenAI / Stability 是 sk- 前缀', () {
      expect(
        apiKeyPlaceholderKindOf('openai-image'),
        ApiKeyPlaceholderKind.skPrefixed,
      );
      expect(
        apiKeyPlaceholderKindOf('stability-image-core'),
        ApiKeyPlaceholderKind.skPrefixed,
      );
    });

    test('DashScope 家族六个成员都折叠到同一种（sk-）', () {
      for (final String id in <String>[
        'wanx-image',
        'wanx-t2v',
        'wanx-i2v',
        'wanx-r2v',
        'kling-v3',
        'kling-v3-omni',
      ]) {
        expect(
          apiKeyPlaceholderKindOf(id),
          ApiKeyPlaceholderKind.skPrefixed,
          reason: id,
        );
      }
    });

    test('自定义端点与未登记的家族不猜前缀', () {
      expect(
        apiKeyPlaceholderKindOf('${kCustomProviderIdPrefix}my-relay'),
        ApiKeyPlaceholderKind.generic,
      );
      expect(
        apiKeyPlaceholderKindOf('fal-ai'),
        ApiKeyPlaceholderKind.generic,
      );
    });
  });

  group('apiKeyPlaceholderText', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations zh = lookupAppLocalizations(const Locale('zh'));

    test('三种口径落到三条不同的文案', () {
      final Set<String> texts = <String>{
        apiKeyPlaceholderText(en, 'gemini-image'),
        apiKeyPlaceholderText(en, 'openai-image'),
        apiKeyPlaceholderText(en, '${kCustomProviderIdPrefix}x'),
      };
      expect(texts, hasLength(3));
    });

    test('Gemini 的提示以 AIza 开头；sk- 家族沿用原占位', () {
      expect(apiKeyPlaceholderText(en, 'gemini-image'), startsWith('AIza'));
      expect(apiKeyPlaceholderText(zh, 'gemini-image'), startsWith('AIza'));
      expect(
        apiKeyPlaceholderText(en, 'wanx-image'),
        en.settingsApiKeyPlaceholder,
      );
      expect(apiKeyPlaceholderText(en, 'openai-image'), startsWith('sk-'));
    });

    test('不猜前缀的那句既不写 sk- 也不写 AIza', () {
      final String generic =
          apiKeyPlaceholderText(en, '${kCustomProviderIdPrefix}x');
      expect(generic, en.settingsApiKeyPlaceholderGeneric);
      expect(generic.startsWith('sk-'), isFalse);
      expect(generic.startsWith('AIza'), isFalse);
    });
  });
}
