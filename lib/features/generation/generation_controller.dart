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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/secure_storage_keys.dart';
import '../../core/di/job_queue.dart';
import '../../core/di/providers.dart';
import '../../core/di/repositories.dart';
import '../../core/di/secure_storage.dart';
import '../../core/interfaces/job_queue_service.dart';
import '../../core/interfaces/job_repository.dart';
import '../../core/interfaces/node_repository.dart';
import '../../core/interfaces/secure_storage_service.dart';
import '../../core/models/generation_task.dart';
import '../../core/models/job_status.dart';
import '../../core/models/provider_capabilities.dart';
import '../../providers/gemini_image_provider.dart';
import '../../providers/provider_registry.dart';

final generationControllerProvider = FutureProvider<GenerationController>(
  (ref) async {
    final nodes = await ref.watch(nodeRepositoryProvider.future);
    final jobs = await ref.watch(jobRepositoryProvider.future);
    final secure = ref.watch(secureStorageServiceProvider);
    final queue = ref.watch(jobQueueServiceProvider);
    final registry = ref.watch(providerRegistryProvider);
    return GenerationController(
      nodes: nodes,
      jobs: jobs,
      secure: secure,
      queue: queue,
      registry: registry,
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

/// 生成完成后返回的聚合句柄——UI 层按需读 resultNodeId / jobId。
class GenerationOutcome {
  const GenerationOutcome({
    required this.jobId,
    required this.resultNodeId,
    required this.status,
  });
  final String jobId;
  final String resultNodeId;
  final JobStatus status;
  bool get succeeded => status.isSuccess;
}

class GenerationController {
  GenerationController({
    required this.nodes,
    required this.jobs,
    required this.secure,
    required this.queue,
    required this.registry,
  });

  final NodeRepository nodes;
  final JobRepository jobs;
  final SecureStorageService secure;
  final JobQueueService queue;
  final ProviderRegistry registry;

  /// 从 config 节点发起一次文生图。阻塞到终态返回。
  Future<GenerationOutcome> submitFromConfigNode(String configNodeId) async {
    final cfgRow = await nodes.findById(configNodeId);
    if (cfgRow == null) {
      throw const InvalidGenerationConfigError('config node not found');
    }
    if (cfgRow['node_role'] != 'config') {
      throw const InvalidGenerationConfigError('node is not a config node');
    }
    final typeConfig = _readTypeConfig(cfgRow['type_config']);

    final prompt = (typeConfig['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      throw const InvalidGenerationConfigError('prompt is empty');
    }
    final providerId = (typeConfig['provider_id'] as String?) ??
        kGeminiImageCapabilities.providerId;
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

    // 预创建 result 节点（R2 路径调整：B-b3 落盘要求 resultNodeId 先在）。
    final resultNodeId = await nodes.create(
      canvasId: canvasId,
      type: 'image',
      nodeRole: 'result',
      sourceNodeId: configNodeId,
    );

    String? jobId;
    try {
      jobId = await jobs.create(
        canvasId: canvasId,
        sourceNodeId: configNodeId,
        resultNodeId: resultNodeId,
        providerId: providerId,
        jobType: 'image',
        fullPrompt: prompt,
        userPrompt: prompt,
        parameters: <String, Object?>{
          'resolution': resolution.name,
          'aspect_ratio': aspect.name,
        },
      );

      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: GenerationMode.textToImage,
        prompt: prompt,
        resolution: resolution,
        aspectRatio: aspect,
      );

      final handle = await queue.submit(task);
      final finalStatus = await handle.done;

      if (!finalStatus.isSuccess) {
        await nodes.softDelete(resultNodeId);
      }

      return GenerationOutcome(
        jobId: jobId,
        resultNodeId: resultNodeId,
        status: finalStatus,
      );
    } catch (_) {
      // 预创建了 result 但下游挂了（jobs.create / queue.submit 等）——清孤儿。
      await nodes.softDelete(resultNodeId);
      rethrow;
    }
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

extension on JobStatus {
  bool get isSuccess => maybeMap(
        success: (_) => true,
        orElse: () => false,
      );
}
