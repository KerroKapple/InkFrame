import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';

class _FakeStorage implements SecureStorageService {
  _FakeStorage({this.present = const <String>{}, this.throwOn});

  final Set<String> present;
  final String? throwOn;

  @override
  Future<bool> exists(String key) async {
    if (key == throwOn) throw StateError('boom');
    return present.contains(key);
  }

  @override
  Future<String?> retrieve(String key) async => null;

  @override
  Future<void> store(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

void main() {
  test('anyProviderKeyConfiguredProvider 无任何 key 返回 false', () async {
    final container = ProviderContainer(overrides: <Override>[
      secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
    ]);
    addTearDown(container.dispose);

    final unlocked = await container.read(anyProviderKeyConfiguredProvider.future);
    expect(unlocked, isFalse);
  });

  test('anyProviderKeyConfiguredProvider 任意 provider key 存在即解锁', () async {
    final container = ProviderContainer(overrides: <Override>[
      secureStorageServiceProvider.overrideWithValue(_FakeStorage(
        present: <String>{SecureStorageKeys.providerApiKey('gemini-image')},
      )),
    ]);
    addTearDown(container.dispose);

    final unlocked = await container.read(anyProviderKeyConfiguredProvider.future);
    expect(unlocked, isTrue);
  });

  test('anyProviderKeyConfiguredProvider 吃掉 exists 抛错，继续看后续 provider', () async {
    final container = ProviderContainer(overrides: <Override>[
      secureStorageServiceProvider.overrideWithValue(_FakeStorage(
        throwOn: SecureStorageKeys.providerApiKey('gemini-image'),
        present: <String>{SecureStorageKeys.providerApiKey('wanx-image')},
      )),
    ]);
    addTearDown(container.dispose);

    final unlocked = await container.read(anyProviderKeyConfiguredProvider.future);
    expect(unlocked, isTrue);
  });
}
