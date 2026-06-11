// SecureStorageKeys — scope 折叠 + key 命名约定单测。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';

void main() {
  group('scopeOf', () {
    test('DashScope 6 款成员全部折叠到 "dashscope"', () {
      const members = [
        'wanx-image',
        'wanx-t2v',
        'wanx-i2v',
        'wanx-r2v',
        'kling-v3',
        'kling-v3-omni',
      ];
      for (final id in members) {
        expect(SecureStorageKeys.scopeOf(id), 'dashscope',
            reason: '$id should map to dashscope family');
      }
    });

    test('Gemini 保持独立 scope', () {
      expect(SecureStorageKeys.scopeOf('gemini-image'), 'gemini-image');
    });

    test('未知 providerId 透传为 scope', () {
      expect(SecureStorageKeys.scopeOf('custom-provider'), 'custom-provider');
    });
  });

  group('providerApiKey', () {
    test('DashScope 成员共享同一 storage key', () {
      final keyA = SecureStorageKeys.providerApiKey('wanx-image');
      final keyB = SecureStorageKeys.providerApiKey('kling-v3-omni');
      expect(keyA, 'provider.dashscope.api_key');
      expect(keyA, keyB);
    });

    test('非家族成员走自己的 key', () {
      expect(
        SecureStorageKeys.providerApiKey('gemini-image'),
        'provider.gemini-image.api_key',
      );
    });
  });

  group('displayNameOf', () {
    test('dashscope → DashScope', () {
      expect(SecureStorageKeys.displayNameOf('dashscope'), 'DashScope');
    });

    test('未登记 family → 回 scope 本身', () {
      expect(SecureStorageKeys.displayNameOf('gemini-image'), 'gemini-image');
    });

    test('openai-image → OpenAI（友好标签）', () {
      expect(SecureStorageKeys.displayNameOf('openai-image'), 'OpenAI');
    });
  });
}
