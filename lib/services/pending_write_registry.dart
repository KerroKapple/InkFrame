// InMemoryPendingWriteRegistry：冲刷挂起写入的注册表实现（BOARD 第 201 行）。
//
// 只做三件事：记下谁有挂起写入、被叫到时并发冲一遍、用超时给整件事封顶。它不知道
// 挂起的是什么（prompt？场次标记？），也不该知道——那是 [PendingWriteFlushable]
// 实现方的事。
//
// 两个口（#12）：[flushAll] 只给退出序列，[flushBeforeEdit] 给撤销 / 重做。两者
// 「问一圈、并发冲、超时封顶」的骨架相同，不同的只有：叫目标的哪个口、日志 module
// 与措辞、超时记几级——编辑口的超时不丢数据（app 还在跑，目标自己会接着重试），
// 记 warn；退出口的超时可能真丢一笔，记 error。
import 'dart:async';

import '../core/interfaces/pending_write_flush.dart';
import '../core/logging/logger_service.dart';

/// 退出口的日志 module 名（英文内部常量，不 i18n）。
const String _exitLogModule = 'teardown.flush';

/// 编辑口（撤销 / 重做之前）的日志 module 名。
const String _editLogModule = 'pending_writes.flush';

class InMemoryPendingWriteRegistry implements PendingWriteRegistry {
  InMemoryPendingWriteRegistry({
    required LoggerService Function() logger,
    Duration timeout = defaultTimeout,
  })  : _loggerResolver = logger,
        _timeout = timeout;

  /// 整次冲刷的总预算（不是每个对象各一份）。两个口共用这一份。
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
  Future<void> flushAll() => _flush(
        module: _exitLogModule,
        startMessage: 'flushing pending writes before shutdown',
        flushOne: (PendingWriteFlushable t) => t.flushPendingWrites(),
        // 放弃等待，不放弃退出。已经发出去的 UPDATE 还有一次机会落地：下一步
        // `Pool.close(force: false)` 会等在用连接归还。此处只负责留痕。
        //
        // 刻意不写崩溃文件：退出时丢一笔草稿不是未捕获错误，而写了崩溃文件会让
        // 下一次启动把一次正常退出报成崩溃。日志目录在启动失败页和诊断包里都够得着。
        onTimeout: (LoggerService logger, Map<String, Object?> extra) =>
            logger.error(
          _exitLogModule,
          'flush timed out, some pending writes may be lost',
          extra: extra,
        ),
      );

  @override
  Future<void> flushBeforeEdit() => _flush(
        module: _editLogModule,
        startMessage: 'flushing pending writes',
        flushOne: (PendingWriteFlushable t) => t.flushBeforeEdit(),
        // 编辑口超时不丢东西：app 还在跑，没写完的那一笔仍在目标的挂起表 / 重试表里，
        // 由目标自己接着落盘。撤销只是不再等它——记 warn 留痕即可。
        onTimeout: (LoggerService logger, Map<String, Object?> extra) =>
            logger.warn(
          _editLogModule,
          'flush timed out, continuing without waiting',
          extra: extra,
        ),
      );

  /// 两个口共用的骨架：问一圈谁有挂起内容 → 并发冲 → 超时封顶。
  Future<void> _flush({
    required String module,
    required String startMessage,
    required Future<void> Function(PendingWriteFlushable target) flushOne,
    required void Function(LoggerService logger, Map<String, Object?> extra)
        onTimeout,
  }) async {
    // 快路径：绝大多数时候没有任何挂起内容，不产生日志也不产生 await。
    final List<PendingWriteFlushable> pending =
        _targets.where((t) => t.hasPendingWrites).toList(growable: false);
    if (pending.isEmpty) return;

    final LoggerService logger = _loggerResolver();
    logger.info(module, startMessage,
        extra: <String, Object?>{'targets': pending.length});

    // 并发冲：各对象之间没有顺序关系，而总预算是固定的——串行会让第 N 个对象
    // 分到的时间取决于前 N-1 个有多慢。
    final Future<void> all = Future.wait(
      pending.map((t) => _guarded(() => flushOne(t), logger, module)),
    );
    try {
      await all.timeout(_timeout);
    } on TimeoutException {
      onTimeout(logger, <String, Object?>{
        'targets': pending.length,
        'still_pending': pending.where((t) => t.hasPendingWrites).length,
        'timeout_ms': _timeout.inMilliseconds,
      });
    }
  }

  /// 单个对象的冲刷不许把别人拖下水。
  ///
  /// 捕获 `on Object`：退出路径，与 `AppTeardown` 各个回收步骤同口径。契约上
  /// 两个冲刷口都不该抛（实现方自己收 InkError 并记日志），这一层防的是实现方
  /// 失手——没有它，一个对象抛出就会让 `Future.wait` 提前结束、把其他对象的挂起
  /// 写入一起丢掉。
  Future<void> _guarded(
    Future<void> Function() flush,
    LoggerService logger,
    String module,
  ) async {
    try {
      await flush();
    } on Object catch (e) {
      logger.error(module, 'flush target threw', cause: e);
    }
  }
}
