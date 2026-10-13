// AppTeardown：窗口关闭路径的有序资源回收（CR-02）。
//
// 顺序契约（时序敏感，勿调整）：
//   1) PendingWriteRegistry.flushAll —— 把「用户已改、还没落盘」的挂起写入冲掉
//   2) JobQueue.dispose —— 停调度，避免回收期间新任务写库
//   3) Pool.close —— 关闭 PG 连接池
//   4) PgController.stop —— pg_ctl stop，杜绝孤儿 postmaster
//   5) container.dispose —— 触发其余 provider 的 onDispose（各步均幂等）
//
// 为什么冲刷排在 JobQueue 之前（BOARD 第 201 行）：两件事都要写库，而预算有限。
// 冲刷写的是**用户亲手敲的内容**（刚打完的最后一个字），JobQueue.dispose 写的是
// 任务取消的行状态——后者本来就有兜底（`init()` 的启动孤儿回收会把它重算出来，
// 见 job_queue_service.dart 的同款注释），前者丢了就真没了。所以把最健康的池子
// 先给用户数据。冲刷自带超时上限，不会把后面几步挤出预算。
//
// 只回收"已实例化"的 provider：关闭路径绝不反向拉起 PG / 队列。
// 对"已挂载但仍在异步初始化中"的 FutureProvider（在途）：等待其 future 完成
// 后再回收。否则 valueOrNull==null 会漏关，且 PgController.stop 可能在 start
// 写 postmaster.pid 之前跑完变 no-op，随后 start 完成 → PG 进程孤儿化。
// 等待由 AppDelegate 的 15s native 超时兜底，不会无限阻塞退出。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/database.dart';
import '../core/di/job_queue.dart';
import '../core/di/pending_writes.dart';
import '../core/di/window_state.dart';

class AppTeardown {
  Future<void>? _running;

  /// 幂等且并发安全：重复 / 并发调用共享同一次回收 future，所有调用方都等到
  /// 同一次完成。这对 macOS 尤其关键——Cmd+Q 经 applicationShouldTerminate
  /// 触发的回收必须在 native terminate 前真正跑完，且不能与窗口关闭路径双跑。
  Future<void> run(ProviderContainer container) =>
      _running ??= _run(container);

  Future<void> _run(ProviderContainer container) async {
    // 0) 记忆窗口尺寸/位置/最大化 —— 窗口此刻仍存活（destroy 在 run 返回后才调）。
    //    尽力而为：服务内部已吞错，此处再兜一层，绝不阻断后续资源回收。
    try {
      await container.read(windowStateServiceProvider).capture();
    } on Object {
      // 记忆窗口状态失败不影响退出回收。
    }

    // 1) 挂起写入：必须在 Pool.close **之前** 冲掉——池一关，内部 semaphore
    //    随即关闭，之后任何 execute 直接抛，补落盘也写不进去。谁有挂起内容由
    //    各 feature 自己注册（PendingWriteFlushable），退出路径只认这一个抽象，
    //    不反向依赖 features。
    //    flushAll 自带超时上限且契约上不抛；外面这层 try 防实现方失手，绝不让
    //    「冲刷没成」挡住后面的 PG 回收。
    if (_isMounted(container, pendingWriteRegistryProvider)) {
      try {
        await container.read(pendingWriteRegistryProvider).flushAll();
      } on Object {
        // 挂起写入冲刷失败不阻断退出回收（注册表内部已记日志）。
      }
    }

    // 2) JobQueue：已挂载则等其初始化完成（可能在途）再 dispose，避免漏回收在途实例。
    //    初始化失败 → 无实例可收，吞掉异常继续。
    if (_isMounted(container, jobQueueServiceProvider)) {
      try {
        final queue = await container.read(jobQueueServiceProvider.future);
        queue.dispose();
      } on Object {
        // 退出路径尽力而为：初始化失败不阻断后续 PG 回收。
      }
    }

    // 3) Pool：等池建好（= PgController.start 已完成）再 close。
    //    try-catch 保证即使 close 抛错也不跳过下面的 stop（否则 postmaster 孤儿）。
    if (_isMounted(container, pgPoolProvider)) {
      try {
        final pool = await container.read(pgPoolProvider.future);
        await pool.close();
      } on Object {
        // 初始化失败或 close 异常：进程交由 PgController.stop 兜底。
      }
    }

    // 4) PgController.stop：上面已 await pgPool.future → start 必已完成、
    //    postmaster.pid 已写，stop 可靠停掉 postmaster，杜绝 stop/start 竞争孤儿。
    if (_isMounted(container, pgControllerProvider)) {
      try {
        await container.read(pgControllerProvider).stop();
      } on Object {
        // 退出路径尽力而为（对齐步骤 1/2/3）：任何 stop 失败都不阻断
        // container.dispose()——下次启动有存活复用 / stale 清理兜底。
      }
    }

    container.dispose();
  }

  /// provider 是否已被实例化——read 未挂载的 provider 会触发创建（启动 PG），
  /// 关闭路径必须先做存在性探测。
  bool _isMounted(ProviderContainer container, ProviderBase<Object?> provider) {
    return container
        .getAllProviderElements()
        .any((element) => element.origin == provider);
  }
}
