// E2E 主链路集成测试（ROAD-TO-BETA DoD-5）：生成 → 落盘 → 渲染。
//
// 用真实生产装配把一条贯穿用例串起来，只在边缘用 fake：
//   - 真：InMemoryJobQueueService（状态机 + 落盘 + type_config 回写）
//        DefaultFileResolverService + DefaultAppPaths.forRoot(tmp)（真实磁盘写）
//        InMemoryNodeRepository（harness，真 patchTypeConfig 回写语义）
//        ProviderRegistry（真 LSP 校验）
//   - fake：provider（脚本化产物）、内存 JobRepository（驱动 pending→success 状态机）、临时目录
//   不碰真实网络、不起 embedded PG、不需要 API key。
//
// 分两支共同覆盖链路（widget 装配过重，渲染断言拆出去）：
//   支1（本文件）：fake provider 产物 → JobQueueService.submit → job 走终态
//                 → 产物经 FileResolverService 落到临时目录
//                 → node.type_config 写入相对 image_url（断言文件存在 + repo 记录更新）
//   支2：generation_render_node_e2e_test.dart —— 节点渲染已落盘产物的 widget 测试。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/job_queue_service.dart';
import 'package:path/path.dart' as p;

import '../_harness/fake_providers.dart';
import '../_harness/fake_repositories.dart';

// ---- 边缘 fake：内存 JobRepository --------------------------------------
// harness 暂无 JobRepository 内存件；这里建最小实现，只覆盖 JobQueueService
// 实际调用的方法（status 状态机 + update），其余未用方法抛 UnimplementedError。
// 状态机语义与真 PG 实现一致：transitionStatus 校验 from 集合后才跃迁。

class _InMemoryJobRepository implements JobRepository {
  final Map<String, Map<String, Object?>> rows = <String, Map<String, Object?>>{};

  /// 预置一条 status='pending' 的行（GenerationController 真实路径里由 create 写入，
  /// 本支直接驱动 JobQueueService，故手动 seed）。
  void seedPending(String id) {
    rows[id] = <String, Object?>{'id': id, 'status': 'pending'};
  }

  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final row = rows[id];
    if (row == null) return 0;
    final cur = row['status'] as String?;
    if (cur == null || !fromStatuses.contains(cur)) return 0;
    row['status'] = toStatus;
    row.addAll(extra);
    return 1;
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    final row = rows[id];
    if (row == null) return 0;
    row.addAll(patch);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> statuses) async {
    return rows.values
        .where((r) => statuses.contains(r['status']))
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];

  // ---- 本链路未触达的方法 ------------------------------------------------
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    String? resultNodeId,
    required String providerId,
    required String jobType,
    required String fullPrompt,
    required String userPrompt,
    Map<String, Object?> parameters = const <String, Object?>{},
    int batchSize = 1,
    int maxRetries = 3,
    DateTime? timeoutAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId, {int limit = 200}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> listDuePolling(int limit) =>
      throw UnimplementedError();

  @override
  Future<int> purgeExpired({required Duration retention}) =>
      throw UnimplementedError();

  @override
  Future<int> purgePerCanvasCap({required int cap}) =>
      throw UnimplementedError();

  @override
  Future<int> hardDelete(String id) => throw UnimplementedError();
}

// ---- 边缘 fake：同步 image provider（inlineBytes 产物）---------------------
// 复用 harness 的 FakeProvider，脚本化 poll：一次 inProgress，再 success(inlineBytes)。
// 走 inlineBytes 即"同步 provider"路径，等价 Gemini Image，无需任何网络下载。

FakeProvider _inlineBytesProvider({
  required String providerId,
  required Uint8List bytes,
}) {
  var pollCalls = 0;
  return FakeProvider(
    capabilities: fakeImageCapabilities(
      id: providerId,
      supportsPolling: true,
      maxConcurrentJobs: 2,
    ),
    onPoll: (_) async {
      pollCalls++;
      if (pollCalls == 1) {
        return const JobStatus.inProgress(progress: 0.5);
      }
      return JobStatus.success(remoteUrls: const <String>[], inlineBytes: [bytes]);
    },
  );
}

InMemoryJobQueueService _buildQueue(
  ProviderRegistry registry, {
  required JobRepository repo,
  required FileResolverService fileResolver,
  required InMemoryNodeRepository nodeRepo,
}) {
  return InMemoryJobQueueService(
    registry: registry,
    repo: repo,
    fileResolver: fileResolver,
    nodeRepo: nodeRepo,
    globalConcurrency: 2,
    // 收紧轮询间隔让测试快速走完，行为不变。
    pollInitialInterval: const Duration(milliseconds: 1),
    pollMaxInterval: const Duration(milliseconds: 5),
    pollBackoffMultiplier: 1.0,
    pollTimeout: const Duration(seconds: 5),
  );
}

void main() {
  const providerId = 'gemini-image';
  const projectId = 'proj-e2e';
  const canvasId = 'canvas-e2e';
  const jobId = 'job-e2e-1';

  late Directory tmp;
  late FileResolverService fileResolver;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_e2e_pipeline_');
    fileResolver = DefaultFileResolverService(DefaultAppPaths.forRoot(tmp));
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    '主链路：生成→落盘→type_config 持久化（inlineBytes 同步 provider）',
    () async {
      // PNG 魔数头 + 任意尾字节，断言落盘字节一致。
      final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x42]);

      // result 节点预创建（真实路径由 GenerationController 先建；本支直接建在 node repo）。
      final nodeRepo = InMemoryNodeRepository();
      final resultNodeId = await nodeRepo.create(
        canvasId: canvasId,
        type: 'image',
        nodeRole: 'result',
      );
      // 预创建后 type_config 应为空——尚无产物。
      expect(
        (nodeRepo.rows[resultNodeId]!['type_config'] as Map)['image_url'],
        isNull,
      );

      final jobRepo = _InMemoryJobRepository()..seedPending(jobId);
      final provider = _inlineBytesProvider(providerId: providerId, bytes: bytes);
      final registry = CachingProviderRegistry({providerId: () => provider});

      final queue = _buildQueue(
        registry,
        repo: jobRepo,
        fileResolver: fileResolver,
        nodeRepo: nodeRepo,
      );

      // —— 步骤1：submit 真实 GenerationTask 到真实 JobQueueService ——
      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: projectId,
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: GenerationMode.textToImage,
        prompt: 'a tranquil ink landscape',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r1x1,
      );
      final handle = await queue.submit(task);

      // —— 步骤2：job 走到终态 success ——
      final terminal = await handle.done;
      expect(terminal, isA<JobSuccess>(),
          reason: 'fake provider 返回 inlineBytes success，job 应到 success 终态');

      // provider 真被调用（submit 1 次，poll 至少 2 次：inProgress + success）。
      expect(provider.submitCallCount, 1);
      expect(provider.pollCallCount, greaterThanOrEqualTo(2));

      // —— 步骤3：产物经 FileResolverService 落到临时目录 ——
      // 落盘相对路径契约：images/{jobId}-{idx}.png（见 JobQueueService._persistInlineBytes）。
      const relPath = 'images/$jobId-0.png';
      final landed = File(p.join(
        tmp.path, 'projects', projectId, 'canvases', canvasId, 'images', '$jobId-0.png',
      ));
      expect(landed.existsSync(), isTrue,
          reason: '产物字节应已落到 canvas/images 临时目录');
      expect(landed.readAsBytesSync(), bytes,
          reason: '落盘字节必须与 provider 返回的 inlineBytes 完全一致');
      // 落盘路径必须可被 FileResolver 用相对路径解析回同一绝对路径（往返一致）。
      final resolvedBack = fileResolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relPath,
      );
      expect(p.equals(resolvedBack.path, landed.path), isTrue);

      // —— 步骤4：node.type_config 写入相对 image_url（DB/repo 记录更新）——
      final updatedNode = await nodeRepo.findById(resultNodeId);
      final typeConfig = updatedNode!['type_config'] as Map<String, Object?>;
      expect(typeConfig['image_url'], relPath,
          reason: 'type_config.image_url 必须是 canvas 相对路径，不是绝对路径');
      expect(p.isAbsolute(typeConfig['image_url'] as String), isFalse);

      // —— 步骤5：jobs 记录达终态 success（持久化状态机闭环）——
      expect(jobRepo.rows[jobId]!['status'], 'success');
      expect(jobRepo.rows[jobId]!['completed_at'], isNotNull);
      expect(jobRepo.rows[jobId]!['remote_task_id'], isNotNull,
          reason: 'submit 返回的 providerJobId 应已写库');

      queue.dispose();
    },
  );

  test(
    '失败链路：落盘越界（projectId 含 ..）→ JobFailure(LocalIOError)，不写 image_url',
    () async {
      // 守住链路负向不变量：落盘失败必须冒泡为终态 failure，type_config 不被污染。
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);
      final nodeRepo = InMemoryNodeRepository();
      final resultNodeId = await nodeRepo.create(
        canvasId: canvasId,
        type: 'image',
        nodeRole: 'result',
      );

      const badProjectId = '..escape';
      final jobRepo = _InMemoryJobRepository()..seedPending(jobId);
      final provider = _inlineBytesProvider(providerId: providerId, bytes: bytes);
      final registry = CachingProviderRegistry({providerId: () => provider});
      final queue = _buildQueue(
        registry,
        repo: jobRepo,
        fileResolver: fileResolver,
        nodeRepo: nodeRepo,
      );

      final task = GenerationTask(
        providerId: providerId,
        jobId: jobId,
        projectId: badProjectId, // FileResolver 会拒绝带 .. 的 segment
        canvasId: canvasId,
        resultNodeId: resultNodeId,
        mode: GenerationMode.textToImage,
        prompt: 'x',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r1x1,
      );

      final terminal = await (await queue.submit(task)).done;

      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error.code, InkErrorCode.localIOError);
      // 落盘失败 → type_config 不该出现 image_url。
      final node = await nodeRepo.findById(resultNodeId);
      expect((node!['type_config'] as Map)['image_url'], isNull);
      // jobs 记录也落到 error 终态。
      expect(jobRepo.rows[jobId]!['status'], 'error');
      expect(jobRepo.rows[jobId]!['error_code'], InkErrorCode.localIOError.wire);

      queue.dispose();
    },
  );
}
