// ProviderRateLimiter 单元测试：token bucket 节流行为。
// 全部计时断言走 fake_async 虚拟时钟——零墙钟依赖，零 flaky。
// limiter 注入 package:clock 的 clock.now，fakeAsync 区内自动接管。

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/providers/rate_limiter.dart';

ProviderRateLimiter _build({required int qps, required int burst}) =>
    ProviderRateLimiter(qps: qps, burst: burst, clock: () => clock.now());

void main() {
  group('ProviderRateLimiter', () {
    test('初始桶已满：burst 内连续 acquire 立即返回（零虚拟时间）', () {
      fakeAsync((async) {
        final rl = _build(qps: 2, burst: 5);
        var completed = 0;
        for (var i = 0; i < 5; i++) {
          rl.acquire().then((_) => completed++);
        }
        async.flushMicrotasks();
        expect(completed, 5, reason: 'burst 内不应消耗任何虚拟时间');
        expect(async.elapsed, Duration.zero);
        rl.dispose();
      });
    });

    test('超过 burst 后需等待补 token：100ms 前挂起，100ms 后放行', () {
      fakeAsync((async) {
        final rl = _build(qps: 10, burst: 2);
        var third = false;
        rl.acquire();
        rl.acquire();
        rl.acquire().then((_) => third = true);
        async.flushMicrotasks();
        expect(third, isFalse, reason: '桶空，第三个必须挂起');

        async.elapse(const Duration(milliseconds: 99));
        expect(third, isFalse, reason: '不足 1/qps=100ms，仍应挂起');

        async.elapse(const Duration(milliseconds: 2));
        expect(third, isTrue, reason: '过 100ms 应补到 1 个 token');
        rl.dispose();
      });
    });

    test('并发 acquire 按顺序拿到 token', () {
      fakeAsync((async) {
        final rl = _build(qps: 20, burst: 1);
        final order = <int>[];
        for (var i = 0; i < 5; i++) {
          rl.acquire().then((_) => order.add(i));
        }
        async.elapse(const Duration(seconds: 1));
        expect(order, <int>[0, 1, 2, 3, 4]);
        rl.dispose();
      });
    });

    test('dispose 后未完成的 acquire 报错退出', () {
      fakeAsync((async) {
        final rl = _build(qps: 1, burst: 1);
        rl.acquire(); // 消耗唯一 token
        Object? error;
        rl.acquire().catchError((Object e) {
          error = e;
          return null;
        });
        async.flushMicrotasks();
        rl.dispose();
        async.flushMicrotasks();
        expect(error, isA<StateError>());
      });
    });

    test('非法构造参数', () {
      expect(
        () => ProviderRateLimiter(qps: 0, burst: 1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ProviderRateLimiter(qps: 1, burst: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('refill 严格按 QPS 速率补充：qps=5 → 200ms 一个', () {
      fakeAsync((async) {
        final rl = _build(qps: 5, burst: 1);
        var second = false;
        rl.acquire(); // 消耗唯一 token
        rl.acquire().then((_) => second = true);
        async.elapse(const Duration(milliseconds: 199));
        expect(second, isFalse, reason: '1/5s=200ms 之前不应放行');
        async.elapse(const Duration(milliseconds: 2));
        expect(second, isTrue);
        rl.dispose();
      });
    });

    test('token 不超过 burst 上限：长时间空闲后仍只放 burst 个', () {
      fakeAsync((async) {
        final rl = _build(qps: 10, burst: 2);
        async.elapse(const Duration(seconds: 60)); // 空闲很久
        var immediate = 0;
        for (var i = 0; i < 3; i++) {
          rl.acquire().then((_) => immediate++);
        }
        async.flushMicrotasks();
        expect(immediate, 2, reason: '桶容量 = burst，空闲不积累超额 token');
        rl.dispose();
      });
    });
  });
}
