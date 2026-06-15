// AppTeardown：窗口关闭路径的有序资源回收（CR-02）。
//
// 顺序契约（时序敏感，勿调整）：
//   1) JobQueue.dispose —— 先停调度，避免回收期间新任务写库
//   2) Pool.close —— 关闭 PG 连接池
//   3) PgController.stop —— pg_ctl stop，杜绝孤儿 postmaster
//   4) container.dispose —— 触发其余 provider 的 onDispose（各步均幂等）
//
// 只回收"已实例化"的 provider：关闭路径绝不反向拉起 PG / 队列。
// JobQueue / Pool 仍在异步初始化中（valueOrNull == null）时跳过显式
// 回收——第 3 步的 pg_ctl stop -m fast 会兜底断开半建连接。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/database.dart';
import '../core/di/job_queue.dart';
import '../storage/pg_controller.dart';

class AppTeardown {
  Future<void>? _running;

  /// 幂等且并发安全：重复 / 并发调用共享同一次回收 future，所有调用方都等到
  /// 同一次完成。这对 macOS 尤其关键——Cmd+Q 经 applicationShouldTerminate
  /// 触发的回收必须在 native terminate 前真正跑完，且不能与窗口关闭路径双跑。
  Future<void> run(ProviderContainer container) =>
      _running ??= _run(container);

  Future<void> _run(ProviderContainer container) async {
    if (_isMounted(container, jobQueueServiceProvider)) {
      container.read(jobQueueServiceProvider).valueOrNull?.dispose();
    }

    if (_isMounted(container, pgPoolProvider)) {
      final pool = container.read(pgPoolProvider).valueOrNull;
      if (pool != null) {
        await pool.close();
      }
    }

    if (_isMounted(container, pgControllerProvider)) {
      try {
        await container.read(pgControllerProvider).stop();
      } on PgLifecycleError {
        // 退出路径上的失败不再扩散——下次启动有存活复用 / stale 清理兜底。
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
