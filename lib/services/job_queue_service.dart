// JobQueueService 内存实现（PRD §10.7）。
//
// b1 ✅ 内存调度 + Provider 集成
// b2 ✅ JobRepository 持久化 + 启动恢复
// b3 ✅ FileResolverService 落盘集成（仅 inlineBytes，本次）
// b3.1 ⏳ remoteUrls HTTP 下载 + 重试 + 续传
// b4 ⏳ 性能档位 → globalConcurrency 联动

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import '../core/errors/ink_error.dart';
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
import '../providers/provider_registry.dart';

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
    final orphan = await repo.listByStatus(const ['submitted', 'polling']);
    if (orphan.isNotEmpty) {
      _logger?.info(_logModule, 'startup recovery: orphan jobs cancelled',
          extra: {'count': orphan.length});
    }
    for (final row in orphan) {
      final id = row['id'] as String?;
      if (id == null) continue;
      await repo.transitionStatus(
        id: id,
        fromStatuses: const ['submitted', 'polling'],
        toStatus: 'cancelled',
        extra: {
          'error_code': InkErrorCode.cancelledOnExit.wire,
          'error_message': 'app exited while job was running',
        },
      );
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
      await _persistCancel(jobId, fromStatuses: const ['pending']);
      _emitFailure(pending.handle, _cancelledError(jobId));
      return;
    }
    final running = _running[jobId];
    if (running == null) return; // idempotent
    running.cancelled = true;
    await _persistCancel(jobId, fromStatuses: const ['submitted', 'polling']);
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
      _emitFailure(p.handle, _cancelledError(p.task.jobId));
    }
    _pending.clear();
    _pendingIndex.clear();
    for (final entry in _running.entries) {
      entry.value.cancelled = true;
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
    final running = _RunningJob(provider: provider);
    _running[task.jobId] = running;

    try {
      // pending → submitted（写 submitted_at）
      await _persistTransition(
        task.jobId,
        from: const ['pending'],
        to: 'submitted',
        extra: {'submitted_at': DateTime.now().toUtc().toIso8601String()},
      );

      final providerJobId = await provider.submit(task);
      running.providerJobId = providerJobId;
      await _persistUpdate(task.jobId, {'remote_task_id': providerJobId});

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
      await _persistFailure(task.jobId, e);
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
    var enteredPolling = false;

    while (true) {
      if (running.cancelled) {
        // cancel 路径已写过 transitionStatus → cancelled，这里不再写
        _emitFailure(handle, _cancelledError(task.jobId));
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        final timeoutErr = ProviderError(
          code: InkErrorCode.pollTimeout,
          extra: {'provider_id': task.providerId, 'job_id': task.jobId},
        );
        await _persistTimeout(task.jobId, timeoutErr);
        _emitFailure(handle, timeoutErr);
        return;
      }

      final JobStatus status = await provider.poll(providerJobId);
      switch (status) {
        case JobInProgress(:final progress):
          if (!enteredPolling) {
            await _persistTransition(
              task.jobId,
              from: const ['submitted'],
              to: 'polling',
              extra: {'progress': progress},
            );
            enteredPolling = true;
          } else {
            await _persistUpdate(task.jobId, {'progress': progress});
          }
          handle._emit(status);
        case JobSuccess(:final inlineBytes, :final remoteUrls):
          // b3：inlineBytes 落盘到 {canvasRoot}/images/{jobId}-{idx}.png
          //     成功后更新 node.type_config.image_url。失败转 LocalIOError。
          if (inlineBytes != null && inlineBytes.isNotEmpty) {
            final ioErr = await _persistInlineBytes(task, inlineBytes);
            if (ioErr != null) {
              await _persistFailure(task.jobId, ioErr);
              _emitFailure(handle, ioErr);
              return;
            }
          }
          // T5-S3：remoteUrls（所有异步 Provider 走这条）→ 下载到
          //   videos/{jobId}.mp4 或 images/{jobId}.png，按 task.mode 分流。
          if (remoteUrls.isNotEmpty) {
            final err = await _persistRemoteUrls(task, remoteUrls);
            if (err != null) {
              await _persistFailure(task.jobId, err);
              _emitFailure(handle, err);
              return;
            }
          }
          await _persistTransition(
            task.jobId,
            from: const ['submitted', 'polling'],
            to: 'success',
            extra: {
              'completed_at': DateTime.now().toUtc().toIso8601String(),
              'progress': 1.0,
            },
          );
          handle._emit(status);
          handle._complete(status);
          return;
        case JobFailure(:final error):
          await _persistFailure(task.jobId, error);
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

  // ---- 持久化 helpers (null repo 时全部 no-op) ----------------------------

  Future<void> _persistTransition(
    String jobId, {
    required List<String> from,
    required String to,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.transitionStatus(
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

  Future<void> _persistFailure(String jobId, InkError error) async {
    // 所有失败终态的统一漏斗：在此落 ERROR 日志。
    _logger?.error(
      _logModule,
      'job failed',
      extra: {'job_id': jobId, 'error_code': error.code.wire},
      cause: error,
    );
    await _persistTransition(
      jobId,
      from: const ['pending', 'submitted', 'polling'],
      to: 'error',
      extra: {
        'error_code': error.code.wire,
        'error_message': _truncate(error.toString(), 2000),
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _persistTimeout(String jobId, InkError error) async {
    _logger?.error(
      _logModule,
      'job poll timeout',
      extra: {'job_id': jobId, 'error_code': error.code.wire},
    );
    await _persistTransition(
      jobId,
      from: const ['submitted', 'polling'],
      to: 'timeout',
      extra: {
        'error_code': error.code.wire,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _persistCancel(
    String jobId, {
    required List<String> fromStatuses,
  }) async {
    await _persistTransition(
      jobId,
      from: fromStatuses,
      to: 'cancelled',
      extra: {
        'error_code': InkErrorCode.cancelledByUser.wire,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// b3：把同步 Provider 返回的 inline bytes 写到 canvas/images/，
  /// 更新 node.type_config.image_url。
  ///
  /// 三个关键 ID（projectId / canvasId / resultNodeId）任一缺失或服务未注入 →
  /// 跳过落盘（认为是单测路径）。返回 null 表示成功，非 null = 应转 failure。
  Future<InkError?> _persistInlineBytes(
    GenerationTask task,
    List<dynamic> bytesList,
  ) async {
    final projectId = task.projectId;
    final canvasId = task.canvasId;
    final resultNodeId = task.resultNodeId;
    final fileResolver = _fileResolver;
    final nodeRepo = _nodeRepo;
    if (projectId == null ||
        canvasId == null ||
        resultNodeId == null ||
        fileResolver == null ||
        nodeRepo == null) {
      return null;
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
      // 当前 batch_size=1 是 P0 主路径；批量留给后续 batch_results 接入。
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

  /// T5-S3：把 Provider 返回的 remoteUrls 下载到本地，
  /// 并更新 node.type_config 里 video_url / image_url（可选 thumbnail_url）。
  ///
  /// 失败映射：
  ///   - [VideoDownloadError] → [ProviderError]（`providerServer`，extra 带 http_status / url）
  ///   - [FileSystemException] → [LocalIOError]
  ///   - [PathSecurityError]   → [LocalIOError]
  ///
  /// 三关键 ID（projectId / canvasId / resultNodeId）任一缺失或依赖未注入 →
  /// 静默跳过（单测路径）。batch_size=1：只取 remoteUrls.first，批量留后续。
  Future<InkError?> _persistRemoteUrls(
    GenerationTask task,
    List<String> remoteUrls,
  ) async {
    final projectId = task.projectId;
    final canvasId = task.canvasId;
    final resultNodeId = task.resultNodeId;
    final fileResolver = _fileResolver;
    final nodeRepo = _nodeRepo;
    final downloader = _videoDownloader;
    if (projectId == null ||
        canvasId == null ||
        resultNodeId == null ||
        fileResolver == null ||
        nodeRepo == null ||
        downloader == null) {
      return null;
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
      return ProviderError(
        code: InkErrorCode.providerServer,
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
