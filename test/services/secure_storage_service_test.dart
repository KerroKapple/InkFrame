import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';

class _InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _box = {};

  @override
  Future<void> store(String key, String value) async {
    _box[key] = value;
  }

  @override
  Future<String?> retrieve(String key) async => _box[key];

  @override
  Future<void> delete(String key) async {
    _box.remove(key);
  }

  @override
  Future<bool> exists(String key) async => _box.containsKey(key);
}

void main() {
  group('SecureStorageService 契约', () {
    late SecureStorageService storage;

    setUp(() {
      storage = _InMemorySecureStorage();
    });

    test('store + retrieve roundtrip', () async {
      await storage.store('k1', 'v1');
      expect(await storage.retrieve('k1'), 'v1');
    });

    test('retrieve 未存 key 返回 null', () async {
      expect(await storage.retrieve('missing'), isNull);
    });

    test('exists 真假分支', () async {
      expect(await storage.exists('k2'), isFalse);
      await storage.store('k2', 'v2');
      expect(await storage.exists('k2'), isTrue);
    });

    test('delete 后 retrieve = null 且 exists = false', () async {
      await storage.store('k3', 'v3');
      await storage.delete('k3');
      expect(await storage.retrieve('k3'), isNull);
      expect(await storage.exists('k3'), isFalse);
    });

    test('同 key 重复 store 覆盖旧值', () async {
      await storage.store('k4', 'old');
      await storage.store('k4', 'new');
      expect(await storage.retrieve('k4'), 'new');
    });

    test('删除不存在的 key 不抛', () async {
      await storage.delete('never-existed');
      expect(await storage.exists('never-existed'), isFalse);
    });
  });

  group('SecureStorageKeys 命名约定', () {
    test('providerApiKey 拼接 provider id', () {
      expect(
        SecureStorageKeys.providerApiKey('gemini-image'),
        'provider.gemini-image.api_key',
      );
    });

    test('proxyPassword 是固定全局 key', () {
      expect(SecureStorageKeys.proxyPassword, 'network.proxy.password');
    });

    test('不同 providerId 产生不同 key', () {
      final k1 = SecureStorageKeys.providerApiKey('gemini-image');
      final k2 = SecureStorageKeys.providerApiKey('jimeng-image');
      expect(k1, isNot(k2));
    });
  });
}
