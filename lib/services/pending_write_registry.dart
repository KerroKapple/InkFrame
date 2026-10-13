// InMemoryPendingWriteRegistry：退出前冲刷挂起写入的注册表实现（BOARD 第 201 行）。
//
// 只做三件事：记下谁有挂起写入、在退出序列被叫到时并发冲一遍、用超时给整件事
// 封顶。它不知道挂起的是什么（prompt？场次标记？），也不该知道——那是
// [PendingWriteFlushable] 实现方的事。
import 'dart:async';

import '../core/interfaces/pending_write_flush.dart';
import '../core/logging/logger_service.dart';

/// 日志 module 名（英文内部常量，不 i18n）。
const String _logModule = 'teardown.flush';

class InMemoryPendingWriteRegistry implements PendingWriteRegistry {
  InMemoryPendingWriteRegistry({
    required LoggerService Function() logger,
    Duration timeout = defaultTimeout,
  })  : _loggerResolver = logger,
        _timeout = timeout;

  /// 整次冲刷的总预算（不是每个对象各一份）。
  ///
  /// 为什么是 2 秒：
  ///   - 本地内嵌 PostgreSQL 的一条 `UPDATE nodes SET type_config = …` 是个位
  ///     毫秒量级，2s 有两个数量级的余量——库健康时**永远**够。
  ///   - 用户刚点了关窗，窗口就该关。2s 还在「关得有点慢」的范围内，不会被当成
  ///     卡死；真正的失败形态是库已经写不进去（池满 / postmaster 失联），那种
  ///     情况下等 10s 和等 2s 结果一样，只是多骗用户 8 秒。
  ///   - 必须远小于 macOS AppDelegate 那道 15s native 超时（见 AppTeardown 头
  ///     注）：冲刷把预算吃掉，后面 Pool.close + pg_ctl stop 就会被 native 强杀，
  ///     换来一个孤儿 postmaster——那比丢一笔草稿严重得多。
  static const Duration defaultTimeout = Duration(seconds: 2);

  /// 懒取 logger（同 FileSecureStorageService 的 `_pathsResolver` 口径）：这张
  /// 注册表在**每个开过检查器的会话**里都会被构造，但只有超时 / 实现方失手才
  /// 需要日志。若在 provider 构造阶段就 `watch(loggerProvider)`，
  /// FileLoggerService（及其底下的 appPathsProvider）就成了「挂载检查器」的硬
  /// 依赖——连纯渲染的检查器 widget 测试都得去接日志目录（实测 50 条红）。
  final LoggerService Function() _loggerResolver;
  final Duration _timeout;

  /// identity 集合：同一对象重复 register 只算一次（Notifier 的 build 可能重跑）。
  final Set<PendingWriteFlushable> _targets = Set<PendingWriteFlushable>.identity();

  @override
  void register(PendingWriteFlushable target) => _targets.add(target);

  @override
  void unregister(PendingWriteFlushable target) => _targets.remove(target);

  @override
  Future<void> flushAll() async {
    // 快路径：绝大多数退出时没有任何挂起内容，不产生日志也不产生 await。
    final List<PendingWriteFlushable> pending =
        _targets.where((t) => t.hasPendingWrites).toList(growable: false);
    if (pending.isEmpty) return;

    final LoggerService logger = _loggerResolver();
    logger.info(_logModule, 'flushing pending writes before shutdown',
        extra: <String, Object?>{'targets': pending.length});

    // 并发冲：各对象之间没有顺序关系，而总预算是固定的——串行会让第 N 个对象
    // 分到的时间取决于前 N-1 个有多慢。
    final Future<void> all = Future.wait(pending.map((t) => _guarded(t, logger)));
    try {
      await all.timeout(_timeout);
    } on TimeoutException {
      // 放弃等待，不放弃退出。已经发出去的 UPDATE 还有一次机会落地：下一步
      // `Pool.close(force: false)` 会等在用连接归还。此处只负责留痕。
      //
      // 刻意不写崩溃文件：退出时丢一笔草稿不是未捕获错误，而写了崩溃文件会让
      // 下一次启动把一次正常退出报成崩溃。日志目录在启动失败页和诊断包里都够得着。
      logger.error(
        _logModule,
        'flush timed out, some pending writes may be lost',
        extra: <String, Object?>{
          'targets': pending.length,
          'still_pending': pending.where((t) => t.hasPendingWrites).length,
          'timeout_ms': _timeout.inMilliseconds,
        },
      );
    }
  }

  /// 单个对象的冲刷不许把别人拖下水。
  ///
  /// 捕获 `on Object`：退出路径，与 `AppTeardown` 各个回收步骤同口径。契约上
  /// [PendingWriteFlushable.flushPendingWrites] 不该抛（实现方自己收 InkError
  /// 并记日志），这一层防的是实现方失手——没有它，一个对象抛出就会让
  /// `Future.wait` 提前结束、把其他对象的挂起写入一起丢掉。
  Future<void> _guarded(PendingWriteFlushable target, LoggerService logger) async {
    try {
      await target.flushPendingWrites();
    } on Object catch (e) {
      logger.error(_logModule, 'flush target threw', cause: e);
    }
  }
}
