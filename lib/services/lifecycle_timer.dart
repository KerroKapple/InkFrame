// LifecycleTimer：启动阶段计时埋点。每个阶段结束落一条 app.lifecycle info
// 日志 {stage, ms}，供性能预算验收（见 docs/perf-baseline.md）。
//
// 计时走注入的单调 [ElapsedSource]：生产 StopwatchElapsed 基于 Stopwatch 单调时钟，
// 单测 FakeElapsed 手动推进。单调源既可注入/伪造（ms 确定性可断言），又免受启动期
// 墙钟跳变（NTP 校正 / 手动改表）污染——冷启 pg_ready（含 initdb，紧随开机、首次
// NTP 校正易落此窗口）是唯一的冷启基线样本，尤其不能被时钟阶跃写成负数/虚高。
// stage 名与模块名均为英文常量（非用户文案）。
import '../core/logging/logger_service.dart';

/// 启动生命周期埋点日志模块名（ARCHITECTURE §13：启动 / 退出）。
const String kLifecycleModule = 'app.lifecycle';

/// 单调流逝时间源——可注入/可伪造，且免受墙钟跳变影响。
abstract class ElapsedSource {
  /// 自源起表以来的单调累计流逝。
  Duration get elapsed;
}

/// 生产实现：构造即 start 一个 Stopwatch（进程起点起表），读单调流逝。
class StopwatchElapsed implements ElapsedSource {
  final Stopwatch _sw = Stopwatch()..start();

  @override
  Duration get elapsed => _sw.elapsed;
}

class LifecycleTimer {
  LifecycleTimer({
    required LoggerService logger,
    required ElapsedSource elapsed,
  })  : _logger = logger,
        _elapsed = elapsed;

  final LoggerService _logger;
  final ElapsedSource _elapsed;

  /// 取当前累计流逝作为区间起点，交给 [record] 结算。
  Duration mark() => _elapsed.elapsed;

  /// 结算 [start] → 当前流逝的耗时并落埋点。
  /// 用于无法用闭包包裹的场景（首帧回调 / PG-ready future 结算）。
  void record(String stage, Duration start) {
    final int ms = (_elapsed.elapsed - start).inMilliseconds;
    _logger.info(
      kLifecycleModule,
      'stage complete',
      extra: <String, Object?>{'stage': stage, 'ms': ms},
    );
  }

  /// 计时同步阶段：跑 [action]，无论成功或抛错都落埋点（finally 保证阶段耗时不丢），
  /// 异常照常向上传播（bootstrap 失败路径不变）。
  T timeSync<T>(String stage, T Function() action) {
    final Duration start = _elapsed.elapsed;
    try {
      return action();
    } finally {
      record(stage, start);
    }
  }

  /// 计时异步阶段：await [action]，无论成功或抛错都落埋点（finally），
  /// 异常照常向上传播。
  Future<T> timeAsync<T>(String stage, Future<T> Function() action) async {
    final Duration start = _elapsed.elapsed;
    try {
      return await action();
    } finally {
      record(stage, start);
    }
  }
}
