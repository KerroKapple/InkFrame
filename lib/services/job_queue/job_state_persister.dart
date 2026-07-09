// JobStatePersister（LB-03 从 JobQueue 抽出）：jobs 表状态跃迁 / 更新 / 失败 /
// 超时 / 取消落库 + 启动孤儿回收。affectedRows(int?) 语义严格保持——0=被抢写 /
// 行不存在，null=未注入 repo（纯内存），orchestrator 据此做 cancel 竞态裁决。
import '../../core/constants/job_housekeeping.dart';
import '../../core/constants/job_statuses.dart';
import '../../core/db/columns.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/batch_result_repository.dart';
import '../../core/interfaces/job_media_persister.dart';
import '../../core/interfaces/job_repository.dart';
import '../../core/interfaces/node_repository.dart';
import '../../core/logging/logger_service.dart';
import '../../core/models/generation_task.dart';
import 'job_queue_util.dart';

/// jobs 表写库漏斗（null repo 时全部 no-op）。批量 slot 收敛委托给 [_media]。
class JobStatePersister {
  JobStatePersister({
    JobRepository? repo,
    BatchResultRepository? batchResults,
    NodeRepository? nodeRepo,
    LoggerService? logger,
    required JobMediaPersister media,
  })  : _repo = repo,
        _batchResults = batchResults,
        _nodeRepo = nodeRepo,
        _logger = logger,
        _media = media;

  final JobRepository? _repo;
  final BatchResultRepository? _batchResults;
  final NodeRepository? _nodeRepo;
  final LoggerService? _logger;
  final JobMediaPersister _media;

  /// 启动初始化：批量把卡在 pending/submitted/polling 的孤儿 job 与仍 generating
  /// 的孤儿 slot 收敛为 cancelled，再跑 jobs 表 housekeeping。未注入 repo 时 no-op。
  Future<void> init() async {
    final repo = _repo;
    if (repo == null) return;
    // ME-02：pending 也在回收范围——建行后未 submit / dispose 前未跑的行
    // 否则永远没有出口。
    const orphanStatuses = [
      JobStatuses.pending,
      JobStatuses.submitted,
      JobStatuses.polling,
    ];
    // 批量回收：一条 UPDATE 把所有遗留 in-flight job 终结为 cancelled，消除 N+1。
    // 启动期无并发，无需 per-row from 守卫。
    final cancelled = await repo.bulkTransition(
      fromStatuses: orphanStatuses,
      toStatus: JobStatuses.cancelled,
      extra: {
        JobCol.errorCode: InkErrorCode.cancelledOnExit.wire,
        JobCol.errorMessage: 'app exited while job was not finished',
        // 回收即终态：与正常终态路径一致补写 completed_at，否则 purgeExpired
        // 的 completed_at < now() - interval 谓词对 NULL 恒假 → 永久逃过 retention。
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (cancelled > 0) {
      _logger?.info(kJobQueueLogModule, 'startup recovery: orphan jobs cancelled',
          extra: {'count': cancelled});
    }
    // 孤儿 slot 同步收敛：启动期无在途 job，任何 generating 态 slot 都已无人推进，
    // 不收敛则批量网格永久转圈。已终态 slot（success/error）不动。
    final batchRepo = _batchResults;
    if (batchRepo != null) {
      final slots = await batchRepo.finalizeAllPending(
        toStatus: SlotStatuses.cancelled,
        errorCode: InkErrorCode.cancelledOnExit.wire,
      );
      if (slots > 0) {
        _logger?.info(
            kJobQueueLogModule, 'startup recovery: orphan batch slots cancelled',
            extra: {'count': slots});
      }
    }
    // ME-32：jobs 表清理在启动时接线（retention + per-canvas cap）。
    // 清理是 housekeeping——失败只放弃本次，绝不阻断启动。
    try {
      await repo.purgeExpired(retention: kJobRetention);
      await repo.purgePerCanvasCap(cap: kJobPerCanvasCap);
    } on LocalIOError {
      // 下次启动重试；orphan 回收已完成，不影响队列可用性。
    }
    // LB-14：孤儿回收之后再收敛崩溃遗留的空 result 壳（软删进回收站，
    // LB-15 可恢复）。同为 housekeeping——失败只 warn，绝不阻断启动。
    final nodeRepo = _nodeRepo;
    if (nodeRepo != null) {
      try {
        final converged = await nodeRepo.softDeleteEmptyOrphanResults();
        if (converged > 0) {
          _logger?.info(kJobQueueLogModule,
              'startup recovery: empty orphan result nodes soft-deleted',
              extra: {'count': converged});
        }
      } on LocalIOError catch (e) {
        _logger?.warn(kJobQueueLogModule,
            'startup convergence of empty orphan result nodes failed',
            extra: {'error_code': e.code.wire});
      }
    }
  }

  /// 返回 affectedRows：0 = 行不存在或 status 不在 from 集合（如已被 cancel 抢写），
  /// null = 未注入 repo（纯内存模式，无行数信息）。调用方据此裁决对外 emit。
  Future<int?> persistTransition(
    String jobId, {
    required List<String> from,
    required String to,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    return repo.transitionStatus(
      id: jobId,
      fromStatuses: from,
      toStatus: to,
      extra: extra,
    );
  }

  Future<void> persistUpdate(String jobId, Map<String, Object?> patch) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.update(jobId, patch);
  }

  Future<int?> persistFailure(
    GenerationTask task,
    InkError error,
    RunningJob running,
  ) async {
    // 所有失败终态的统一漏斗：在此落 ERROR 日志。
    _logger?.error(
      kJobQueueLogModule,
      'job failed',
      extra: {'job_id': task.jobId, 'error_code': error.code.wire},
      cause: error,
    );
    final rows = await persistTransition(
      task.jobId,
      from: const [JobStatuses.pending, JobStatuses.submitted, JobStatuses.polling],
      to: JobStatuses.error,
      extra: {
        JobCol.errorCode: error.code.wire,
        JobCol.errorMessage: truncate(error.toString(), 2000),
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _media.convergeSlotsAfterTerminal(task, rows, running, error);
    return rows;
  }

  Future<int?> persistTimeout(
    GenerationTask task,
    InkError error,
    RunningJob running,
  ) async {
    _logger?.error(
      kJobQueueLogModule,
      'job poll timeout',
      extra: {'job_id': task.jobId, 'error_code': error.code.wire},
    );
    final rows = await persistTransition(
      task.jobId,
      from: const [JobStatuses.submitted, JobStatuses.polling],
      to: JobStatuses.timeout,
      extra: {
        JobCol.errorCode: error.code.wire,
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _media.convergeSlotsAfterTerminal(task, rows, running, error);
    return rows;
  }

  Future<int?> persistCancel(
    String jobId, {
    required List<String> fromStatuses,
  }) {
    return persistTransition(
      jobId,
      from: fromStatuses,
      to: JobStatuses.cancelled,
      extra: {
        JobCol.errorCode: InkErrorCode.cancelledByUser.wire,
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}
