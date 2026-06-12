// ProviderRateLimiter 单元测试：验证 token bucket 节流行为。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/providers/rate_limiter.dart';

/// 可手动推进的伪单调时钟。
class _FakeStopwatch extends Stopwatch {
  int us = 0;

  @override
  int get elapsedMicroseconds => us;
}

void main() {
  group('ProviderRateLimiter', () {
    test('初始桶已满：burst 内连续 acquire 立即返回', () async {
      final rl = ProviderRateLimiter(qps: 2, burst: 5);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await rl.acquire();
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100));
      rl.dispose();
    });

    test('超过 burst 后需要等待补充 token', () async {
      final rl = ProviderRateLimiter(qps: 10, burst: 2);
      final sw = Stopwatch()..start();
      await rl.acquire();
      await rl.acquire();
      await rl.acquire(); // 需要等 ~100ms 补一个
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThan(50));
      rl.dispose();
    });

    test('并发 acquire 按顺序拿到 token', () async {
      final rl = ProviderRateLimiter(qps: 20, burst: 1);
      final order = <int>[];
      final futures = List.generate(5, (i) async {
        await rl.acquire();
        order.add(i);
      });
      await Future.wait(futures);
      expect(order, <int>[0, 1, 2, 3, 4]);
      rl.dispose();
    });

    test('dispose 后未完成的 acquire 报错退出', () async {
      final rl = ProviderRateLimiter(qps: 1, burst: 1);
      await rl.acquire(); // 消耗唯一 token
      final pending = rl.acquire();
      rl.dispose();
      await expectLater(pending, throwsA(isA<StateError>()));
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

    test('refill 按 QPS 速率补充', () async {
      final rl = ProviderRateLimiter(qps: 5, burst: 1);
      await rl.acquire(); // 消耗唯一 token
      final sw = Stopwatch()..start();
      await rl.acquire(); // 应等 ~200ms (1/5 s)
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThan(150));
      expect(sw.elapsedMilliseconds, lessThan(500));
      rl.dispose();
    });

    test('补充节奏跟随单调时钟（Stopwatch），与系统墙钟无关', () async {
      final watch = _FakeStopwatch();
      final rl = ProviderRateLimiter(qps: 10, burst: 1, stopwatch: watch);
      await rl.acquire(); // 桶空

      // 时钟不前进：token 不补充，下一次 acquire 必须挂起
      final pending = rl.acquire();
      var done = false;
      unawaited(pending.then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      // 推进伪时钟 0.1s（qps=10 → 恰好补一个 token），唤醒定时器
      // 触发 refill 后等待者被唤醒。
      watch.us = 100000;
      await pending;
      rl.dispose();
    });

    test('dispose 幂等；dispose 后 acquire 抛 StateError', () async {
      final rl = ProviderRateLimiter(qps: 1, burst: 1);
      rl.dispose();
      rl.dispose(); // 不抛
      await expectLater(rl.acquire(), throwsA(isA<StateError>()));
    });
  });
}
