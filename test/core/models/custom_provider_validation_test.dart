// custom provider 校验纯函数全分支单测（GAP-1）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/custom_provider_validation.dart';

void main() {
  group('validateRequired', () {
    test('空/纯空白 → emptyField;非空 → null', () {
      expect(validateRequired(''), CustomProviderFieldError.emptyField);
      expect(validateRequired('   '), CustomProviderFieldError.emptyField);
      expect(validateRequired('x'), isNull);
    });
  });

  group('validateId', () {
    const noReserved = <String>{};
    test('合法 id 通过', () {
      expect(
        validateId('my-provider_1',
            takenIds: const {}, reservedProviderIds: noReserved),
        isNull,
      );
    });
    test('空 → emptyField;非法字符/首字符 → invalidId', () {
      expect(
        validateId('', takenIds: const {}, reservedProviderIds: noReserved),
        CustomProviderFieldError.emptyField,
      );
      expect(
        validateId('-lead', takenIds: const {}, reservedProviderIds: noReserved),
        CustomProviderFieldError.invalidId,
      );
      expect(
        validateId('has space',
            takenIds: const {}, reservedProviderIds: noReserved),
        CustomProviderFieldError.invalidId,
      );
      expect(
        validateId('中文', takenIds: const {}, reservedProviderIds: noReserved),
        CustomProviderFieldError.invalidId,
      );
    });
    test('重复 → duplicateId;撞内置 → reservedId', () {
      expect(
        validateId('dup',
            takenIds: const {'dup'}, reservedProviderIds: noReserved),
        CustomProviderFieldError.duplicateId,
      );
      expect(
        validateId('gemini',
            takenIds: const {},
            reservedProviderIds: const {'custom:gemini'}),
        CustomProviderFieldError.reservedId,
      );
    });
  });

  group('validateTemplate', () {
    test('白名单内通过;未知 → unknownTemplate;空 → emptyField', () {
      expect(validateTemplate('openai-image'), isNull);
      expect(
        validateTemplate('made-up'),
        CustomProviderFieldError.unknownTemplate,
      );
      expect(validateTemplate(''), CustomProviderFieldError.emptyField);
    });
  });

  group('validateBaseUrl', () {
    test('合法 http(s) 通过', () {
      expect(validateBaseUrl('https://api.example.com/v1'), isNull);
      expect(validateBaseUrl('http://127.0.0.1:8080'), isNull);
    });
    test('相对/非 http/无 host/query/fragment/userinfo → invalidBaseUrl', () {
      for (final bad in [
        '/relative',
        'ftp://x.com',
        'https://',
        'https://x.com/v1?key=1',
        'https://x.com/v1#frag',
        'https://user:pw@x.com',
      ]) {
        expect(
          validateBaseUrl(bad),
          CustomProviderFieldError.invalidBaseUrl,
          reason: bad,
        );
      }
      expect(validateBaseUrl(''), CustomProviderFieldError.emptyField);
    });
  });

  test('normalizeBaseUrl 剔尾部斜杠', () {
    expect(normalizeBaseUrl('https://x.com/v1///'), 'https://x.com/v1');
    expect(normalizeBaseUrl(' https://x.com '), 'https://x.com');
  });
}
