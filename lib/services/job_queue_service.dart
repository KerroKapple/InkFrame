// JobQueueService 内存实现（PRD §10.7）。
//
// 不持久化 jobs 表，不写盘——纯调度引擎。b2 / b3 子步分别接入。

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../core/errors/ink_error.dart';
import '../core/interfaces/generation_provider.dart';
import '../core/interfaces/job_queue_service.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../providers/provider_registry.dart';

class InMemoryJobQueueService implements JobQueueService {
  InMemoryJobQueueService({
    required ProviderRegistry registry,
    int globalConcurrency = 2,
    Duration pollInitialInterval = const Duration(seconds: 3),
    Duration pollMaxInterval = const Duration(seconds: 30),
    double pollBackoffMultiplier = 2.0,
    Duration pollTimeout = const Duration(minutes: 30),
    Random? random,
  })  : _registry = registry,
        _globalConcurrency = globalConcurrency,
        _pollInitial = pollInitialInterval,
        _pollMax = pollMaxInterval,
        _pollMultiplier = pollBackoffMultiplier,
        _pollTimeout = pollTimeout,
        _random = random ?? Random();

  final ProviderRegistry _registry;
  final int _globalConcurrency;
  final Duration _pollInitial;
  final Duration _pollMax;
  final double _pollMultiplier;
  final Duration _pollTimeout;
  final Random _random;

  final Queue<_PendingJob> _pending = Queue<_PendingJob>();
  final Map<String, _RunningJob> _running = <String, _RunningJob>{};
  final Map<String, int> _perProviderSlots = <String, int>{};
  bool _disposed = false;

  @override
  Future<JobHandle> submit(GenerationTask task) async {
    _ensureNotDisposed();
    if (_pending.any((p) => p.task.jobId == task.jobId) ||
        _running.containsKey(task.jobId)) {
      throw StateError('jobId ${task.jobId} already submitted');
    }
    // ignore: close_sinks  // 终态由 _Handle._complete 关闭
    final controller = StreamController<JobStatus>.broadcast();
    final doneCompleter = Completer<JobStatus>();
    final handle = _Handle(task.jobId, controller, doneCompleter);

    _pending.add(_PendingJob(task: task, handle: handle));
    _schedule();
    return handle;
  }

  @override
  Future<void> cancel(String jobId) async {
    final pendingIdx = _pending.toList().indexWhere((p) => p.task.jobId == jobId);
    if (pendingIdx >= 0) {
      final list = _pending.toList();
      final removed = list.removeAt(pendingIdx);
      _pending
        ..clear()
        ..addAll(list);
      _emitFailure(removed.handle, _cancelledError(jobId));
      return;
    }
    final running = _running[jobId];
    if (running == null) return; // idempotent
    running.cancelled = true;
    final provider = running.provider;
    if (provider is Cancellable) {
      try {
        await (provider as Cancellable).cancel(running.providerJobId ?? jobId);
      } on InkError {
        // 按 PROVIDER-API §5.4：cancel 失败不抛
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final p in _pending) {
      _emitFailure(p.handle, _cancelledError(p.task.jobId));
    }
    _pending.clear();
    for (final entry in _running.entries) {
      entry.value.cancelled = true;
    }
  }

  // ---- 调度 ---------------------------------------------------------------

  void _schedule() {
    if (_disposed) return;
    while (_pending.isNotEmpty &&
        _running.length < _globalConcurrency) {
      final next = _pickNextSchedulable();
      if (next == null) return; // 所有 pending 都被 per-provider 限流卡住
      _pending.remove(next);
      _occupy(next.task.providerId);
      _runJob(next.task, next.handle);
    }
  }

  _PendingJob? _pickNextSchedulable() {
    for (final p in _pending) {
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
    final running = _RunningJob(provider: provider);
    _running[task.jobId] = running;

    try {
      final providerJobId = await provider.submit(task);
      running.providerJobId = providerJobId;

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
      _emitFailure(handle, e);
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

    while (true) {
      if (running.cancelled) {
        _emitFailure(handle, _cancelledError(task.jobId));
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        _emitFailure(
          handle,
          ProviderError(
            code: InkErrorCode.pollTimeout,
            extra: {'provider_id': task.providerId, 'job_id': task.jobId},
          ),
        );
        return;
      }

      final JobStatus status = await provider.poll(providerJobId);
      switch (status) {
        case JobInProgress():
          handle._emit(status);
        case JobSuccess():
          handle._emit(status);
          handle._complete(status);
          return;
        case JobFailure(:final error):
          _emitFailure(handle, error);
          return;
      }

      // 退避 + jitter
      final jitter = 1.0 + (_random.nextDouble() - 0.5) * 0.4; // ±20%
      final nextMs = (interval.inMilliseconds * _pollMultiplier * jitter).round();
      interval = Duration(milliseconds: nextMs.clamp(0, _pollMax.inMilliseconds));
      await Future<void>.delayed(interval);
    }
  }

  void _emitFailure(_Handle handle, InkError error) {
    final failure = JobStatus.failure(error: error);
    handle._emit(failure);
    handle._complete(failure);
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
  final _Handle handle;
}

class _RunningJob {
  _RunningJob({required this.provider});
  final Submittable provider;
  String? providerJobId;
  bool cancelled = false;
}

class _Handle implements JobHandle {
  _Handle(this._jobId, this._controller, this._done);

  final String _jobId;
  final StreamController<JobStatus> _controller;
  final Completer<JobStatus> _done;

  @override
  String get jobId => _jobId;

  @override
  Stream<JobStatus> get status => _controller.stream;

  @override
  Future<JobStatus> get done => _done.future;

  void _emit(JobStatus s) {
    if (!_controller.isClosed) _controller.add(s);
  }

  void _complete(JobStatus terminal) {
    if (!_done.isCompleted) _done.complete(terminal);
    if (!_controller.isClosed) _controller.close();
  }
}
