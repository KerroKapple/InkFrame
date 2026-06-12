// CachingProviderRegistry 单元测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../_harness/fake_providers.dart';

void main() {
  group('CachingProviderRegistry', () {
    test('按 id 取 Provider', () {
      final registry = CachingProviderRegistry({
        'fake-a': () =>
            FakeSubmittable(capabilities: fakeImageCapabilities(id: 'fake-a')),
        'fake-b': () =>
            FakeSubmittable(capabilities: fakeImageCapabilities(id: 'fake-b')),
      });
      expect(registry.contains('fake-a'), isTrue);
      expect(registry.get('fake-a').capabilities.providerId, 'fake-a');
      expect(registry.ids, containsAll(<String>['fake-a', 'fake-b']));
    });

    test('未注册 id 抛 ProviderError(invalidParameter)', () {
      final registry =
          CachingProviderRegistry(const <String, ProviderFactory>{});
      expect(
        () => registry.get('nope'),
        throwsA(
          isA<ProviderError>()
              .having((e) => e.code, 'code', InkErrorCode.invalidParameter)
              .having((e) => e.extra['provider_id'], 'provider_id', 'nope'),
        ),
      );
    });

    test('空字符串 id 断言失败', () {
      expect(
        () => CachingProviderRegistry({
          '': () => FakeSubmittable(capabilities: fakeImageCapabilities(id: 'x')),
        }),
        throwsA(isA<AssertionError>()),
      );
    });

    test('同一 id 重复 get() 返回缓存实例，factory 只调用一次', () {
      var calls = 0;
      final registry = CachingProviderRegistry({
        'fake-a': () {
          calls++;
          return FakeSubmittable(
            capabilities: fakeImageCapabilities(id: 'fake-a'),
          );
        },
      });
      final a = registry.get('fake-a');
      final b = registry.get('fake-a');
      expect(
        identical(a, b),
        isTrue,
        reason: '实例必须按 providerId 缓存——Dio / inlineCache 跨调用方一致',
      );
      expect(calls, 1);
    });

    test('listCapabilities 返回所有能力声明且复用缓存实例', () {
      var calls = 0;
      final registry = CachingProviderRegistry({
        'a': () {
          calls++;
          return FakeSubmittable(capabilities: fakeImageCapabilities(id: 'a'));
        },
        'b': () {
          calls++;
          return FakeSubmittable(capabilities: fakeImageCapabilities(id: 'b'));
        },
      });
      final caps = registry.listCapabilities();
      expect(caps, hasLength(2));
      expect(caps.map((c) => c.providerId), containsAll(<String>['a', 'b']));
      registry.listCapabilities();
      expect(calls, 2, reason: 'listCapabilities 不得每次调用重建实例');
    });
  });
}
