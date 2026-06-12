// ProviderRateLimiter：Per-Provider Token Bucket（PRD §10.7.1 / PROVIDER-API.md §7）。
//
// 每个 providerId 独立实例，由 Riverpod keepAlive provider 持有，
// 并在 DI 层经 ref.onDispose 随容器销毁。
// submit() 必须在发 HTTP 前 await acquire()；poll() / cancel() 不过 bucket。

import 'dart:async';

/// Token bucket 实现——撞限阻塞等待，不计入 retry_count。
///
/// 算法：
/// - 桶容量 = [burst]；每 1s 补充 [qps] 个 token
/// - acquire() 立即拿一个 token；不够时等待到能拿为止
/// - 计时基于 Stopwatch 单调时钟——系统墙钟回拨/前跳不影响补充速率
/// - 日志由调用方记录（DEBUG 级），本类只负责节流
class ProviderRateLimiter {
  ProviderRateLimiter({
    required this.qps,
    required this.burst,
    Stopwatch? stopwatch,
  })  : assert(qps > 0, 'qps must be positive'),
        assert(burst > 0, 'burst must be positive'),
        _watch = (stopwatch ?? Stopwatch())..start(),
        _tokens = burst.toDouble();

  final int qps;
  final int burst;

  /// 单调时钟；测试可注入伪 Stopwatch 控制 elapsed。
  final Stopwatch _watch;

  double _tokens;
  int _lastRefillUs = 0;
  bool _disposed = false;
  final _waiters = <Completer<void>>[];

  /// 拿一个 token；不够就阻塞等待。dispose 后调用抛 StateError。
  Future<void> acquire() async {
    if (_disposed) {
      throw StateError('RateLimiter disposed');
    }
    _refill();
    if (_tokens >= 1) {
      _tokens -= 1;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    _scheduleWake();
    return completer.future;
  }

  void _refill() {
    final nowUs = _watch.elapsedMicroseconds;
    final elapsed = (nowUs - _lastRefillUs) / 1e6;
    if (elapsed <= 0) {
      return;
    }
    _tokens = (_tokens + elapsed * qps).clamp(0, burst.toDouble());
    _lastRefillUs = nowUs;
    _drainWaiters();
  }

  void _drainWaiters() {
    while (_tokens >= 1 && _waiters.isNotEmpty) {
      _tokens -= 1;
      _waiters.removeAt(0).complete();
    }
  }

  Timer? _wakeTimer;
  void _scheduleWake() {
    if (_wakeTimer != null) return;
    final needed = 1.0 - _tokens;
    final delayMs = (needed / qps * 1000).ceil().clamp(1, 1000);
    _wakeTimer = Timer(Duration(milliseconds: delayMs), () {
      _wakeTimer = null;
      _refill();
      if (_waiters.isNotEmpty) _scheduleWake();
    });
  }

  /// 由 DI 层 ref.onDispose / 测试调用。幂等。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wakeTimer?.cancel();
    _wakeTimer = null;
    for (final w in _waiters) {
      if (!w.isCompleted) w.completeError(StateError('RateLimiter disposed'));
    }
    _waiters.clear();
  }
}
