// GenerationController — 把"Canvas config 节点 → 生成 → 结果节点"串起来。
//
// 职责（S3a）：
//   1. 读 config 节点的 type_config（prompt / providerId / resolution / aspectRatio）
//   2. 从 SecureStorage 取 API Key（缺失 → GenerationError.missingApiKey）
//   3. 预创建 result 节点（source_node_id = config.id）
//      —— 注意：原 plan R2 "success 后创"在 B-b3 落盘体系下不可行：
//         JobQueueService 落盘逻辑要 GenerationTask.resultNodeId 才能
//         NodeRepository.update(image_url)。必须预创建 + 失败清理。
//   4. 在 jobs 表插 pending 行（result_node_id 指向刚建的 result）
//   5. 组装 GenerationTask 交给 JobQueueService.submit
//   6. 等 JobHandle.done：
//      - success → 返回，UI 通过 node.image_url 渲染
//      - failure → NodeRepository.softDelete(resultNodeId) 清孤儿，
//                  error 原样上抛（UI 层接 toast）
//
// 本文件仅一次性生成（文生图）；imageToImage / video 未来扩展时加入
// refImages / duration / camera 等字段 mapping 即可。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/default_providers.dart';
import '../../core/constants/secure_storage_keys.dart';
import '../../core/di/file_resolver.dart';
import '../../core/di/job_queue.dart';
import '../../core/di/providers.dart';
import '../../core/di/repositories.dart';
import '../../core/di/secure_storage.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/edge_repository.dart';
import '../../core/interfaces/file_resolver_service.dart';
import '../../core/interfaces/job_queue_service.dart';
import '../../core/interfaces/job_repository.dart';
import '../../core/interfaces/node_repository.dart';
import '../../core/interfaces/secure_storage_service.dart';
import '../../core/models/generation_task.dart';
import '../../core/models/job_status.dart';
import '../../core/models/provider_capabilities.dart';
import '../../core/interfaces/provider_registry.dart';
import 'models/job_state.dart';
import 'providers/jobs_registry.dart';

final generationControllerProvider = FutureProvider<GenerationController>(
  (ref) async {
    final nodes = await ref.watch(nodeRepositoryProvider.future);
    final edges = await ref.watch(edgeRepositoryProvider.future);
    final jobs = await ref.watch(jobRepositoryProvider.future);
    final secure = ref.watch(secureStorageServiceProvider);
    final queue = await ref.watch(jobQueueServiceProvider.future);
    final registry = ref.watch(providerRegistryProvider);
    final resolver = ref.watch(fileResolverServiceProvider);
    // jobsRegistryProvider 是 keepAlive：用 read 拿实例，controller 持有它，
    // 后台 _track future 全程不再触碰 ref。
    final jobsRegistry = ref.read(jobsRegistryProvider.notifier);
    return GenerationController(
      nodes: nodes,
      edges: edges,
      jobs: jobs,
      secure: secure,
      queue: queue,
      registry: registry,
      resolver: resolver,
      jobsRegistry: jobsRegistry,
    );
  },
  name: 'generationControllerProvider',
);

/// 生成控制器异常。具体子类见下方——UI 层按类型分流 toast。
sealed class GenerationError implements Exception {
  const GenerationError();
}

class MissingApiKeyError extends GenerationError {
  const MissingApiKeyError(this.providerId);
  final String providerId;
  @override
  String toString() => 'MissingApiKeyError(provider=$providerId)';
}

class InvalidGenerationConfigError extends GenerationError {
  const InvalidGenerationConfigError(this.reason);
  final String reason;
  @override
  String toString() => 'InvalidGenerationConfigError($reason)';
}

class ProviderNotRegisteredError extends GenerationError {
  const ProviderNotRegisteredError(this.providerId);
  final String providerId;
  @override
  String toString() => 'ProviderNotRegisteredError(provider=$providerId)';
}

class GenerationController {
  GenerationController({
    required this.nodes,
    required this.edges,
    required this.jobs,
    required this.secure,
    required this.queue,
    required this.registry,
    required this.resolver,
    required this.jobsRegistry,
  });

  final NodeRepository nodes;
  final EdgeRepository edges;
  final JobRepository jobs;
  final SecureStorageService secure;
  final JobQueueService queue;
  final ProviderRegistry registry;
  final FileResolverService resolver;
  final JobsRegistry jobsRegistry;

  /// 从 config 节点发起一次生成。fire-and-forget：提交成功即返回 jobId，
  /// 后台 [_track] 推进 JobsRegistry 状态机；终态结果由 registry listener 反映。
  Future<String> submitFromConfigNode(String configNodeId) async {
    final cfgRow = await nodes.findById(configNodeId);
    if (cfgRow == null) {
      throw const InvalidGenerationConfigError('config node not found');
    }
    if (cfgRow['node_role'] != 'config') {
      throw const InvalidGenerationConfigError('node is not a config node');
    }
    final nodeType = (cfgRow['type'] as String?) ?? 'image';
    if (nodeType != 'image' && nodeType != 'video') {
      throw const InvalidGenerationConfigError('unsupported node type');
    }
    final typeConfig = _readTypeConfig(cfgRow['type_config']);

    final prompt = (typeConfig['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      throw const InvalidGenerationConfigError('prompt is empty');
    }
    final providerId =
        (typeConfig['provider_id'] as String?) ?? kDefaultImageProviderId;
    if (!registry.contains(providerId)) {
      throw ProviderNotRegisteredError(providerId);
    }
    final resolution = _parseResolution(typeConfig['resolution']) ??
        Resolution.p1080;
    final aspect = _parseAspect(typeConfig['aspect_ratio']) ?? AspectRatio.r1x1;

    final apiKey = await secure.retrieve(
      SecureStorageKeys.providerApiKey(providerId),
    );
    if (apiKey == null || apiKey.isEmpty) {
      throw MissingApiKeyError(providerId);
    }

    final canvasId = cfgRow['canvas_id']!.toString();
    final projectId = cfgRow['project_id']?.toString();

    // 读入 data 连线作为参考图（PRD §8.2）。失败不阻断生成——refs 仍可为空。
    final refs = await _resolveRefImages(
      configNodeId: configNodeId,
      projectId: projectId,
      canvasId: canvasId,
    );

    // image / video 分流：mode 推断 + video 独有 duration / camera。
    final GenerationMode mode;
    int durationSeconds = 0;
    CameraMovement? cameraEnum;
    if (nodeType == 'video') {
      mode = refs.refImagePaths.isEmpty &&
              refs.firstFramePath == null &&
              refs.lastFramePath == null
          ? GenerationMode.textToVideo
          : GenerationMode.imageToVideo;
      final durMs = typeConfig['duration_ms'];
      if (durMs is int) durationSeconds = durMs ~/ 1000;
      final camRaw = typeConfig['camera'];
      if (camRaw is String) {
        for (final c in CameraMovement.values) {
          if (c.name == camRaw) cameraEnum = c;
        }
      }
    } else {
      mode = refs.refImagePaths.isEmpty
          ? GenerationMode.textToImage
          : GenerationMode.imageToImage;
    }

    // 预创建 result 节点（R2 路径调整：B-b3 落盘要求 resultNodeId 先在）。
    final resultNodeId = await nodes.create(
      canvasId: canvasId,
      type: nodeType,
      nodeRole: 'result',
      sourceNodeId: configNodeId,
    );

    try {
      final jobId = await jobs.create(
        canvasId: canvasId,
        sourceNodeId: configNodeId,
        resultNodeId: resultNodeId,
        providerId: providerId,
        jobType: nodeType,
        fullPrompt: prompt,
        userPrompt: prompt,
        parameters: <String, Object?>{
          'resolution': resolution.name,
          'aspect_ratio': aspect.name,
          if (durationSeconds > 0) 'duration_seconds': durationSeconds,
          if (cameraEnum != null) 'camera': cameraEnum.name,
          if (refs.refImagePaths.isNotEmpty)
            'ref_image_paths': refs.refImagePaths,
          if (refs.firstFramePath != null)
            'first_frame_path': refs.firstFramePath,
          if (refs.lastFramePath != null)
            'last_frame_path': refs.lastFramePath,
        },
      );

      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: mode,
        prompt: prompt,
        resolution: resolution,
        aspectRatio: aspect,
        durationSeconds: durationSeconds,
        camera: cameraEnum,
        refImagePaths: refs.refImagePaths,
        firstFramePath: refs.firstFramePath,
        lastFramePath: refs.lastFramePath,
      );

      final handle = await queue.submit(task);
      jobsRegistry.upsert(
        JobState.queued(
          jobId: jobId,
          providerId: providerId,
          canvasId: canvasId,
        ),
      );
      unawaited(_track(
        handle,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        providerId: providerId,
      ));
      return jobId;
    } catch (_) {
      // 预创建了 result 但下游挂了（jobs.create / queue.submit 等）——清孤儿。
      await nodes.softDelete(resultNodeId);
      rethrow;
    }
  }

  /// 后台跟踪一个已提交 job 的状态流 + 终态，推进 JobsRegistry。
  ///
  /// 不在 submitFromConfigNode 中 await——fire-and-forget。失败/取消时清理孤儿 result。
  Future<void> _track(
    JobHandle handle, {
    required String canvasId,
    required String resultNodeId,
    required String providerId,
  }) async {
    final sub = handle.status.listen((s) {
      if (s is JobInProgress) {
        jobsRegistry.upsert(
          JobState.running(
            jobId: handle.jobId,
            providerId: providerId,
            canvasId: canvasId,
            progress: s.progress,
          ),
        );
      }
    });
    try {
      final status = await handle.done;
      if (status is JobSuccess) {
        final path = await _readArtifactPath(resultNodeId);
        jobsRegistry.upsert(
          JobState.succeeded(
            jobId: handle.jobId,
            providerId: providerId,
            canvasId: canvasId,
            artifactPath: path,
          ),
        );
      } else if (status is JobFailure) {
        await nodes.softDelete(resultNodeId);
        if (status.error is CancelledError) {
          jobsRegistry.upsert(
            JobState.cancelled(
              jobId: handle.jobId,
              providerId: providerId,
              canvasId: canvasId,
            ),
          );
        } else {
          jobsRegistry.upsert(
            JobState.failed(
              jobId: handle.jobId,
              providerId: providerId,
              canvasId: canvasId,
              error: status.error,
            ),
          );
        }
      }
    } catch (e, st) {
      await nodes.softDelete(resultNodeId);
      jobsRegistry.upsert(
        JobState.failed(
          jobId: handle.jobId,
          providerId: providerId,
          canvasId: canvasId,
          error: UnknownError(cause: e, stackTrace: st),
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// 读 result 节点落盘后的相对路径（image_url / video_url）。
  Future<String> _readArtifactPath(String resultNodeId) async {
    final row = await nodes.findById(resultNodeId);
    final tc = _readTypeConfig(row?['type_config']);
    return (tc['image_url'] ?? tc['video_url'] ?? '').toString();
  }

  /// 读入 configNode 的所有 data 入连线，把源节点的 image_url 解析为绝对路径。
  ///
  /// 失败策略：单条边解析失败（源节点已删 / image_url 空 / PathSecurityError）静默跳过，
  /// 不影响其他边。projectId 为空时所有解析跳过（单测场景）。
  Future<_RefImages> _resolveRefImages({
    required String configNodeId,
    required String? projectId,
    required String canvasId,
  }) async {
    if (projectId == null) return const _RefImages.empty();
    final List<Map<String, Object?>> incoming;
    try {
      incoming = await edges.listIncoming(configNodeId);
    } catch (_) {
      return const _RefImages.empty();
    }

    final List<String> refs = [];
    String? firstFrame;
    String? lastFrame;

    for (final row in incoming) {
      if (row['edge_type'] != 'data') continue;
      final srcId = row['source_node_id']?.toString();
      if (srcId == null) continue;
      final role = row['role'] as String? ?? 'reference';

      final Map<String, Object?>? srcRow;
      try {
        srcRow = await nodes.findById(srcId);
      } catch (_) {
        continue;
      }
      if (srcRow == null) continue;

      final tc = _readTypeConfig(srcRow['type_config']);
      final relPath = tc['image_url'];
      if (relPath is! String || relPath.isEmpty) continue;

      final String absPath;
      try {
        absPath = resolver
            .resolve(
              projectId: projectId,
              canvasId: canvasId,
              relativePath: relPath,
            )
            .path;
      } catch (_) {
        continue;
      }

      switch (role) {
        case 'first_frame':
          firstFrame ??= absPath;
        case 'last_frame':
          lastFrame ??= absPath;
        default:
          refs.add(absPath);
      }
    }

    return _RefImages(
      refImagePaths: List.unmodifiable(refs),
      firstFramePath: firstFrame,
      lastFramePath: lastFrame,
    );
  }

  Map<String, Object?> _readTypeConfig(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, Object?>{};
  }

  Resolution? _parseResolution(Object? raw) {
    if (raw is String) {
      for (final r in Resolution.values) {
        if (r.name == raw) return r;
      }
    }
    return null;
  }

  AspectRatio? _parseAspect(Object? raw) {
    if (raw is String) {
      for (final a in AspectRatio.values) {
        if (a.name == raw) return a;
      }
    }
    return null;
  }
}

class _RefImages {
  const _RefImages({
    required this.refImagePaths,
    this.firstFramePath,
    this.lastFramePath,
  });
  const _RefImages.empty()
      : refImagePaths = const <String>[],
        firstFramePath = null,
        lastFramePath = null;
  final List<String> refImagePaths;
  final String? firstFramePath;
  final String? lastFramePath;
}
