// JobQueueService 内存实现（PRD §10.7）。
//
// b1 ✅ 内存调度 + Provider 集成
// b2 ✅ JobRepository 持久化 + 启动恢复
// b3 ✅ FileResolverService 落盘集成（inlineBytes）
// b3.1 ✅ remoteUrls HTTP 下载（T5-S3；重试 / 续传未实现）
// b4 ⏳ 性能档位 → globalConcurrency 联动

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import '../core/constants/job_housekeeping.dart';
import '../core/constants/job_statuses.dart';
import '../core/db/columns.dart';
import '../core/errors/ink_error.dart';
import '../core/interfaces/batch_result_repository.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/logging/logger_service.dart';
import '../core/interfaces/job_queue_service.dart';
import '../core/interfaces/job_repository.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/thumbnail_service.dart';
import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/video_download_service.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/provider_capabilities.dart';
import '../core/interfaces/provider_registry.dart';

// 数据结构：
//   _pending      = Queue<_PendingJob>，保持 FIFO；只追加 / 队头出队
//   _pendingIndex = Map<jobId, _PendingJob>，cancel 用 O(1) 定位
//   cancel pending = pendingIndex.remove + 标记 cancelled；queue 不重建
//   dispatch loop  = 跳过 cancelled 条目并顺手出队（摊还 O(1)）
//   FIFO / retry / status 机 契约外部不变。
class InMemoryJobQueueService implements JobQueueService {
  InMemoryJobQueueService({
    required ProviderRegistry registry,
    JobRepository? repo,
    FileResolverService? fileResolver,
    NodeRepository? nodeRepo,
    BatchResultRepository? batchResultRepo,
    VideoDownloadService? videoDownloader,
    ThumbnailService? thumbnailService,
    LoggerService? logger,
    int globalConcurrency = 2,
    Duration pollInitialInterval = const Duration(seconds: 3),
    Duration pollMaxInterval = const Duration(seconds: 30),
    double pollBackoffMultiplier = 2.0,
    Duration pollTimeout = const Duration(minutes: 30),
    Random? random,
  })  : _registry = registry,
        _repo = repo,
        _fileResolver = fileResolver,
        _nodeRepo = nodeRepo,
        _batchResults = batchResultRepo,
        _videoDownloader = videoDownloader,
        _thumbnail = thumbnailService,
        _logger = logger,
        _globalConcurrency = globalConcurrency,
        _pollInitial = pollInitialInterval,
        _pollMax = pollMaxInterval,
        _pollMultiplier = pollBackoffMultiplier,
        _pollTimeout = pollTimeout,
        _random = random ?? Random();

  final ProviderRegistry _registry;
  final JobRepository? _repo;
  final FileResolverService? _fileResolver;
  final NodeRepository? _nodeRepo;
  final BatchResultRepository? _batchResults;
  final VideoDownloadService? _videoDownloader;
  final ThumbnailService? _thumbnail;
  final LoggerService? _logger;
  final int _globalConcurrency;

  static const String _logModule = 'jobqueue';
  final Duration _pollInitial;
  final Duration _pollMax;
  final double _pollMultiplier;
  final Duration _pollTimeout;
  final Random _random;

  final Queue<_PendingJob> _pending = Queue<_PendingJob>();
  // 与 _pending 一一对应的索引；jobId → 同一个 _PendingJob 引用。
  // cancel(jobId) 用它做 O(1) 定位 + 移除，避免把 queue 拆成 List 重建。
  final Map<String, _PendingJob> _pendingIndex = <String, _PendingJob>{};
  final Map<String, _RunningJob> _running = <String, _RunningJob>{};
  final Map<String, int> _perProviderSlots = <String, int>{};
  bool _disposed = false;

  @override
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
      },
    );
    if (cancelled > 0) {
      _logger?.info(_logModule, 'startup recovery: orphan jobs cancelled',
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
            _logModule, 'startup recovery: orphan batch slots cancelled',
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
  }

  @override
  Future<JobHandle> submit(GenerationTask task) async {
    _ensureNotDisposed();
    if (_pendingIndex.containsKey(task.jobId) ||
        _running.containsKey(task.jobId)) {
      throw StateError('jobId ${task.jobId} already submitted');
    }
    // ignore: close_sinks  // 终态由 _Handle._complete 关闭
    final controller = StreamController<JobStatus>.broadcast();
    final doneCompleter = Completer<JobStatus>();
    final handle = _Handle(task.jobId, controller, doneCompleter);

    _logger?.debug(_logModule, 'job queued', extra: {
      'job_id': task.jobId,
      'provider_id': task.providerId,
    });
    final pendingJob = _PendingJob(task: task, handle: handle);
    _pending.add(pendingJob);
    _pendingIndex[task.jobId] = pendingJob;
    _schedule();
    return handle;
  }

  @override
  Future<void> cancel(String jobId) async {
    final pending = _pendingIndex.remove(jobId);
    if (pending != null) {
      // 软删除：标记后 dispatch loop 自然跳过并出队，避免重建 Queue。
      pending.cancelled = true;
      await _persistCancel(jobId, fromStatuses: const [JobStatuses.pending]);
      // 排队期取消：预建的 slot 占位行同步收敛（仅批量 job 有 slot 行）。
      if (pending.task.batchSize > 1) {
        await _convergeSlots(
          jobId,
          toStatus: SlotStatuses.cancelled,
          errorCode: InkErrorCode.cancelledByUser.wire,
        );
      }
      _emitFailure(pending.handle, _cancelledError(jobId));
      return;
    }
    final running = _running[jobId];
    if (running == null) return; // idempotent
    running.cancelled = true;
    await _persistCancel(jobId,
        fromStatuses: const [JobStatuses.submitted, JobStatuses.polling]);
    running.wake(); // ME-01：中断退避睡眠，让 _pollLoop 立即收敛到 cancelled
    final provider = running.provider;
    if (provider is Cancellable) {
      try {
        await (provider as Cancellable).cancel(running.providerJobId ?? jobId);
      } on InkError catch (e) {
        // 按 PROVIDER-API §5.4：cancel 失败不抛——但必须留日志痕迹。
        _logger?.warn(_logModule, 'provider cancel failed (swallowed)',
            extra: {'job_id': jobId, 'error_code': e.code.wire});
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final p in _pending) {
      if (p.cancelled) continue; // 已 cancel 的事件已发过
      // dispose 是同步接口，持久化只能 fire-and-forget；init() 的 pending 回收兜底。
      unawaited(
          _persistCancel(p.task.jobId, fromStatuses: const [JobStatuses.pending]));
      _emitFailure(p.handle, _cancelledError(p.task.jobId));
    }
    _pending.clear();
    _pendingIndex.clear();
    for (final entry in _running.entries) {
      final running = entry.value;
      running.cancelled = true;
      running.wake();
      // ME-01：立即终结 handle，不等 _pollLoop 推进到下个检查点
      // （可能正挂在 provider.poll 上）。行状态由 init() 的 orphan 回收兜底。
      _emitFailure(running.handle, _cancelledError(entry.key));
    }
  }

  // ---- 调度 ---------------------------------------------------------------

  void _schedule() {
    if (_disposed) return;
    // 把队头的 cancelled 条目顺手清掉；摊还 O(1)。
    while (_pending.isNotEmpty && _pending.first.cancelled) {
      _pending.removeFirst();
    }
    while (_pending.isNotEmpty &&
        _running.length < _globalConcurrency) {
      final next = _pickNextSchedulable();
      if (next == null) return; // 所有 pending 都被 per-provider 限流卡住
      _pending.remove(next);
      _pendingIndex.remove(next.task.jobId);
      _occupy(next.task.providerId);
      _runJob(next.task, next.handle);
    }
  }

  _PendingJob? _pickNextSchedulable() {
    for (final p in _pending) {
      if (p.cancelled) continue;
      final cap = _perProviderCap(p.task.providerId);
      final used = _perProviderSlots[p.task.providerId] ?? 0;
      if (used < cap) return p;
    }
    return null;
  }

  int _perProviderCap(String providerId) {
    final provider = _registry.get(providerId);
    return provider.capabilities.maxConcurrentJobs;
  }

  void _occupy(String providerId) {
    _perProviderSlots[providerId] = (_perProviderSlots[providerId] ?? 0) + 1;
  }

  void _release(String providerId) {
    final cur = _perProviderSlots[providerId] ?? 0;
    if (cur <= 1) {
      _perProviderSlots.remove(providerId);
    } else {
      _perProviderSlots[providerId] = cur - 1;
    }
  }

  // ---- 单任务生命周期 -----------------------------------------------------

  Future<void> _runJob(GenerationTask task, _Handle handle) async {
    final provider = _registry.get(task.providerId);
    final running = _RunningJob(provider: provider, handle: handle);
    _running[task.jobId] = running;

    try {
      // pending → submitted（写 submitted_at）
      await _persistTransition(
        task.jobId,
        from: const [JobStatuses.pending],
        to: JobStatuses.submitted,
        extra: {JobCol.submittedAt: DateTime.now().toUtc().toIso8601String()},
      );

      final providerJobId = await provider.submit(task);
      running.providerJobId = providerJobId;
      await _persistUpdate(task.jobId, {JobCol.remoteTaskId: providerJobId});

      if (provider is! Pollable) {
        // 仅 Submittable 的 Provider 在 P0 还没有——按契约 supportsPolling 必须实现
        // Pollable（包括同步 Provider，见 ADR-0004）。这里防御性失败。
        throw ProviderError(
          code: InkErrorCode.providerServer,
          extra: {
            'provider_id': provider.capabilities.providerId,
            'reason': 'provider_not_pollable',
          },
        );
      }
      await _pollLoop(provider as Pollable, providerJobId, task, handle, running);
    } on InkError catch (e) {
      final rows = await _persistFailure(task, e, running);
      _emitFailure(handle, _arbitrate(rows, running, e, task.jobId));
    } catch (e, st) {
      // HI-01 兜底：非 InkError（provider bug / 库异常）逃逸会让 handle 永挂。
      // 队列边界统一翻译成 UnknownError，保证 handle 一定终结。
      final err = UnknownError(
        cause: e,
        stackTrace: st,
        extra: {'job_id': task.jobId},
      );
      await _persistFailure(task, err, running);
      _emitFailure(handle, err);
    } finally {
      _running.remove(task.jobId);
      _release(task.providerId);
      _schedule();
    }
  }

  Future<void> _pollLoop(
    Pollable provider,
    String providerJobId,
    GenerationTask task,
    _Handle handle,
    _RunningJob running,
  ) async {
    final deadline = DateTime.now().add(_pollTimeout);
    var interval = _pollInitial;
    var enteredPolling = false;

    // 退避 + jitter；可中断（cancel/dispose wake 后立即返回）。
    Future<void> backoff() {
      final jitter = 1.0 + (_random.nextDouble() - 0.5) * 0.4; // ±20%
      final nextMs =
          (interval.inMilliseconds * _pollMultiplier * jitter).round();
      interval =
          Duration(milliseconds: nextMs.clamp(0, _pollMax.inMilliseconds));
      return _sleepInterruptible(running, interval);
    }

    // cancel 收敛：幂等补写 cancelled（cancel 主路径已写过则 0 行），persist 先于 emit。
    // slot 收敛（已成功 slot 保留，仍 generating 的置 cancelled）与 job 行同步。
    Future<void> emitCancelled() async {
      await _persistCancel(
        task.jobId,
        fromStatuses: const [JobStatuses.submitted, JobStatuses.polling],
      );
      if (task.batchSize > 1) {
        await _convergeSlots(
          task.jobId,
          toStatus: SlotStatuses.cancelled,
          errorCode: InkErrorCode.cancelledByUser.wire,
        );
      }
      _emitFailure(handle, _cancelledError(task.jobId));
    }

    while (true) {
      if (running.cancelled) {
        await emitCancelled();
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        final timeoutErr = ProviderError(
          code: InkErrorCode.pollTimeout,
          extra: {'provider_id': task.providerId, 'job_id': task.jobId},
        );
        final rows = await _persistTimeout(task, timeoutErr, running);
        _emitFailure(handle, _arbitrate(rows, running, timeoutErr, task.jobId));
        return;
      }

      final JobStatus status;
      try {
        status = await provider.poll(providerJobId);
      } on InkError catch (e) {
        if (!e.retryable) rethrow; // 不可重试 → _runJob 统一落 error
        // ME-04：瞬时错误（网络抖动 / 5xx / busy）退避重试，pollTimeout deadline 兜底
        await backoff();
        continue;
      }
      switch (status) {
        case JobInProgress(:final progress):
          if (!enteredPolling) {
            await _persistTransition(
              task.jobId,
              from: const [JobStatuses.submitted],
              to: JobStatuses.polling,
              extra: {JobCol.progress: progress},
            );
            enteredPolling = true;
          } else {
            await _persistUpdate(task.jobId, {JobCol.progress: progress});
          }
          handle._emit(status);
        case JobSuccess(:final inlineBytes, :final remoteUrls):
          // HI-02：cancel 已落库则不再做落盘/下载，直接收敛 cancelled。
          if (running.cancelled) {
            await emitCancelled();
            return;
          }
          final hasInline = inlineBytes != null && inlineBytes.isNotEmpty;
          // 批量零产出：provider 报 success 但两路产物皆空 → 按失败收敛，
          // 否则 job 落 success 而 N 个 slot 永挂 generating。
          if (task.batchSize > 1 && !hasInline && remoteUrls.isEmpty) {
            final err = ProviderError(
              code: InkErrorCode.providerInvalidResponse,
              extra: {
                'provider_id': task.providerId,
                'job_id': task.jobId,
                'reason': 'batch_zero_outputs',
              },
            );
            final rows = await _persistFailure(task, err, running);
            _emitFailure(handle, _arbitrate(rows, running, err, task.jobId));
            return;
          }
          // b3：inlineBytes 落盘到 {canvasRoot}/images/{jobId}-{idx}.png
          //     成功后更新 node.type_config.image_url。失败转 LocalIOError。
          if (hasInline) {
            final ioErr = await _persistInlineBytes(task, inlineBytes, running);
            if (ioErr != null) {
              final rows = await _persistFailure(task, ioErr, running);
              _emitFailure(
                  handle, _arbitrate(rows, running, ioErr, task.jobId));
              return;
            }
          }
          // T5-S3：remoteUrls（所有异步 Provider 走这条）→ 下载到
          //   videos/{jobId}.mp4 或 images/{jobId}.png，按 task.mode 分流。
          // 批量下 inline 与 remote 互斥：inline 已落盘则跳过 remote，
          // 避免同名双写/覆盖。
          if (remoteUrls.isNotEmpty && !(task.batchSize > 1 && hasInline)) {
            final err = await _persistRemoteUrls(task, remoteUrls, running);
            if (err != null) {
              final rows = await _persistFailure(task, err, running);
              _emitFailure(handle, _arbitrate(rows, running, err, task.jobId));
              return;
            }
          }
          final rows = await _persistTransition(
            task.jobId,
            from: const [JobStatuses.submitted, JobStatuses.polling],
            to: JobStatuses.success,
            extra: {
              JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
              JobCol.progress: 1.0,
            },
          );
          // HI-02：affectedRows==0 = cancel 抢先把行落成 cancelled
          // → 对外以 cancelled 为准，绝不补发 success。
          if (_lostToCancel(rows, running)) {
            _emitFailure(handle, _cancelledError(task.jobId));
            return;
          }
          handle._emit(status);
          handle._complete(status);
          return;
        case JobFailure(:final error):
          final rows = await _persistFailure(task, error, running);
          _emitFailure(handle, _arbitrate(rows, running, error, task.jobId));
          return;
      }

      await backoff();
    }
  }

  // ---- cancel 竞态裁决 ------------------------------------------------------

  /// 终态写库被 cancel 抢先：有 repo 时以 affectedRows==0 为准；
  /// 无 repo（纯内存）时退化为内存 cancelled 标志。
  bool _lostToCancel(int? rows, _RunningJob running) {
    if (!running.cancelled) return false;
    return rows == null || rows == 0;
  }

  /// 终态裁决：cancel 赢 → 对外发 cancelled，否则用原终态错误。
  InkError _arbitrate(
    int? rows,
    _RunningJob running,
    InkError original,
    String jobId,
  ) =>
      _lostToCancel(rows, running) ? _cancelledError(jobId) : original;

  /// ME-01：可中断睡眠——cancel/dispose 通过 [_RunningJob.wake] 提前唤醒，
  /// 避免最长 pollMaxInterval（默认 30s）的不可中断等待。
  Future<void> _sleepInterruptible(_RunningJob running, Duration duration) {
    final completer = Completer<void>();
    final timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    running.sleeper = completer;
    return completer.future.whenComplete(() {
      timer.cancel();
      running.sleeper = null;
    });
  }

  void _emitFailure(_Handle handle, InkError error) {
    final failure = JobStatus.failure(error: error);
    handle._emit(failure);
    handle._complete(failure);
  }

  InkError _cancelledError(String jobId) =>
      CancelledError.byUser(extra: {'job_id': jobId});

  // ---- 持久化 helpers (null repo 时全部 no-op) ----------------------------

  /// 返回 affectedRows：0 = 行不存在或 status 不在 from 集合（如已被 cancel 抢写），
  /// null = 未注入 repo（纯内存模式，无行数信息）。调用方据此裁决对外 emit。
  Future<int?> _persistTransition(
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

  Future<void> _persistUpdate(String jobId, Map<String, Object?> patch) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.update(jobId, patch);
  }

  Future<int?> _persistFailure(
    GenerationTask task,
    InkError error,
    _RunningJob running,
  ) async {
    // 所有失败终态的统一漏斗：在此落 ERROR 日志。
    _logger?.error(
      _logModule,
      'job failed',
      extra: {'job_id': task.jobId, 'error_code': error.code.wire},
      cause: error,
    );
    final rows = await _persistTransition(
      task.jobId,
      from: const [JobStatuses.pending, JobStatuses.submitted, JobStatuses.polling],
      to: JobStatuses.error,
      extra: {
        JobCol.errorCode: error.code.wire,
        JobCol.errorMessage: _truncate(error.toString(), 2000),
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _convergeSlotsAfterTerminal(task, rows, running, error);
    return rows;
  }

  Future<int?> _persistTimeout(
    GenerationTask task,
    InkError error,
    _RunningJob running,
  ) async {
    _logger?.error(
      _logModule,
      'job poll timeout',
      extra: {'job_id': task.jobId, 'error_code': error.code.wire},
    );
    final rows = await _persistTransition(
      task.jobId,
      from: const [JobStatuses.submitted, JobStatuses.polling],
      to: JobStatuses.timeout,
      extra: {
        JobCol.errorCode: error.code.wire,
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _convergeSlotsAfterTerminal(task, rows, running, error);
    return rows;
  }

  // ---- batch slot 落库 helpers（batchSize>1 专用；未注入 repo 时全 no-op） ----

  /// job 落终态后收敛遗留 generating 态 slot。
  ///
  /// 取消语境由 [_lostToCancel]（running.cancelled + 竞态裁决）显式判定，
  /// 绝不单凭 affectedRows==0 反推——二次失败写库同样是 0 行，但对外终态
  /// 仍是原错误，slot 必须收敛 error。
  Future<void> _convergeSlotsAfterTerminal(
    GenerationTask task,
    int? rows,
    _RunningJob running,
    InkError error,
  ) {
    if (task.batchSize <= 1) return Future.value();
    final cancelWon = _lostToCancel(rows, running);
    return _convergeSlots(
      task.jobId,
      toStatus: cancelWon ? SlotStatuses.cancelled : SlotStatuses.error,
      errorCode:
          cancelWon ? InkErrorCode.cancelledByUser.wire : error.code.wire,
    );
  }

  /// 终态 slot 收敛统一入口：绝不抛出。收敛链上的抛出会跳过 emit、
  /// 让 handle 永挂——失败仅记日志，init() 的孤儿 slot 回收兜底。
  Future<void> _convergeSlots(
    String jobId, {
    required String toStatus,
    String? errorCode,
  }) async {
    final repo = _batchResults;
    if (repo == null) return;
    try {
      await repo.finalizePendingByJob(
        jobId,
        toStatus: toStatus,
        errorCode: errorCode,
      );
    } on InkError catch (e) {
      _logger?.warn(_logModule, 'slot convergence failed (swallowed)', extra: {
        'job_id': jobId,
        'to_status': toStatus,
        'error_code': e.code.wire,
      });
    }
  }

  /// 按 (resultNodeId, slotIndex) 定位 slot 行并 patch；行缺失静默跳过。
  Future<void> _updateSlot(
    String resultNodeId,
    int slotIndex,
    Map<String, Object?> patch,
  ) async {
    final repo = _batchResults;
    if (repo == null) return;
    final row = await repo.findBySlot(resultNodeId, slotIndex);
    final id = row?[BatchResultCol.id];
    if (id == null) return;
    await repo.update(id.toString(), patch);
  }

  Map<String, Object?> _slotSuccessPatch(String relPath) => <String, Object?>{
        BatchResultCol.status: SlotStatuses.success,
        BatchResultCol.outputUrl: relPath,
        BatchResultCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      };

  Map<String, Object?> _slotErrorPatch(InkError error) => <String, Object?>{
        BatchResultCol.status: SlotStatuses.error,
        BatchResultCol.errorCode: error.code.wire,
        BatchResultCol.errorMessage: _truncate(error.toString(), 2000),
        BatchResultCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      };

  Future<int?> _persistCancel(
    String jobId, {
    required List<String> fromStatuses,
  }) {
    return _persistTransition(
      jobId,
      from: fromStatuses,
      to: JobStatuses.cancelled,
      extra: {
        JobCol.errorCode: InkErrorCode.cancelledByUser.wire,
        JobCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// b3：把同步 Provider 返回的 inline bytes 写到 canvas/images/，
  /// 更新 node.type_config.image_url。
  ///
  /// 依赖（fileResolver/nodeRepo）未注入 = 单测/纯内存模式：跳过落盘（返回 null）。
  /// 依赖已注入但关键 ID 缺失 = 生产故障：返回 LocalIOError（转 failure，不静默丢产物）。
  Future<InkError?> _persistInlineBytes(
    GenerationTask task,
    List<dynamic> bytesList,
    _RunningJob running,
  ) async {
    final projectId = task.projectId;
    final canvasId = task.canvasId;
    final resultNodeId = task.resultNodeId;
    final fileResolver = _fileResolver;
    final nodeRepo = _nodeRepo;
    // 依赖未注入 = 纯内存/单测模式：跳过落盘（非故障）。
    if (fileResolver == null || nodeRepo == null) {
      return null;
    }
    // 依赖已注入但关键 ID 缺失 = 生产故障：必须失败，绝不静默丢产物当成功。
    if (projectId == null || canvasId == null || resultNodeId == null) {
      return LocalIOError(
        extra: <String, Object?>{
          'job_id': task.jobId,
          'reason': 'missing_result_ids',
        },
      );
    }
    // 批量：逐张写盘 + 逐 slot 落终态（部分成功语义）。
    if (task.batchSize > 1) {
      return _persistInlineBytesBatch(
        task,
        bytesList,
        running,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        fileResolver: fileResolver,
        nodeRepo: nodeRepo,
      );
    }
    try {
      final relativePaths = <String>[];
      for (var i = 0; i < bytesList.length; i++) {
        final bytes = bytesList[i];
        final relPath = 'images/${task.jobId}-$i.png';
        final file = fileResolver.resolve(
          projectId: projectId,
          canvasId: canvasId,
          relativePath: relPath,
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes as List<int>);
        relativePaths.add(relPath);
      }
      // 多张时只取首张做主图（PRD §4.4：image_url 单值；批量在 batch_results 表）。
      await nodeRepo.patchTypeConfig(resultNodeId, {
        'image_url': relativePaths.first,
      });
      return null;
    } on FileSystemException catch (e) {
      return LocalIOError(
        cause: e,
        extra: {
          'job_id': task.jobId,
          'reason': 'write_inline_bytes_failed',
          'message': e.message,
        },
      );
    } on PathSecurityError catch (e) {
      return LocalIOError(
        cause: e,
        extra: {
          'job_id': task.jobId,
          'reason': 'unsafe_path',
        },
      );
    }
  }

  /// 批量 inlineBytes（batchSize>1，恒为图片）：逐张写 images/{jobId}-{i}.png，
  /// 每张独立落 slot 终态；≥1 张成功 → 整体 success（首张成功图作主图 image_url），
  /// 全败 → 返回最后一个错误（job 失败）。bytes 数 < batchSize 的缺失 slot 收敛 error。
  /// 取消即中断：剩余张不再写盘，未完成 slot 收敛 cancelled（已成功的保留）。
  Future<InkError?> _persistInlineBytesBatch(
    GenerationTask task,
    List<dynamic> bytesList,
    _RunningJob running, {
    required String projectId,
    required String canvasId,
    required String resultNodeId,
    required FileResolverService fileResolver,
    required NodeRepository nodeRepo,
  }) async {
    String? firstSuccessRel;
    InkError? lastError;
    final count = min(bytesList.length, task.batchSize);
    for (var i = 0; i < count; i++) {
      // 每张写盘前看取消位：已取消则中断，剩余 slot 由下方统一收敛。
      if (running.cancelled) break;
      final relPath = 'images/${task.jobId}-$i.png';
      InkError? slotError;
      try {
        final file = fileResolver.resolve(
          projectId: projectId,
          canvasId: canvasId,
          relativePath: relPath,
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytesList[i] as List<int>);
      } on FileSystemException catch (e) {
        slotError = LocalIOError(
          cause: e,
          extra: {
            'job_id': task.jobId,
            'slot_index': i,
            'reason': 'write_inline_bytes_failed',
            'message': e.message,
          },
        );
      } on PathSecurityError catch (e) {
        slotError = LocalIOError(
          cause: e,
          extra: {
            'job_id': task.jobId,
            'slot_index': i,
            'reason': 'unsafe_path',
          },
        );
      }
      if (slotError == null) {
        await _updateSlot(resultNodeId, i, _slotSuccessPatch(relPath));
        firstSuccessRel ??= relPath;
      } else {
        lastError = slotError;
        _logger?.warn(_logModule, 'batch slot failed', extra: {
          'job_id': task.jobId,
          'slot_index': i,
          'error_code': slotError.code.wire,
        });
        await _updateSlot(resultNodeId, i, _slotErrorPatch(slotError));
      }
    }
    if (running.cancelled) {
      // 取消中断：未完成 slot 收敛 cancelled；job 对外终态由 cancel 竞态裁决收口。
      await _convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.cancelled,
        errorCode: InkErrorCode.cancelledByUser.wire,
      );
    } else {
      // Provider 返回张数不足 batchSize：缺失 slot 收敛 error，避免永久 generating。
      await _convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.error,
        errorCode: InkErrorCode.providerInvalidResponse.wire,
      );
    }
    if (firstSuccessRel == null) {
      return lastError ??
          LocalIOError(
            extra: <String, Object?>{
              'job_id': task.jobId,
              'reason': 'batch_no_outputs',
            },
          );
    }
    await nodeRepo.patchTypeConfig(resultNodeId, {
      'image_url': firstSuccessRel,
    });
    return null;
  }

  /// T5-S3：把 Provider 返回的 remoteUrls 下载到本地，
  /// 并更新 node.type_config 里 video_url / image_url（可选 thumbnail_url）。
  ///
  /// 失败映射：
  ///   - [VideoDownloadError] → [DownloadError]（可重试，extra 带 http_status / url）
  ///   - [FileSystemException] → [LocalIOError]
  ///   - [PathSecurityError]   → [LocalIOError]
  ///
  /// 依赖未注入 = 单测/纯内存模式：跳过下载落盘（返回 null）。
  /// 依赖已注入但关键 ID 缺失 = 生产故障：返回 LocalIOError（转 failure）。
  /// batch_size=1 只取 remoteUrls.first；batchSize>1 走批量分支（逐 slot 落终态）。
  Future<InkError?> _persistRemoteUrls(
    GenerationTask task,
    List<String> remoteUrls,
    _RunningJob running,
  ) async {
    final projectId = task.projectId;
    final canvasId = task.canvasId;
    final resultNodeId = task.resultNodeId;
    final fileResolver = _fileResolver;
    final nodeRepo = _nodeRepo;
    final downloader = _videoDownloader;
    // 依赖未注入 = 纯内存/单测模式：跳过下载落盘（非故障）。
    if (fileResolver == null || nodeRepo == null || downloader == null) {
      return null;
    }
    // 依赖已注入但关键 ID 缺失 = 生产故障：失败，不静默丢产物。
    if (projectId == null || canvasId == null || resultNodeId == null) {
      return LocalIOError(
        extra: <String, Object?>{
          'job_id': task.jobId,
          'reason': 'missing_result_ids',
        },
      );
    }

    // 批量（视频恒 batchSize=1，不走此分支）：逐 URL 下载 + 逐 slot 落终态。
    if (task.batchSize > 1) {
      return _persistRemoteUrlsBatch(
        task,
        remoteUrls,
        running,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        fileResolver: fileResolver,
        nodeRepo: nodeRepo,
        downloader: downloader,
      );
    }

    final isVideo = task.mode == GenerationMode.textToVideo ||
        task.mode == GenerationMode.imageToVideo;
    final subdir = isVideo ? 'videos' : 'images';
    final ext = isVideo ? 'mp4' : 'png';
    final urlKey = isVideo ? 'video_url' : 'image_url';
    final url = remoteUrls.first;
    final relPath = '$subdir/${task.jobId}.$ext';

    try {
      final file = fileResolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relPath,
      );
      await downloader.download(url: url, destination: file);

      final patch = <String, Object?>{urlKey: relPath};

      // 视频可选：抽首帧（S4 换真实现；S3 provider 返回 null 时跳过）。
      final thumbnail = _thumbnail;
      if (isVideo && thumbnail != null) {
        try {
          final thumbRel = 'videos/${task.jobId}.jpg';
          final thumbFile = fileResolver.resolve(
            projectId: projectId,
            canvasId: canvasId,
            relativePath: thumbRel,
          );
          await thumbnail.extractFirstFrame(
            videoPath: file.path,
            destination: thumbFile,
          );
          patch['thumbnail_url'] = thumbRel;
        } on ThumbnailError catch (e) {
          // 抽帧失败不阻断视频可用，仅没有 thumbnail_url。
          _logger?.warn(_logModule, 'thumbnail extraction failed (swallowed)',
              extra: {'job_id': task.jobId, 'reason': e.toString()});
        } on FileSystemException catch (e) {
          // 同上。
          _logger?.warn(_logModule, 'thumbnail io failed (swallowed)',
              extra: {'job_id': task.jobId, 'reason': e.message});
        } on PathSecurityError {
          // 同上。
          _logger?.warn(_logModule, 'thumbnail unsafe path (swallowed)',
              extra: {'job_id': task.jobId});
        }
      }

      await nodeRepo.patchTypeConfig(resultNodeId, patch);
      return null;
    } on VideoDownloadError catch (e) {
      // ME-05：产物下载失败是 DownloadError 域（downloadFailed，可重试），
      // 误归 providerServer 会把"取文件失败"错报成"生成服务 5xx"。
      return DownloadError(
        cause: e,
        extra: {
          'job_id': task.jobId,
          'reason': 'remote_url_download_failed',
          'url': e.url,
          'http_status': e.httpStatus,
        },
      );
    } on FileSystemException catch (e) {
      return LocalIOError(
        cause: e,
        extra: {
          'job_id': task.jobId,
          'reason': 'write_remote_file_failed',
          'message': e.message,
        },
      );
    } on PathSecurityError catch (e) {
      return LocalIOError(
        cause: e,
        extra: {
          'job_id': task.jobId,
          'reason': 'unsafe_path',
        },
      );
    }
  }

  /// 批量 remoteUrls（batchSize>1，恒为图片）：逐 URL 下载到 images/{jobId}-{i}.png，
  /// 每张独立落 slot 终态；≥1 张成功 → 整体 success（首张成功图作主图 image_url），
  /// 全败 → 返回最后一个错误（job 失败）。URL 数 < batchSize 的缺失 slot 收敛 error。
  /// 取消即中断：剩余 URL 不再下载，未完成 slot 收敛 cancelled（已成功的保留）。
  Future<InkError?> _persistRemoteUrlsBatch(
    GenerationTask task,
    List<String> remoteUrls,
    _RunningJob running, {
    required String projectId,
    required String canvasId,
    required String resultNodeId,
    required FileResolverService fileResolver,
    required NodeRepository nodeRepo,
    required VideoDownloadService downloader,
  }) async {
    String? firstSuccessRel;
    InkError? lastError;
    final count = min(remoteUrls.length, task.batchSize);
    for (var i = 0; i < count; i++) {
      // 每张下载前看取消位：已取消则中断，剩余 slot 由下方统一收敛。
      if (running.cancelled) break;
      final relPath = 'images/${task.jobId}-$i.png';
      InkError? slotError;
      try {
        final file = fileResolver.resolve(
          projectId: projectId,
          canvasId: canvasId,
          relativePath: relPath,
        );
        await downloader.download(url: remoteUrls[i], destination: file);
      } on VideoDownloadError catch (e) {
        slotError = DownloadError(
          cause: e,
          extra: {
            'job_id': task.jobId,
            'slot_index': i,
            'reason': 'remote_url_download_failed',
            'url': e.url,
            'http_status': e.httpStatus,
          },
        );
      } on FileSystemException catch (e) {
        slotError = LocalIOError(
          cause: e,
          extra: {
            'job_id': task.jobId,
            'slot_index': i,
            'reason': 'write_remote_file_failed',
            'message': e.message,
          },
        );
      } on PathSecurityError catch (e) {
        slotError = LocalIOError(
          cause: e,
          extra: {
            'job_id': task.jobId,
            'slot_index': i,
            'reason': 'unsafe_path',
          },
        );
      }
      if (slotError == null) {
        await _updateSlot(resultNodeId, i, _slotSuccessPatch(relPath));
        firstSuccessRel ??= relPath;
      } else {
        lastError = slotError;
        _logger?.warn(_logModule, 'batch slot failed', extra: {
          'job_id': task.jobId,
          'slot_index': i,
          'error_code': slotError.code.wire,
        });
        await _updateSlot(resultNodeId, i, _slotErrorPatch(slotError));
      }
    }
    if (running.cancelled) {
      // 取消中断：未完成 slot 收敛 cancelled；job 对外终态由 cancel 竞态裁决收口。
      await _convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.cancelled,
        errorCode: InkErrorCode.cancelledByUser.wire,
      );
    } else {
      // Provider 返回 URL 数不足 batchSize：缺失 slot 收敛 error，避免永久 generating。
      await _convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.error,
        errorCode: InkErrorCode.providerInvalidResponse.wire,
      );
    }
    if (firstSuccessRel == null) {
      return lastError ??
          ProviderError(
            code: InkErrorCode.providerInvalidResponse,
            extra: <String, Object?>{
              'job_id': task.jobId,
              'reason': 'batch_no_outputs',
            },
          );
    }
    await nodeRepo.patchTypeConfig(resultNodeId, {
      'image_url': firstSuccessRel,
    });
    return null;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('JobQueueService disposed');
    }
  }
}

class _PendingJob {
  _PendingJob({required this.task, required this.handle});
  final GenerationTask task;
  final _Handle handle;
  // 被 cancel 后由 dispatch loop 跳过并丢弃。pending 队列只追加不重建。
  bool cancelled = false;
}

class _RunningJob {
  _RunningJob({required this.provider, required this.handle});
  final Submittable provider;
  final _Handle handle;
  String? providerJobId;
  bool cancelled = false;

  /// 当前退避睡眠的句柄；cancel/dispose 经 [wake] 提前唤醒。
  Completer<void>? sleeper;

  void wake() {
    final s = sleeper;
    if (s != null && !s.isCompleted) s.complete();
  }
}

class _Handle implements JobHandle {
  _Handle(this._jobId, this._controller, this._done);

  final String _jobId;
  final StreamController<JobStatus> _controller;
  final Completer<JobStatus> _done;

  /// ME-03：last-value cache——迟到订阅者先收到最近一次状态（含终态）。
  JobStatus? _last;

  @override
  String get jobId => _jobId;

  @override
  Stream<JobStatus> get status {
    // 尚无可重放状态且流仍开放 → 直接给广播流（零开销，事件时序与广播一致）。
    if (_last == null && !_controller.isClosed) return _controller.stream;
    // 迟到订阅：返回一条新流，onListen 同步建桥（无丢事件窗口），
    // 先重放 _last 再转发广播；广播已关闭则补发终态后立即 done。
    StreamSubscription<JobStatus>? bridge;
    late final StreamController<JobStatus> out;
    out = StreamController<JobStatus>(
      onListen: () {
        final last = _last;
        if (last != null) out.add(last);
        if (_controller.isClosed) {
          out.close();
          return;
        }
        bridge = _controller.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () => bridge?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<JobStatus> get done => _done.future;

  void _emit(JobStatus s) {
    _last = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  void _complete(JobStatus terminal) {
    if (!_done.isCompleted) _done.complete(terminal);
    if (!_controller.isClosed) _controller.close();
  }
}
