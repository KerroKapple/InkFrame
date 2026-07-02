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
import '../../core/db/columns.dart';
import '../../core/db/row_reader.dart';
import '../../core/di/character_assets.dart';
import '../../core/di/file_resolver.dart';
import '../../core/di/job_queue.dart';
import '../../core/di/logger.dart';
import '../../core/di/providers.dart';
import '../../core/di/repositories.dart';
import '../../core/di/secure_storage.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/batch_result_repository.dart';
import '../../core/interfaces/canvas_repository.dart';
import '../../core/interfaces/character_asset_service.dart';
import '../../core/interfaces/character_repository.dart';
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
import '../canvas/models/character.dart';
import 'models/job_state.dart';
import 'providers/jobs_registry.dart';
import 'services/prompt_assembler.dart';

final generationControllerProvider = FutureProvider<GenerationController>((
  ref,
) async {
  final nodes = await ref.watch(nodeRepositoryProvider.future);
  final edges = await ref.watch(edgeRepositoryProvider.future);
  final jobs = await ref.watch(jobRepositoryProvider.future);
  final secure = ref.watch(secureStorageServiceProvider);
  final queue = await ref.watch(jobQueueServiceProvider.future);
  final registry = ref.watch(providerRegistryProvider);
  final resolver = ref.watch(fileResolverServiceProvider);
  final canvas = await ref.watch(canvasRepositoryProvider.future);
  final lanes = await ref.watch(styleLaneRepositoryProvider.future);
  final characters = await ref.watch(characterRepositoryProvider.future);
  final characterAssets = ref.watch(characterAssetServiceProvider);
  final batchResults = await ref.watch(batchResultRepositoryProvider.future);
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
    characters: characters,
    characterAssets: characterAssets,
    batchResults: batchResults,
    uow: uow,
    jobsRegistry: jobsRegistry,
    logger: ref.watch(loggerProvider),
  );
}, name: 'generationControllerProvider');

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
    required this.characters,
    required this.characterAssets,
    required this.batchResults,
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
  final CharacterRepository characters;
  final CharacterAssetService characterAssets;
  final BatchResultRepository batchResults;
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
    if (cfgRow[NodeCol.nodeRole] != 'config') {
      throw const InvalidGenerationConfigError('node is not a config node');
    }
    final nodeType = cfgRow.optString(NodeCol.type) ?? 'image';
    if (nodeType != 'image' && nodeType != 'video') {
      throw const InvalidGenerationConfigError('unsupported node type');
    }
    final typeConfig = _readTypeConfig(cfgRow[NodeCol.typeConfig]);

    final prompt = (typeConfig['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      throw const InvalidGenerationConfigError('prompt is empty');
    }
    final providerId =
        (typeConfig['provider_id'] as String?) ?? kDefaultImageProviderId;
    if (!registry.contains(providerId)) {
      throw ProviderNotRegisteredError(providerId);
    }
    final resolution =
        _parseResolution(typeConfig['resolution']) ?? Resolution.p1080;
    final aspect = _parseAspect(typeConfig['aspect_ratio']) ?? AspectRatio.r1x1;
    final seed = typeConfig['seed'] is int ? typeConfig['seed'] as int : null;
    final negRaw = typeConfig['negative_prompt'];
    final negativePrompt = (negRaw is String && negRaw.trim().isNotEmpty)
        ? negRaw.trim()
        : null;
    final batchRaw = typeConfig['batch_size'];
    // 批量仅对图片节点生效：视频强制单张（数据层可构造 video+batch_size，此处收口）。
    final batchSize = (nodeType == 'image' && batchRaw is int && batchRaw > 0)
        ? batchRaw
        : 1;

    final apiKey = await secure.retrieve(
      SecureStorageKeys.providerApiKey(providerId),
    );
    if (apiKey == null || apiKey.isEmpty) {
      throw MissingApiKeyError(providerId);
    }

    final canvasId = cfgRow.reqId(NodeCol.canvasId);
    final projectId = cfgRow.optId(NodeCol.projectId);

    final laneId = cfgRow.optId(NodeCol.laneId);
    final ignoreLane = typeConfig['ignore_lane_style'] == true;
    // data 入连线取一次，参考图与关联文本共用，避免重复 listIncoming（评审 P1#5①）。
    final incoming = await _incomingEdges(configNodeId);
    final fullPrompt = await _assembleFullPrompt(
      userPrompt: prompt,
      canvasId: canvasId,
      incoming: incoming,
      laneId: laneId,
      ignoreLaneStyle: ignoreLane,
    );

    // 读入 data 连线作为参考图（PRD §8.2）。失败不阻断生成——refs 仍可为空。
    var refs = await _resolveRefImages(
      incoming: incoming,
      projectId: projectId,
      canvasId: canvasId,
    );
    // M2 角色一致性：图像节点按 provider 能力注入项目级角色参考图（不支持则原样返回）。
    refs = await _injectCharacterRefs(
      base: refs,
      typeConfig: typeConfig,
      nodeType: nodeType,
      providerId: providerId,
      projectId: projectId,
    );

    // image / video 分流：mode 推断 + video 独有 duration / camera。
    final GenerationMode mode;
    int durationSeconds = 0;
    CameraMovement? cameraEnum;
    if (nodeType == 'video') {
      mode =
          refs.refImagePaths.isEmpty &&
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
          batchSize: batchSize,
          parameters: <String, Object?>{
            'resolution': resolution.name,
            'aspect_ratio': aspect.name,
            if (durationSeconds > 0) 'duration_seconds': durationSeconds,
            if (cameraEnum != null) 'camera': cameraEnum.name,
            'seed': ?seed,
            'negative_prompt': ?negativePrompt,
            if (batchSize > 1) 'batch_size': batchSize,
            if (refs.refImagePaths.isNotEmpty)
              'ref_image_paths': refs.refImagePaths,
            if (refs.firstFramePath != null)
              'first_frame_path': refs.firstFramePath,
            if (refs.lastFramePath != null)
              'last_frame_path': refs.lastFramePath,
          },
        );
        // 批量：同事务预建 slot 占位行——消费侧网格立即可见 generating。
        // 失败补偿删 job 时 FK CASCADE 自动清 slot。
        if (batchSize > 1) {
          for (var i = 0; i < batchSize; i++) {
            await scope.batchResults.create(
              nodeId: rNode,
              jobId: jId,
              slotIndex: i,
              status: 'generating',
            );
          }
        }
        return (rNode, jId);
      });
      resultNodeId = created.$1;
      jobId = created.$2;
    } on InkError catch (e, st) {
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
        negativePrompt: negativePrompt,
        resolution: resolution,
        aspectRatio: aspect,
        durationSeconds: durationSeconds,
        camera: cameraEnum,
        refImagePaths: refs.refImagePaths,
        firstFramePath: refs.firstFramePath,
        lastFramePath: refs.lastFramePath,
        seed: seed,
        batchSize: batchSize,
      );

      final handle = await queue.submit(task);
      logger?.info(
        _logModule,
        'job submitted',
        extra: {'job_id': jobId, 'provider_id': providerId, 'mode': mode.name},
      );
      jobsRegistry.upsert(
        JobState.queued(
          jobId: jobId,
          providerId: providerId,
          canvasId: canvasId,
          sourceNodeId: configNodeId,
          resultNodeId: resultNodeId,
        ),
      );
      unawaited(
        _track(
          handle,
          canvasId: canvasId,
          resultNodeId: resultNodeId,
          providerId: providerId,
          sourceNodeId: configNodeId,
          batchSize: batchSize,
        ),
      );
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
      // 补偿：清 result + job；DB 抖动给一次重试，仍失败则交给孤儿回收（评审 P1#6）。
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          await uow.run((scope) async {
            await scope.jobs.hardDelete(jobId);
            await scope.nodes.softDelete(resultNodeId);
          });
          break;
        } on InkError catch (cleanupErr) {
          logger?.warn(
            _logModule,
            'orphan cleanup attempt failed',
            extra: {
              'attempt': attempt,
              'job_id': jobId,
              'reason': cleanupErr.toString(),
            },
          );
          // 2 次用尽后不再抛——保留原始错误语义（下方 rethrow）。
        }
      }
      rethrow;
    }
  }

  /// 后台跟踪一个已提交 job 的状态流 + 终态，推进 JobsRegistry。
  ///
  /// 不在 submitFromConfigNode 中 await——fire-and-forget。失败时清理孤儿 result；
  /// 取消时批量 job 若已有 success slot 则保留结果节点（用户仍能看到成功产物）。
  Future<void> _track(
    JobHandle handle, {
    required String canvasId,
    required String resultNodeId,
    required String providerId,
    required String sourceNodeId,
    required int batchSize,
  }) async {
    final sub = handle.status.listen((s) {
      if (s is JobInProgress) {
        jobsRegistry.upsert(
          JobState.running(
            jobId: handle.jobId,
            providerId: providerId,
            canvasId: canvasId,
            sourceNodeId: sourceNodeId,
            resultNodeId: resultNodeId,
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
            sourceNodeId: sourceNodeId,
            resultNodeId: resultNodeId,
            artifactPath: path,
          ),
        );
      } else if (status is JobFailure) {
        if (status.error is CancelledError) {
          // 取消保留语义：批量下已有 success slot 的结果节点不软删。
          final keep = batchSize > 1 && await _hasSuccessSlot(resultNodeId);
          if (!keep) {
            await nodes.softDelete(resultNodeId);
          }
          jobsRegistry.upsert(
            JobState.cancelled(
              jobId: handle.jobId,
              providerId: providerId,
              canvasId: canvasId,
              sourceNodeId: sourceNodeId,
              resultNodeId: resultNodeId,
            ),
          );
        } else {
          await nodes.softDelete(resultNodeId);
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
              sourceNodeId: sourceNodeId,
              resultNodeId: resultNodeId,
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
          sourceNodeId: sourceNodeId,
          resultNodeId: resultNodeId,
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

  /// 取消收敛时判定 result 节点下是否已有 success slot。
  /// 查询失败按「有」处理——宁保留节点，也不误删用户已见的成功产物。
  Future<bool> _hasSuccessSlot(String resultNodeId) async {
    try {
      final slots = await batchResults.listByNode(resultNodeId);
      return slots.any((r) => r[BatchResultCol.status] == 'success');
    } on InkError catch (e) {
      logger?.warn(
        _logModule,
        'batch slot lookup failed; keeping result node (swallowed)',
        extra: {'result_node_id': resultNodeId, 'reason': e.toString()},
      );
      return true;
    }
  }

  /// configNode 的 data 入连线取一次（refs + associatedTexts 共用）；失败 warn + 空。
  Future<List<Map<String, Object?>>> _incomingEdges(String configNodeId) async {
    try {
      return await edges.listIncoming(configNodeId);
    } on InkError catch (e) {
      logger?.warn(
        _logModule,
        'listIncoming failed; refs+texts skipped (swallowed)',
        extra: {'config_node_id': configNodeId, 'reason': e.toString()},
      );
      return const [];
    }
  }

  /// 从给定 data 入连线把源节点 image_url 解析为绝对路径。
  ///
  /// 失败策略：单条边解析失败（源节点已删 / image_url 空 / 路径不安全）静默跳过，
  /// 不影响其他边。projectId 为空时所有解析跳过（单测场景）。
  Future<_RefImages> _resolveRefImages({
    required List<Map<String, Object?>> incoming,
    required String? projectId,
    required String canvasId,
  }) async {
    if (projectId == null) return const _RefImages.empty();

    final List<String> refs = [];
    String? firstFrame;
    String? lastFrame;
    var failedResolves = 0;

    for (final row in incoming) {
      if (row[EdgeCol.edgeType] != 'data') continue;
      final srcId = row.optId(EdgeCol.sourceNodeId);
      if (srcId == null) continue;
      final role = row.optString(EdgeCol.role) ?? 'reference';

      final Map<String, Object?>? srcRow;
      try {
        srcRow = await nodes.findById(srcId);
      } catch (e) {
        logger?.warn(
          _logModule,
          'ref source lookup failed (swallowed)',
          extra: {'source_node_id': srcId, 'reason': e.toString()},
        );
        continue;
      }
      if (srcRow == null) continue;

      final tc = _readTypeConfig(srcRow[NodeCol.typeConfig]);
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
        failedResolves++;
        logger?.warn(
          _logModule,
          'ref path resolve failed (swallowed)',
          extra: {'source_node_id': srcId, 'reason': e.toString()},
        );
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

    // 有参考图候选但全部解析失败 → 上层会静默退化为 t2i/t2v，显式 warn（评审 P1#6）。
    if (failedResolves > 0 &&
        refs.isEmpty &&
        firstFrame == null &&
        lastFrame == null) {
      logger?.warn(
        _logModule,
        'all ref images failed to resolve; generation degraded to text-only',
        extra: {'failed_count': failedResolves},
      );
    }

    return _RefImages(
      refImagePaths: List.unmodifiable(refs),
      firstFramePath: firstFrame,
      lastFramePath: lastFrame,
    );
  }

  /// M2 角色一致性：把 config 节点挂接的项目级角色参考图并进 refImagePaths。
  ///
  /// 门控（缺一即原样返回 base，绝不误翻 mode / 破坏文生图）：
  ///   - 仅 image 节点（video 的 i2v 走首/尾帧语义，v1 不覆盖）；
  ///   - projectId 非空；
  ///   - config.type_config['character_ids'] 非空；
  ///   - provider 声明 maxRefImages>0 且支持 imageToImage。
  /// 合并去重后按 maxRefImages 截断（边连参考图优先，角色图补足）。
  /// 角色查不到 / 资产文件缺失静默跳过，不阻断生成。
  Future<_RefImages> _injectCharacterRefs({
    required _RefImages base,
    required Map<String, Object?> typeConfig,
    required String nodeType,
    required String providerId,
    required String? projectId,
  }) async {
    if (nodeType != 'image' || projectId == null) return base;
    final ids = _readCharacterIds(typeConfig);
    if (ids.isEmpty) return base;

    final caps = registry.get(providerId).capabilities;
    if (caps.maxRefImages <= 0 ||
        !caps.modes.contains(GenerationMode.imageToImage)) {
      return base;
    }

    final relPaths = <String>[];
    for (final id in ids) {
      Map<String, Object?>? row;
      try {
        row = await characters.findById(id);
      } on InkError catch (e) {
        logger?.warn(
          _logModule,
          'character lookup failed (swallowed)',
          extra: {'character_id': id, 'reason': e.toString()},
        );
        continue;
      }
      if (row == null) continue;
      relPaths.addAll(Character.fromRow(row).referenceImagePaths);
    }
    if (relPaths.isEmpty) return base;

    // resolveExisting 为非抛设计（服务内逐条吞掉缺文件/越权），无需外层 catch。
    final extraAbs = await characterAssets.resolveExisting(
      projectId: projectId,
      relativePaths: relPaths,
    );
    if (extraAbs.isEmpty) return base;

    // 合并去重（边连参考图在前，角色图补足）。不在此截断 maxRefImages——与边连参考图
    // 一致，由 provider 自身 take(maxRefImages) 收口，避免"有无角色决定是否截断"的不一致
    // （评审 #1）。
    final merged = <String>[...base.refImagePaths];
    for (final abs in extraAbs) {
      if (!merged.contains(abs)) merged.add(abs);
    }
    return _RefImages(
      refImagePaths: List.unmodifiable(merged),
      firstFramePath: base.firstFramePath,
      lastFramePath: base.lastFramePath,
    );
  }

  List<String> _readCharacterIds(Map<String, Object?> typeConfig) {
    final raw = typeConfig['character_ids'];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  /// PRD §7.4：组装 base前缀 + 泳道风格 + 关联文本 + userPrompt + base后缀。
  /// 任一查询失败降级（仅用 userPrompt），不阻断生成。
  Future<String> _assembleFullPrompt({
    required String userPrompt,
    required String canvasId,
    required List<Map<String, Object?>> incoming,
    required String? laneId,
    required bool ignoreLaneStyle,
  }) async {
    var basePrefix = '';
    var baseSuffix = '';
    try {
      final c = await canvas.findById(canvasId);
      basePrefix = c?.optString(CanvasCol.baseStylePrefix) ?? '';
      baseSuffix = c?.optString(CanvasCol.baseStyleSuffix) ?? '';
    } on InkError catch (e) {
      logger?.warn(
        _logModule,
        'base style lookup failed; degraded to empty (swallowed)',
        extra: {'canvas_id': canvasId, 'reason': e.toString()},
      );
    }
    var laneStyle = '';
    if (!ignoreLaneStyle && laneId != null) {
      try {
        final l = await lanes.findById(laneId);
        laneStyle = l?.optString(StyleLaneCol.stylePrompt) ?? '';
      } on InkError catch (e) {
        logger?.warn(
          _logModule,
          'lane style lookup failed; degraded to empty (swallowed)',
          extra: {'lane_id': laneId, 'reason': e.toString()},
        );
      }
    }
    final texts = await _resolveAssociatedTexts(incoming);
    return assemblePrompt(
      baseStylePrefix: basePrefix,
      laneStylePrompt: laneStyle,
      associatedTexts: texts,
      userPrompt: userPrompt,
      baseStyleSuffix: baseSuffix,
      ignoreLaneStyle: ignoreLaneStyle,
    );
  }

  /// 给定 data 入连线里的文本节点内容，按 edge.created_at 升序。
  Future<List<String>> _resolveAssociatedTexts(
    List<Map<String, Object?>> incoming,
  ) async {
    final rows = incoming.where((r) => r[EdgeCol.edgeType] == 'data').toList()
      ..sort(
        (a, b) => (a[EdgeCol.createdAt]?.toString() ?? '').compareTo(
          b[EdgeCol.createdAt]?.toString() ?? '',
        ),
      );
    final out = <String>[];
    for (final r in rows) {
      final srcId = r.optId(EdgeCol.sourceNodeId);
      if (srcId == null) continue;
      Map<String, Object?>? src;
      try {
        src = await nodes.findById(srcId);
      } on InkError catch (_) {
        continue;
      }
      if (src == null || src[NodeCol.type] != 'text') continue;
      final tc = _readTypeConfig(src[NodeCol.typeConfig]);
      final text = (tc['text'] as String?)?.trim();
      final label = src.optString(NodeCol.label)?.trim();
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
