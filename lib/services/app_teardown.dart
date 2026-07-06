// AppTeardown：窗口关闭路径的有序资源回收（CR-02）。
//
// 顺序契约（时序敏感，勿调整）：
//   1) JobQueue.dispose —— 先停调度，避免回收期间新任务写库
//   2) Pool.close —— 关闭 PG 连接池
//   3) PgController.stop —— pg_ctl stop，杜绝孤儿 postmaster
//   4) container.dispose —— 触发其余 provider 的 onDispose（各步均幂等）
//
// 只回收"已实例化"的 provider：关闭路径绝不反向拉起 PG / 队列。
// 对"已挂载但仍在异步初始化中"的 FutureProvider（在途）：等待其 future 完成
// 后再回收。否则 valueOrNull==null 会漏关，且 PgController.stop 可能在 start
// 写 postmaster.pid 之前跑完变 no-op，随后 start 完成 → PG 进程孤儿化。
// 等待由 AppDelegate 的 15s native 超时兜底，不会无限阻塞退出。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/database.dart';
import '../core/di/job_queue.dart';

class AppTeardown {
  Future<void>? _running;

  /// 幂等且并发安全：重复 / 并发调用共享同一次回收 future，所有调用方都等到
  /// 同一次完成。这对 macOS 尤其关键——Cmd+Q 经 applicationShouldTerminate
  /// 触发的回收必须在 native terminate 前真正跑完，且不能与窗口关闭路径双跑。
  Future<void> run(ProviderContainer container) =>
      _running ??= _run(container);

  Future<void> _run(ProviderContainer container) async {
    // 1) JobQueue：已挂载则等其初始化完成（可能在途）再 dispose，避免漏回收在途实例。
    //    初始化失败 → 无实例可收，吞掉异常继续。
    if (_isMounted(container, jobQueueServiceProvider)) {
      try {
        final queue = await container.read(jobQueueServiceProvider.future);
        queue.dispose();
      } on Object {
        // 退出路径尽力而为：初始化失败不阻断后续 PG 回收。
      }
    }

    // 2) Pool：等池建好（= PgController.start 已完成）再 close。
    //    try-catch 保证即使 close 抛错也不跳过下面的 stop（否则 postmaster 孤儿）。
    if (_isMounted(container, pgPoolProvider)) {
      try {
        final pool = await container.read(pgPoolProvider.future);
        await pool.close();
      } on Object {
        // 初始化失败或 close 异常：进程交由 PgController.stop 兜底。
      }
    }

    // 3) PgController.stop：上面已 await pgPool.future → start 必已完成、
    //    postmaster.pid 已写，stop 可靠停掉 postmaster，杜绝 stop/start 竞争孤儿。
    if (_isMounted(container, pgControllerProvider)) {
      try {
        await container.read(pgControllerProvider).stop();
      } on Object {
        // 退出路径尽力而为（对齐步骤 1/2）：任何 stop 失败都不阻断
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
