// DatabaseRestoreFlow：备份还原编排（LB-22）。
//
// 顺序（设计评审 rev2 拍板 4-7）：
//   确保 PG 服务在跑 → settle 链（loading 必须等出确定态——否则 pg_restore 与
//   在途建池/迁移并发写同库）→ 预备份（设置页失败即中止 / 启动面 best-effort，
//   **查返回值**，backup 服务失败不抛）→ 终结 JobQueue（内存 handle 必达，行状态
//   由重建后 init() 孤儿回收兜底）→ 关池 → scratch 对换还原 → 无条件重建链 →
//   **await 重建成功才算 restored**（toast=「数据可见」）→ 预热 JobQueue。
// flow 级单飞：两个 UI 入口（设置页 / 启动失败面）共享同一在途 future；
// busy 经 app-scoped provider 供 UI 展示（widget 级守卫会随切页归零，评审 P1-2）。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgres/postgres.dart';

import '../../services/database_restore_service.dart';
import '../../storage/pg_controller.dart';
import '../interfaces/database_backup_service.dart';
import '../interfaces/database_restore_service.dart';
import 'clock.dart';
import 'database.dart';
import 'database_backup.dart';
import 'job_queue.dart';
import 'logger.dart';
import 'paths.dart';
import 'process_runner.dart';

/// 还原进行中（UI 禁钮展示位；真守卫在 flow 单飞）。
final databaseRestoreBusyProvider = StateProvider<bool>(
  (ref) => false,
  name: 'databaseRestoreBusyProvider',
);

/// app-scoped：scratch 对换还原服务。
final databaseRestoreServiceProvider = Provider<DatabaseRestoreService>((ref) {
  return PgSwapRestoreService(
    paths: ref.watch(appPathsProvider),
    locator: ref.watch(pgBinaryLocatorProvider),
    runner: ref.watch(processRunnerProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  );
}, name: 'databaseRestoreServiceProvider');

final databaseRestoreFlowProvider = Provider<DatabaseRestoreFlow>(
  (ref) => DatabaseRestoreFlow(ref),
  name: 'databaseRestoreFlowProvider',
);

/// 一次还原的结果：outcome + 预备份文件名（失败提示引用）。
class RestoreFlowResult {
  const RestoreFlowResult({required this.outcome, this.preBackupFileName});

  final RestoreOutcome outcome;
  final String? preBackupFileName;
}

class DatabaseRestoreFlow {
  DatabaseRestoreFlow(this._ref);

  final Ref _ref;

  /// 单飞 memo：在途时的二次 run 共享同一 future（评审 P1-2）。
  Future<RestoreFlowResult>? _inflight;

  Future<RestoreFlowResult> run(
    String backupFileName, {
    required bool requirePreBackup,
  }) {
    return _inflight ??=
        _run(backupFileName, requirePreBackup: requirePreBackup)
            .whenComplete(() => _inflight = null);
  }

  Future<RestoreFlowResult> _run(
    String backupFileName, {
    required bool requirePreBackup,
  }) async {
    final logger = _ref.read(loggerProvider);
    _ref.read(databaseRestoreBusyProvider.notifier).state = true;
    try {
      // 0) 服务器可用（还原需要活的 postgres 服务）。
      final controller = _ref.read(pgControllerProvider);
      final PgRuntime runtime;
      try {
        runtime = controller.runtime ?? await controller.start();
      } on PgLifecycleError catch (e, st) {
        logger.error(kRestoreModule, 'restore.server_unavailable',
            cause: e, stackTrace: st);
        return const RestoreFlowResult(outcome: RestoreOutcome.failed);
      }
      final conn = BackupConnection(
        host: runtime.host,
        port: runtime.port,
        username: kPgSuperuser,
        database: kPgDatabaseName,
        password: runtime.password,
      );

      // settle 链：loading 必须等出确定态（评审生命周期 P1-1——error 态无池可关，
      // loading 态有一个池正在路上，绝不能各走各的）。
      Pool<void>? pool;
      try {
        pool = await _ref.read(pgPoolProvider.future);
      } catch (_) {
        // 链失败态（启动失败面）：无池可关。
        pool = null;
      }

      // 1) 预备份——查返回值（backup 服务失败不抛，评审 P1-4）；
      // preserve=还原目标：兜底备份触发的剪枝绝不能删掉它（#189 评审 P1-2）。
      String? preName;
      final BackupNowResult pre = await _ref
          .read(databaseBackupServiceProvider)
          .backupNow(conn,
              kind: BackupKind.preRestore, preserve: backupFileName);
      preName = pre.fileName;
      if (pre.outcome != BackupOutcome.created) {
        logger.warn(kRestoreModule, 'restore.pre_backup_failed',
            extra: <String, Object?>{'outcome': pre.outcome.name});
        if (requirePreBackup) {
          // 设置页语义：库是健康的，安全网必须真实存在才允许替换数据。
          return const RestoreFlowResult(
              outcome: RestoreOutcome.abortedPreBackup);
        }
        // 启动失败面语义：库已坏，dump 不出来不拦路（best-effort）。
      }

      // 2) 终结 JobQueue（内存 handle 必达；行状态由重建后孤儿回收兜底）。
      _ref.read(jobQueueServiceProvider).valueOrNull?.dispose();
      // 3) 关池（等在途语句收尾）。close 失败也继续——重建链会换新池。
      try {
        if (pool != null) await pool.close();
      } catch (e) {
        logger.warn(kRestoreModule, 'restore.pool_close_failed',
            extra: <String, Object?>{'error': e.toString()});
      }

      // 4) scratch 对换还原。catch-all：池已关，任何逃逸都不得阻断链重建——
      // 否则全 app 写库 StateError 到重启，且失败不可见（#189 评审 P1-1）。
      RestoreOutcome outcome;
      try {
        outcome = await _ref
            .read(databaseRestoreServiceProvider)
            .restore(conn, backupFileName);
      } catch (e, st) {
        // 放行点（sanctioned swallow）：service 已把已知失败收成返回值，
        // 走到这里的是未预期逃逸——记 ERROR 后按 failed 收口。
        logger.error(kRestoreModule, 'restore.unexpected',
            cause: e, stackTrace: st);
        outcome = RestoreOutcome.failed;
      }

      // 5) 无条件重建链（池已关，不重建 app 就死）+ await 出确定态——
      // restored 从此意味着「新库可用、前向迁移已过」（评审 UX P2-1）。
      _ref.invalidate(pgPoolProvider);
      _ref.invalidate(pgMigratedPoolProvider);
      try {
        await _ref.read(pgMigratedPoolProvider.future);
      } catch (e, st) {
        logger.error(kRestoreModule, 'restore.chain_rebuild_failed',
            cause: e, stackTrace: st);
        return RestoreFlowResult(
          outcome: RestoreOutcome.failed,
          preBackupFileName: preName,
        );
      }
      // 6) 预热 JobQueue：孤儿回收立刻跑，画廊不见「进行中」幽灵 job。
      // 预热失败不影响还原结果（下一个消费者 read 时自然重试）。
      unawaited(_ref
          .read(jobQueueServiceProvider.future)
          .then<void>((_) {}, onError: (Object _) {}));
      return RestoreFlowResult(
        outcome: outcome,
        preBackupFileName: preName,
      );
    } finally {
      _ref.read(databaseRestoreBusyProvider.notifier).state = false;
    }
  }
}
