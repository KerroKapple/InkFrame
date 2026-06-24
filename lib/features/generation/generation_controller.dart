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
import '../../core/di/logger.dart';
import '../../core/di/providers.dart';
import '../../core/di/repositories.dart';
import '../../core/di/secure_storage.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/canvas_repository.dart';
import '../../core/interfaces/edge_repository.dart';
import '../../core/interfaces/file_resolver_service.dart';
import '../../core/interfaces/job_queue_service.dart';
import '../../core/interfaces/job_repository.dart';
import '../../core/interfaces/node_repository.dart';
import '../../core/interfaces/secure_storage_service.dart';
import '../../core/interfaces/style_lane_repository.dart';
import '../../core/interfaces/unit_of_work.dart';
import '../../core/logging/logger_service.dart';
import '../../core/models/generation_task.dart';
import '../../core/models/job_status.dart';
import '../../core/models/provider_capabilities.dart';
import '../../core/interfaces/provider_registry.dart';
import 'models/job_state.dart';
import 'providers/jobs_registry.dart';
import 'services/prompt_assembler.dart';

final generationControllerProvider = FutureProvider<GenerationController>(
  (ref) async {
    final nodes = await ref.watch(nodeRepositoryProvider.future);
    final edges = await ref.watch(edgeRepositoryProvider.future);
    final jobs = await ref.watch(jobRepositoryProvider.future);
    final secure = ref.watch(secureStorageServiceProvider);
    final queue = await ref.watch(jobQueueServiceProvider.future);
    final registry = ref.watch(providerRegistryProvider);
    final resolver = ref.watch(fileResolverServiceProvider);
    final canvas = await ref.watch(canvasRepositoryProvider.future);
    final lanes = await ref.watch(styleLaneRepositoryProvider.future);
    final uow = await ref.watch(unitOfWorkProvider.future);
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
      canvas: canvas,
      lanes: lanes,
      uow: uow,
      jobsRegistry: jobsRegistry,
      logger: ref.watch(loggerProvider),
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
    required this.canvas,
    required this.lanes,
    required this.uow,
    required this.jobsRegistry,
    this.logger,
  });

  final NodeRepository nodes;
  final EdgeRepository edges;
  final JobRepository jobs;
  final SecureStorageService secure;
  final JobQueueService queue;
  final ProviderRegistry registry;
  final FileResolverService resolver;
  final CanvasRepository canvas;
  final StyleLaneRepository lanes;
  final UnitOfWork uow;
  final JobsRegistry jobsRegistry;
  final LoggerService? logger;

  static const String _logModule = 'generation.controller';

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

    final laneId = cfgRow['lane_id']?.toString();
    final ignoreLane = typeConfig['ignore_lane_style'] == true;
    final fullPrompt = await _assembleFullPrompt(
      userPrompt: prompt,
      canvasId: canvasId,
      configNodeId: configNodeId,
      laneId: laneId,
      ignoreLaneStyle: ignoreLane,
    );

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

    // 预创建 result 节点 + 建 job 行——单事务原子（任一失败整体回滚，不留半行）。
    final String resultNodeId;
    final String jobId;
    try {
      final created = await uow.run((scope) async {
        final rNode = await scope.nodes.create(
          canvasId: canvasId,
          type: nodeType,
          nodeRole: 'result',
          sourceNodeId: configNodeId,
        );
        final jId = await scope.jobs.create(
          canvasId: canvasId,
          sourceNodeId: configNodeId,
          resultNodeId: rNode,
          providerId: providerId,
          jobType: nodeType,
          fullPrompt: fullPrompt,
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
        return (rNode, jId);
      });
      resultNodeId = created.$1;
      jobId = created.$2;
    } catch (e, st) {
      // 创建事务失败 → 已回滚（无残留行），记日志后照常上抛。
      logger?.error(
        _logModule,
        'create result+job tx rolled back',
        extra: {'config_node_id': configNodeId, 'provider_id': providerId},
        cause: e,
        stackTrace: st,
      );
      rethrow;
    }

    try {
      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: mode,
        prompt: fullPrompt,
        resolution: resolution,
        aspectRatio: aspect,
        durationSeconds: durationSeconds,
        camera: cameraEnum,
        refImagePaths: refs.refImagePaths,
        firstFramePath: refs.firstFramePath,
        lastFramePath: refs.lastFramePath,
      );

      final handle = await queue.submit(task);
      logger?.info(_logModule, 'job submitted', extra: {
        'job_id': jobId,
        'provider_id': providerId,
        'mode': mode.name,
      });
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
    } catch (e, st) {
      // node+job 已提交，但 submit / registry 挂了——原子清掉两行，不留孤儿。
      logger?.error(
        _logModule,
        'submit rolled back: orphan result + job cleaned',
        extra: {
          'result_node_id': resultNodeId,
          'job_id': jobId,
          'provider_id': providerId,
        },
        cause: e,
        stackTrace: st,
      );
      try {
        await uow.run((scope) async {
          await scope.jobs.hardDelete(jobId);
          await scope.nodes.softDelete(resultNodeId);
        });
      } on InkError {
        // 补偿失败：保留原始错误语义，残留行交给孤儿回收/清理路径。
      }
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
          logger?.error(
            _logModule,
            'job failed',
            extra: {
              'job_id': handle.jobId,
              'provider_id': providerId,
              'error_code': status.error.code.wire,
            },
            cause: status.error,
          );
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
      logger?.error(
        _logModule,
        'job tracking crashed',
        extra: {'job_id': handle.jobId, 'provider_id': providerId},
        cause: e,
        stackTrace: st,
      );
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
    } catch (e) {
      logger?.warn(_logModule, 'listIncoming failed; refs skipped (swallowed)',
          extra: {'config_node_id': configNodeId, 'reason': e.toString()});
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
      } catch (e) {
        logger?.warn(_logModule, 'ref source lookup failed (swallowed)',
            extra: {'source_node_id': srcId, 'reason': e.toString()});
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
      } catch (e) {
        logger?.warn(_logModule, 'ref path resolve failed (swallowed)',
            extra: {'source_node_id': srcId, 'reason': e.toString()});
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

  /// PRD §7.4：组装 base前缀 + 泳道风格 + 关联文本 + userPrompt + base后缀。
  /// 任一查询失败降级（仅用 userPrompt），不阻断生成。
  Future<String> _assembleFullPrompt({
    required String userPrompt,
    required String canvasId,
    required String configNodeId,
    required String? laneId,
    required bool ignoreLaneStyle,
  }) async {
    var basePrefix = '';
    var baseSuffix = '';
    try {
      final c = await canvas.findById(canvasId);
      basePrefix = (c?['base_style_prefix'] as String?) ?? '';
      baseSuffix = (c?['base_style_suffix'] as String?) ?? '';
    } on InkError catch (_) {}
    var laneStyle = '';
    if (!ignoreLaneStyle && laneId != null) {
      try {
        final l = await lanes.findById(laneId);
        laneStyle = (l?['style_prompt'] as String?) ?? '';
      } on InkError catch (_) {}
    }
    final texts = await _resolveAssociatedTexts(configNodeId);
    return assemblePrompt(
      baseStylePrefix: basePrefix,
      laneStylePrompt: laneStyle,
      associatedTexts: texts,
      userPrompt: userPrompt,
      baseStyleSuffix: baseSuffix,
      ignoreLaneStyle: ignoreLaneStyle,
    );
  }

  /// 连入的 data 边里的文本节点内容，按 edge.created_at 升序。
  Future<List<String>> _resolveAssociatedTexts(String configNodeId) async {
    final List<Map<String, Object?>> incoming;
    try {
      incoming = await edges.listIncoming(configNodeId);
    } on InkError catch (_) {
      return const [];
    }
    final rows = incoming.where((r) => r['edge_type'] == 'data').toList()
      ..sort((a, b) => (a['created_at']?.toString() ?? '')
          .compareTo(b['created_at']?.toString() ?? ''));
    final out = <String>[];
    for (final r in rows) {
      final srcId = r['source_node_id']?.toString();
      if (srcId == null) continue;
      Map<String, Object?>? src;
      try {
        src = await nodes.findById(srcId);
      } on InkError catch (_) {
        continue;
      }
      if (src == null || src['type'] != 'text') continue;
      final tc = _readTypeConfig(src['type_config']);
      final text = (tc['text'] as String?)?.trim();
      final label = (src['label'] as String?)?.trim();
      final content = (text != null && text.isNotEmpty) ? text : (label ?? '');
      if (content.isNotEmpty) out.add(content);
    }
    return out;
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
