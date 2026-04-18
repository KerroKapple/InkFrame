// ProviderRateLimiter：Per-Provider Token Bucket（PRD §10.7.1 / PROVIDER-API.md §7）。
//
// 每个 providerId 独立实例，由 Riverpod keepAlive provider 持有。
// submit() 必须在发 HTTP 前 await acquire()；poll() / cancel() 不过 bucket。

import 'dart:async';

/// Token bucket 实现——撞限阻塞等待，不计入 retry_count。
///
/// 算法：
/// - 桶容量 = [burst]；每 1s 补充 [qps] 个 token
/// - acquire() 立即拿一个 token；不够时等待到能拿为止
/// - 日志由调用方记录（DEBUG 级），本类只负责节流
class ProviderRateLimiter {
  ProviderRateLimiter({
    required this.qps,
    required this.burst,
    DateTime Function()? clock,
  })  : assert(qps > 0, 'qps must be positive'),
        assert(burst > 0, 'burst must be positive'),
        _clock = clock ?? DateTime.now,
        _tokens = burst.toDouble(),
        _lastRefill = (clock ?? DateTime.now)();

  final int qps;
  final int burst;
  final DateTime Function() _clock;

  double _tokens;
  DateTime _lastRefill;
  final _waiters = <Completer<void>>[];

  /// 拿一个 token；不够就阻塞等待。
  Future<void> acquire() async {
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
    final now = _clock();
    final elapsed = now.difference(_lastRefill).inMicroseconds / 1e6;
    if (elapsed <= 0) {
      return;
    }
    _tokens = (_tokens + elapsed * qps).clamp(0, burst.toDouble());
    _lastRefill = now;
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

  /// 测试/关闭时调用。
  void dispose() {
    _wakeTimer?.cancel();
    for (final w in _waiters) {
      if (!w.isCompleted) w.completeError(StateError('RateLimiter disposed'));
    }
    _waiters.clear();
  }
}
