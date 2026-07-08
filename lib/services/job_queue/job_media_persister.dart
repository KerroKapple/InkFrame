// JobMediaPersister 实现（LB-03 从 JobQueue 抽出）：inlineBytes / remoteUrls 落盘
// + 批量 slot 收敛。任一媒体依赖注入即用 [JobMediaPersisterImpl]（各方法按自身
// 依赖独立守卫跳过，保持拆分前的 per-dep 独立性）；全部未注入（纯内存）时用
// [NullJobMediaPersister]（null-object，全 no-op），编排器对 _media 恒非空、不判空。
import 'dart:io';
import 'dart:math';

import '../../core/constants/job_statuses.dart';
import '../../core/db/columns.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/batch_result_repository.dart';
import '../../core/interfaces/file_resolver_service.dart';
import '../../core/interfaces/job_media_persister.dart';
import '../../core/interfaces/node_repository.dart';
import '../../core/interfaces/thumbnail_service.dart';
import '../../core/interfaces/video_download_service.dart';
import '../../core/logging/logger_service.dart';
import '../../core/models/generation_task.dart';
import '../../core/models/provider_capabilities.dart';
import 'job_queue_util.dart';

/// 真实落盘器。所有媒体依赖均可空——每个方法只守卫自己实际用到的依赖：
///   - persistInlineBytes：fileResolver + nodeRepo
///   - persistRemoteUrls：fileResolver + nodeRepo + downloader
///   - convergeSlots / convergeSlotsAfterTerminal / _updateSlot：batchResults
/// 缺失即该路 no-op（返回 null / 直接 return），与拆分前逐依赖跳过语义逐字节一致。
class JobMediaPersisterImpl implements JobMediaPersister {
  JobMediaPersisterImpl({
    FileResolverService? fileResolver,
    NodeRepository? nodeRepo,
    BatchResultRepository? batchResults,
    VideoDownloadService? downloader,
    ThumbnailService? thumbnail,
    LoggerService? logger,
  })  : _fileResolver = fileResolver,
        _nodeRepo = nodeRepo,
        _batchResults = batchResults,
        _downloader = downloader,
        _thumbnail = thumbnail,
        _logger = logger;

  final FileResolverService? _fileResolver;
  final NodeRepository? _nodeRepo;
  final BatchResultRepository? _batchResults;
  final VideoDownloadService? _downloader;
  final ThumbnailService? _thumbnail;
  final LoggerService? _logger;

  // ---- slot 收敛 ----------------------------------------------------------

  @override
  Future<void> convergeSlotsAfterTerminal(
    GenerationTask task,
    int? rows,
    CancelSignal running,
    InkError error,
  ) {
    if (task.batchSize <= 1) return Future.value();
    // 取消语境由 [lostToCancel]（running.cancelled + 竞态裁决）显式判定，
    // 绝不单凭 affectedRows==0 反推——二次失败写库同样是 0 行，但对外终态
    // 仍是原错误，slot 必须收敛 error。
    final cancelWon = lostToCancel(rows: rows, cancelled: running.cancelled);
    return convergeSlots(
      task.jobId,
      toStatus: cancelWon ? SlotStatuses.cancelled : SlotStatuses.error,
      errorCode:
          cancelWon ? InkErrorCode.cancelledByUser.wire : error.code.wire,
    );
  }

  @override
  Future<void> convergeSlots(
    String jobId, {
    required String toStatus,
    String? errorCode,
  }) async {
    // 终态 slot 收敛统一入口：绝不抛出。收敛链上的抛出会跳过 emit、
    // 让 handle 永挂——失败仅记日志，init() 的孤儿 slot 回收兜底。
    final repo = _batchResults;
    if (repo == null) return;
    try {
      await repo.finalizePendingByJob(
        jobId,
        toStatus: toStatus,
        errorCode: errorCode,
      );
    } on InkError catch (e) {
      _logger?.warn(
          kJobQueueLogModule, 'slot convergence failed (swallowed)', extra: {
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
        BatchResultCol.errorMessage: truncate(error.toString(), 2000),
        BatchResultCol.completedAt: DateTime.now().toUtc().toIso8601String(),
      };

  // ---- inlineBytes 落盘 ----------------------------------------------------

  /// b3：把同步 Provider 返回的 inline bytes 写到 canvas/images/，
  /// 更新 node.type_config.image_url。
  ///
  /// 依赖（fileResolver/nodeRepo）未注入 = 单测/纯内存模式：跳过落盘（返回 null）。
  /// 依赖已注入但关键 ID 缺失 = 生产故障：返回 LocalIOError（转 failure，不静默丢产物）。
  @override
  Future<InkError?> persistInlineBytes(
    GenerationTask task,
    List<dynamic> bytesList,
    CancelSignal running,
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
    CancelSignal running, {
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
        _logger?.warn(kJobQueueLogModule, 'batch slot failed', extra: {
          'job_id': task.jobId,
          'slot_index': i,
          'error_code': slotError.code.wire,
        });
        await _updateSlot(resultNodeId, i, _slotErrorPatch(slotError));
      }
    }
    if (running.cancelled) {
      // 取消中断：未完成 slot 收敛 cancelled；job 对外终态由 cancel 竞态裁决收口。
      await convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.cancelled,
        errorCode: InkErrorCode.cancelledByUser.wire,
      );
    } else {
      // Provider 返回张数不足 batchSize：缺失 slot 收敛 error，避免永久 generating。
      await convergeSlots(
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

  // ---- remoteUrls 下载落盘 -------------------------------------------------

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
  @override
  Future<InkError?> persistRemoteUrls(
    GenerationTask task,
    List<String> remoteUrls,
    CancelSignal running,
  ) async {
    final projectId = task.projectId;
    final canvasId = task.canvasId;
    final resultNodeId = task.resultNodeId;
    final fileResolver = _fileResolver;
    final nodeRepo = _nodeRepo;
    final downloader = _downloader;
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
          _logger?.warn(kJobQueueLogModule,
              'thumbnail extraction failed (swallowed)',
              extra: {'job_id': task.jobId, 'reason': e.toString()});
        } on FileSystemException catch (e) {
          // 同上。
          _logger?.warn(kJobQueueLogModule, 'thumbnail io failed (swallowed)',
              extra: {'job_id': task.jobId, 'reason': e.message});
        } on PathSecurityError {
          // 同上。
          _logger?.warn(kJobQueueLogModule, 'thumbnail unsafe path (swallowed)',
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
    CancelSignal running, {
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
        _logger?.warn(kJobQueueLogModule, 'batch slot failed', extra: {
          'job_id': task.jobId,
          'slot_index': i,
          'error_code': slotError.code.wire,
        });
        await _updateSlot(resultNodeId, i, _slotErrorPatch(slotError));
      }
    }
    if (running.cancelled) {
      // 取消中断：未完成 slot 收敛 cancelled；job 对外终态由 cancel 竞态裁决收口。
      await convergeSlots(
        task.jobId,
        toStatus: SlotStatuses.cancelled,
        errorCode: InkErrorCode.cancelledByUser.wire,
      );
    } else {
      // Provider 返回 URL 数不足 batchSize：缺失 slot 收敛 error，避免永久 generating。
      await convergeSlots(
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
}

/// null-object：所有媒体依赖均未注入（纯内存模式）时注入，全 no-op。
/// 编排器因此对 _media 恒非空、无需判空分支。
class NullJobMediaPersister implements JobMediaPersister {
  const NullJobMediaPersister();

  @override
  Future<InkError?> persistInlineBytes(
    GenerationTask task,
    List<dynamic> bytesList,
    CancelSignal running,
  ) async =>
      null;

  @override
  Future<InkError?> persistRemoteUrls(
    GenerationTask task,
    List<String> remoteUrls,
    CancelSignal running,
  ) async =>
      null;

  @override
  Future<void> convergeSlots(
    String jobId, {
    required String toStatus,
    String? errorCode,
  }) async {}

  @override
  Future<void> convergeSlotsAfterTerminal(
    GenerationTask task,
    int? rows,
    CancelSignal running,
    InkError error,
  ) async {}
}
