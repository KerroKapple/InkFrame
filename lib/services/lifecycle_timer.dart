// LifecycleTimer：启动阶段计时埋点。每个阶段结束落一条 app.lifecycle info
// 日志 {stage, ms}，供性能预算验收（见 docs/perf-baseline.md）。
//
// 为何不用真 Stopwatch：Stopwatch 走单调时钟无法注入/伪造，ms 在单测里不确定。
// 改用注入的 [Clock]（di/clock.dart 同一抽象）取 nowUtc 差值——生产走 SystemClock，
// 单测走 FakeClock，ms 确定性可断言。stage 名与模块名均为英文常量（非用户文案）。
import '../core/logging/logger_service.dart';

/// 启动生命周期埋点日志模块名（ARCHITECTURE §13：启动 / 退出）。
const String kLifecycleModule = 'app.lifecycle';

class LifecycleTimer {
  LifecycleTimer({required LoggerService logger, required Clock clock})
      : _logger = logger,
        _clock = clock;

  final LoggerService _logger;
  final Clock _clock;

  /// 取当前时刻作为区间起点，交给 [record] 结算。
  DateTime now() => _clock.nowUtc();

  /// 结算 [startedAt] → 当前时刻的耗时并落埋点。
  /// 用于无法用闭包包裹的场景（首帧回调 / PG-ready future 结算）。
  void record(String stage, DateTime startedAt) {
    final int ms = _clock.nowUtc().difference(startedAt).inMilliseconds;
    _logger.info(
      kLifecycleModule,
      'stage complete',
      extra: <String, Object?>{'stage': stage, 'ms': ms},
    );
  }

  /// 计时同步阶段：跑 [action]，结束落埋点，返回其结果。
  T timeSync<T>(String stage, T Function() action) {
    final DateTime start = _clock.nowUtc();
    final T result = action();
    record(stage, start);
    return result;
  }

  /// 计时异步阶段：await [action]，结束落埋点，返回其结果。
  Future<T> timeAsync<T>(String stage, Future<T> Function() action) async {
    final DateTime start = _clock.nowUtc();
    final T result = await action();
    record(stage, start);
    return result;
  }
}
