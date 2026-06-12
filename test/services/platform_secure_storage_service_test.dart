// PlatformSecureStorageService 边界测试 —— PlatformException 必须翻译成
// LocalIOError（ME-07），且错误对象任何字段都不得泄漏 key 的明文 value。

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/services/platform_secure_storage_service.dart';

const String _secret = 'sk-SUPER-SECRET-VALUE';

/// 任意调用都抛 PlatformException 的假插件。
class _ThrowingStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw PlatformException(code: 'keychain_error', message: 'os says no');
  }
}

/// 正常工作的内存假插件——验证非异常路径直通。
class _MemoryStorage implements FlutterSecureStorage {
  final Map<String, String> box = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    final key = named[#key] as String?;
    switch (invocation.memberName) {
      case #write:
        box[key!] = named[#value] as String;
        return Future<void>.value();
      case #read:
        return Future<String?>.value(box[key]);
      case #delete:
        box.remove(key);
        return Future<void>.value();
      case #containsKey:
        return Future<bool>.value(box.containsKey(key));
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('PlatformSecureStorageService 错误边界', () {
    late PlatformSecureStorageService service;

    setUp(() {
      service = PlatformSecureStorageService(storage: _ThrowingStorage());
    });

    test('store 的 PlatformException 翻译为 LocalIOError', () async {
      await expectLater(
        service.store('provider.x.api_key', _secret),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('retrieve 的 PlatformException 翻译为 LocalIOError', () async {
      await expectLater(
        service.retrieve('provider.x.api_key'),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('delete 的 PlatformException 翻译为 LocalIOError', () async {
      await expectLater(
        service.delete('provider.x.api_key'),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('exists 的 PlatformException 翻译为 LocalIOError', () async {
      await expectLater(
        service.exists('provider.x.api_key'),
        throwsA(isA<LocalIOError>()),
      );
    });

    test('LocalIOError 保留 cause 且任何字段不含明文 value', () async {
      late LocalIOError err;
      try {
        await service.store('provider.x.api_key', _secret);
        fail('expected LocalIOError');
      } on LocalIOError catch (e) {
        err = e;
      }
      expect(err.cause, isA<PlatformException>());
      expect(err.toString(), isNot(contains(_secret)));
      expect(err.extra.toString(), isNot(contains(_secret)));
      expect(err.toLogJson().toString(), isNot(contains(_secret)));
    });
  });

  group('PlatformSecureStorageService 正常路径', () {
    test('store / retrieve / exists / delete 直通底层插件', () async {
      final mem = _MemoryStorage();
      final service = PlatformSecureStorageService(storage: mem);

      await service.store('k', 'v');
      expect(await service.retrieve('k'), 'v');
      expect(await service.exists('k'), isTrue);
      await service.delete('k');
      expect(await service.exists('k'), isFalse);
      expect(await service.retrieve('k'), isNull);
    });
  });
}
