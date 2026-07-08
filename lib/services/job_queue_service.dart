// JobQueueService 内存编排器（PRD §10.7）：只留调度、单任务状态机、cancel 竞态裁决。
// LB-03 拆分：产物落盘→JobMediaPersister；写库/启动恢复→JobStatePersister；
// 句柄→JobHandleImpl；共享内件（RunningJob / 裁决谓词）→job_queue_util。

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../core/constants/job_statuses.dart';
import '../core/db/columns.dart';
import '../core/errors/ink_error.dart';
import '../core/interfaces/batch_result_repository.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/logging/logger_service.dart';
import '../core/interfaces/job_media_persister.dart';
import '../core/interfaces/job_queue_service.dart';
import '../core/interfaces/job_repository.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/thumbnail_service.dart';
import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/video_download_service.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/interfaces/provider_registry.dart';
import 'job_queue/job_handle_impl.dart';
import 'job_queue/job_media_persister.dart';
import 'job_queue/job_queue_util.dart';
import 'job_queue/job_state_persister.dart';

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
        _logger = logger,
        _globalConcurrency = globalConcurrency,
        _pollInitial = pollInitialInterval,
        _pollMax = pollMaxInterval,
        _pollMultiplier = pollBackoffMultiplier,
        _pollTimeout = pollTimeout,
        _random = random ?? Random(),
        // 任一媒体依赖注入即用真实落盘器（各方法按自身依赖独立守卫跳过，保持拆分前
        // 的 per-dep 独立性）；全部未注入（纯内存）才用 null-object 全 no-op。
        _media = (fileResolver != null ||
                nodeRepo != null ||
                batchResultRepo != null ||
                videoDownloader != null ||
                thumbnailService != null)
            ? JobMediaPersisterImpl(
                fileResolver: fileResolver,
                nodeRepo: nodeRepo,
                batchResults: batchResultRepo,
                downloader: videoDownloader,
                thumbnail: thumbnailService,
                logger: logger,
              )
            : const NullJobMediaPersister() {
    _state = JobStatePersister(
      repo: repo,
      batchResults: batchResultRepo,
      logger: logger,
      media: _media,
    );
  }

  final ProviderRegistry _registry;
  final LoggerService? _logger;
  final JobMediaPersister _media;
  late final JobStatePersister _state;
  final int _globalConcurrency;

  final Duration _pollInitial;
  final Duration _pollMax;
  final double _pollMultiplier;
  final Duration _pollTimeout;
  final Random _random;

  final Queue<_PendingJob> _pending = Queue<_PendingJob>();
  // 与 _pending 一一对应的索引；jobId → 同一个 _PendingJob 引用。
  // cancel(jobId) 用它做 O(1) 定位 + 移除，避免把 queue 拆成 List 重建。
  final Map<String, _PendingJob> _pendingIndex = <String, _PendingJob>{};
  final Map<String, RunningJob> _running = <String, RunningJob>{};
  final Map<String, int> _perProviderSlots = <String, int>{};
  bool _disposed = false;

  @override
  Future<void> init() => _state.init();

  @override
  Future<JobHandle> submit(GenerationTask task) async {
    _ensureNotDisposed();
    if (_pendingIndex.containsKey(task.jobId) ||
        _running.containsKey(task.jobId)) {
      throw StateError('jobId ${task.jobId} already submitted');
    }
    // ignore: close_sinks  // 终态由 JobHandleImpl._complete 关闭
    final controller = StreamController<JobStatus>.broadcast();
    final doneCompleter = Completer<JobStatus>();
    final handle = JobHandleImpl(task.jobId, controller, doneCompleter);

    _logger?.debug(kJobQueueLogModule, 'job queued', extra: {
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
      await _state.persistCancel(jobId, fromStatuses: const [JobStatuses.pending]);
      // 排队期取消：预建的 slot 占位行同步收敛（仅批量 job 有 slot 行）。
      if (pending.task.batchSize > 1) {
        await _media.convergeSlots(
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
    await _state.persistCancel(jobId,
        fromStatuses: const [JobStatuses.submitted, JobStatuses.polling]);
    running.wake(); // ME-01：中断退避睡眠，让 _pollLoop 立即收敛到 cancelled
    final provider = running.provider;
    if (provider is Cancellable) {
      try {
        await (provider as Cancellable).cancel(running.providerJobId ?? jobId);
      } on InkError catch (e) {
        // 按 PROVIDER-API §5.4：cancel 失败不抛——但必须留日志痕迹。
        _logger?.warn(kJobQueueLogModule, 'provider cancel failed (swallowed)',
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
          _state.persistCancel(p.task.jobId, fromStatuses: const [JobStatuses.pending]));
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

  Future<void> _runJob(GenerationTask task, JobHandleImpl handle) async {
    final provider = _registry.get(task.providerId);
    final running = RunningJob(provider: provider, handle: handle);
    _running[task.jobId] = running;

    try {
      // pending → submitted（写 submitted_at）
      await _state.persistTransition(
        task.jobId,
        from: const [JobStatuses.pending],
        to: JobStatuses.submitted,
        extra: {JobCol.submittedAt: DateTime.now().toUtc().toIso8601String()},
      );

      final providerJobId = await provider.submit(task);
      running.providerJobId = providerJobId;
      await _state.persistUpdate(task.jobId, {JobCol.remoteTaskId: providerJobId});

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
      // LB-02：能力声明的 poll 超时/间隔覆盖实例默认（未声明则回落默认）。
      final caps = provider.capabilities;
      await _pollLoop(
        provider as Pollable,
        providerJobId,
        task,
        handle,
        running,
        pollTimeout: caps.pollTimeout ?? _pollTimeout,
        pollInitial: caps.pollInterval ?? _pollInitial,
      );
    } on InkError catch (e) {
      final rows = await _state.persistFailure(task, e, running);
      _emitFailure(handle, _arbitrate(rows, running, e, task.jobId));
    } catch (e, st) {
      // HI-01 兜底：非 InkError（provider bug / 库异常）逃逸会让 handle 永挂。
      // 队列边界统一翻译成 UnknownError，保证 handle 一定终结。
      final err = UnknownError(
        cause: e,
        stackTrace: st,
        extra: {'job_id': task.jobId},
      );
      await _state.persistFailure(task, err, running);
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
    JobHandleImpl handle,
    RunningJob running, {
    required Duration pollTimeout,
    required Duration pollInitial,
  }) async {
    final deadline = DateTime.now().add(pollTimeout);
    var interval = pollInitial;
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
      await _state.persistCancel(
        task.jobId,
        fromStatuses: const [JobStatuses.submitted, JobStatuses.polling],
      );
      if (task.batchSize > 1) {
        await _media.convergeSlots(
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
        final rows = await _state.persistTimeout(task, timeoutErr, running);
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
            await _state.persistTransition(
              task.jobId,
              from: const [JobStatuses.submitted],
              to: JobStatuses.polling,
              extra: {JobCol.progress: progress},
            );
            enteredPolling = true;
          } else {
            await _state.persistUpdate(task.jobId, {JobCol.progress: progress});
          }
          handle.emit(status);
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
            final rows = await _state.persistFailure(task, err, running);
            _emitFailure(handle, _arbitrate(rows, running, err, task.jobId));
            return;
          }
          // b3：inlineBytes 落盘到 {canvasRoot}/images/{jobId}-{idx}.png
          //     成功后更新 node.type_config.image_url。失败转 LocalIOError。
          if (hasInline) {
            final ioErr =
                await _media.persistInlineBytes(task, inlineBytes, running);
            if (ioErr != null) {
              final rows = await _state.persistFailure(task, ioErr, running);
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
            final err =
                await _media.persistRemoteUrls(task, remoteUrls, running);
            if (err != null) {
              final rows = await _state.persistFailure(task, err, running);
              _emitFailure(handle, _arbitrate(rows, running, err, task.jobId));
              return;
            }
          }
          final rows = await _state.persistTransition(
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
          handle.emit(status);
          handle.complete(status);
          return;
        case JobFailure(:final error):
          final rows = await _state.persistFailure(task, error, running);
          _emitFailure(handle, _arbitrate(rows, running, error, task.jobId));
          return;
      }

      await backoff();
    }
  }

  // ---- cancel 竞态裁决 ------------------------------------------------------

  /// 终态写库被 cancel 抢先：有 repo 时以 affectedRows==0 为准；
  /// 无 repo（纯内存）时退化为内存 cancelled 标志。
  bool _lostToCancel(int? rows, RunningJob running) =>
      lostToCancel(rows: rows, cancelled: running.cancelled);

  /// 终态裁决：cancel 赢 → 对外发 cancelled，否则用原终态错误。
  InkError _arbitrate(
    int? rows,
    RunningJob running,
    InkError original,
    String jobId,
  ) =>
      _lostToCancel(rows, running) ? _cancelledError(jobId) : original;

  /// ME-01：可中断睡眠——cancel/dispose 通过 [RunningJob.wake] 提前唤醒，
  /// 避免最长 pollMaxInterval（默认 30s）的不可中断等待。
  Future<void> _sleepInterruptible(RunningJob running, Duration duration) {
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

  void _emitFailure(JobHandleImpl handle, InkError error) {
    final failure = JobStatus.failure(error: error);
    handle.emit(failure);
    handle.complete(failure);
  }

  InkError _cancelledError(String jobId) =>
      CancelledError.byUser(extra: {'job_id': jobId});

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('JobQueueService disposed');
    }
  }
}

class _PendingJob {
  _PendingJob({required this.task, required this.handle});
  final GenerationTask task;
  final JobHandleImpl handle;
  // 被 cancel 后由 dispatch loop 跳过并丢弃。pending 队列只追加不重建。
  bool cancelled = false;
}
