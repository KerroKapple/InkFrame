// ProviderRegistry 单元测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../_harness/fake_providers.dart';

void main() {
  group('ProviderRegistry', () {
    test('按 id 取 Provider', () {
      final registry = ProviderRegistry({
        'fake-a': () =>
            FakeSubmittable(capabilities: fakeImageCapabilities(id: 'fake-a')),
        'fake-b': () =>
            FakeSubmittable(capabilities: fakeImageCapabilities(id: 'fake-b')),
      });
      expect(registry.contains('fake-a'), isTrue);
      expect(registry.get('fake-a').capabilities.providerId, 'fake-a');
      expect(registry.ids, containsAll(<String>['fake-a', 'fake-b']));
    });

    test('未注册 id 抛 ArgumentError', () {
      final registry = ProviderRegistry(const <String, ProviderFactory>{});
      expect(() => registry.get('nope'), throwsA(isA<ArgumentError>()));
    });

    test('空字符串 id 断言失败', () {
      expect(
        () => ProviderRegistry({
          '': () => FakeSubmittable(capabilities: fakeImageCapabilities(id: 'x')),
        }),
        throwsA(isA<AssertionError>()),
      );
    });

    test('listCapabilities 返回所有 Provider 能力声明', () {
      final registry = ProviderRegistry({
        'a': () => FakeSubmittable(capabilities: fakeImageCapabilities(id: 'a')),
        'b': () => FakeSubmittable(capabilities: fakeImageCapabilities(id: 'b')),
      });
      final caps = registry.listCapabilities();
      expect(caps, hasLength(2));
      expect(caps.map((c) => c.providerId), containsAll(<String>['a', 'b']));
    });
  });
}
