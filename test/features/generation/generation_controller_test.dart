// GenerationController 单测 —— 全 fake，不启 PG / 真 Provider。
//
// 覆盖：
//   - 参数校验（找不到 config / 非 config / 空 prompt / Provider 未注册）
//   - API Key 缺失
//   - 成功路径：预创建 result 节点 + jobs.create + queue.submit + 等 done
//   - 失败路径：JobHandle.done = failure → result 节点 softDelete
//   - 异常路径：jobs.create 抛错 → result 节点 softDelete + rethrow

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'dart:io';

import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/file_resolver_service.dart';

// ---- fakes ------------------------------------------------------------

class _FakeNodeRepo implements NodeRepository {
  final Map<String, Map<String, Object?>> rows = {};
  final List<Map<String, Object?>> creates = [];
  final List<String> softDeleted = [];
  int _idSeq = 0;

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    final id = 'n${++_idSeq}';
    creates.add({
      'id': id,
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'source_node_id': sourceNodeId,
    });
    rows[id] = {
      'id': id,
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'source_node_id': sourceNodeId,
      'type_config': typeConfig,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];
  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    rows.remove(id);
    return 1;
  }

  // 未使用接口
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async =>
      0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeJobRepo implements JobRepository {
  final List<Map<String, Object?>> creates = [];
  bool createThrows = false;

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
  }) async {
    if (createThrows) throw StateError('jobs.create boom');
    final id = 'j${creates.length + 1}';
    creates.add({
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'result_node_id': resultNodeId,
      'provider_id': providerId,
      'full_prompt': fullPrompt,
      'parameters': parameters,
    });
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> s) async => [];
  @override
  Future<List<Map<String, Object?>>> listDuePolling(int l) async => [];
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c, {int limit = 200}) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async => 0;
  @override
  Future<int> purgeExpired({required Duration retention}) async => 0;
  @override
  Future<int> purgePerCanvasCap({required int cap}) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeSecure implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<void> store(String k, String v) async => _data[k] = v;
  @override
  Future<String?> retrieve(String k) async => _data[k];
  @override
  Future<void> delete(String k) async => _data.remove(k);
  @override
  Future<bool> exists(String k) async => _data.containsKey(k);
}

class _FakeHandle implements JobHandle {
  _FakeHandle(this._jobId, this._statuses, this._done);
  final String _jobId;
  final List<JobStatus> _statuses;
  final JobStatus _done;
  @override
  String get jobId => _jobId;
  @override
  Stream<JobStatus> get status => Stream<JobStatus>.fromIterable(_statuses);
  // done 延后一个 microtask 完成，保证 status 流先 emit，再到终态——
  // 避免 fire-and-forget 下 JobRunning 事件因竞态丢失。
  @override
  Future<JobStatus> get done => Future<JobStatus>.microtask(() => _done);
}

class _FakeJobQueue implements JobQueueService {
  _FakeJobQueue(this.finalStatus);
  JobStatus finalStatus;
  GenerationTask? lastTask;
  @override
  Future<void> init() async {}
  @override
  Future<JobHandle> submit(GenerationTask task) async {
    lastTask = task;
    return _FakeHandle(
      task.jobId,
      const [JobStatus.inProgress(progress: 0.4)],
      finalStatus,
    );
  }
  @override
  Future<void> cancel(String jobId) async {}
  @override
  void dispose() {}
}

/// 记录所有 upsert 事件的 JobsRegistry——单测断言状态机推进序列。
///
/// Notifier 未挂到 ProviderContainer 时 `super.upsert` 会因 state 未初始化抛错，
/// 故仅记录 events，不调 super。
class _RecordingRegistry extends JobsRegistry {
  final List<JobState> events = [];
  @override
  void upsert(JobState job) {
    events.add(job);
  }
}

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = [];

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) async =>
      rows.where((r) => r['target_node_id'] == targetNodeId).toList();

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    final id = 'e${rows.length + 1}';
    rows.add({
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
    });
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c) async => [];
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeResolver implements FileResolverService {
  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('/fake/$projectId/$canvasId/$relativePath');
  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

// ---- tests ------------------------------------------------------------

void main() {
  const providerId = 'gemini-image';
  late _FakeNodeRepo nodes;
  late _FakeEdgeRepo edges;
  late _FakeJobRepo jobs;
  late _FakeSecure secure;
  late _FakeJobQueue queue;
  late ProviderRegistry registry;
  late _FakeResolver resolver;
  late _RecordingRegistry jobsRegistry;

  GenerationController buildCtrl() => GenerationController(
        nodes: nodes,
        edges: edges,
        jobs: jobs,
        secure: secure,
        queue: queue,
        registry: registry,
        resolver: resolver,
        jobsRegistry: jobsRegistry,
      );

  setUp(() {
    nodes = _FakeNodeRepo();
    edges = _FakeEdgeRepo();
    resolver = _FakeResolver();
    jobs = _FakeJobRepo();
    secure = _FakeSecure();
    queue = _FakeJobQueue(const JobStatus.success(remoteUrls: []));
    registry = ProviderRegistry({
      providerId: () => throw UnimplementedError('not called in tests'),
    });
    jobsRegistry = _RecordingRegistry();
  });

  Future<String> seedConfigNode({
    String prompt = 'a cat',
    String? providerIdOverride,
    String? projectId = 'proj-1',
  }) async {
    const id = 'cfg1';
    final typeConfig = <String, Object?>{'prompt': prompt};
    if (providerIdOverride != null) {
      typeConfig['provider_id'] = providerIdOverride;
    }
    nodes.rows[id] = {
      'id': id,
      'canvas_id': 'cvx',
      'project_id': projectId,
      'type': 'image',
      'node_role': 'config',
      'type_config': typeConfig,
    };
    return id;
  }

  void seedRefImageNode({
    required String id,
    required String imageUrl,
  }) {
    nodes.rows[id] = {
      'id': id,
      'canvas_id': 'cvx',
      'project_id': 'proj-1',
      'type': 'image',
      'node_role': 'result',
      'type_config': <String, Object?>{'image_url': imageUrl},
    };
  }

  void seedDataEdge({
    required String sourceId,
    required String targetId,
    String role = 'reference',
  }) {
    edges.rows.add({
      'id': 'e_${edges.rows.length + 1}',
      'canvas_id': 'cvx',
      'source_node_id': sourceId,
      'target_node_id': targetId,
      'edge_type': 'data',
      'role': role,
    });
  }

  test('成功路径（fire-and-forget）：立即返回 jobId，后台推进 queued→running→succeeded',
      () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );

    final jobId = await buildCtrl().submitFromConfigNode(cfg);

    // 同步契约：提交即返回非空 jobId + result 节点已预创建。
    expect(jobId, isNotEmpty);
    expect(nodes.creates, hasLength(1));
    expect(nodes.creates.first['node_role'], 'result');
    expect(nodes.creates.first['source_node_id'], cfg);
    expect(jobs.creates, hasLength(1));
    expect(
      jobs.creates.first['result_node_id'],
      nodes.creates.first['id'],
    );
    expect(queue.lastTask?.prompt, 'a cat');

    // 排空后台 _track future。
    await pumpEventQueue();

    final types = jobsRegistry.events.map((e) => e.runtimeType).toList();
    expect(types.first, JobQueued);
    expect(types, contains(JobRunning));
    expect(types.last, JobSucceeded);
    expect(nodes.softDeleted, isEmpty);
  });

  test('config 节点不存在 → InvalidGenerationConfigError', () async {
    expect(
      () => buildCtrl().submitFromConfigNode('missing'),
      throwsA(isA<InvalidGenerationConfigError>()),
    );
  });

  test('节点存在但不是 config → InvalidGenerationConfigError', () async {
    nodes.rows['r1'] = {
      'id': 'r1',
      'canvas_id': 'cvx',
      'type': 'image',
      'node_role': 'result',
      'type_config': const <String, Object?>{'prompt': 'x'},
    };
    expect(
      () => buildCtrl().submitFromConfigNode('r1'),
      throwsA(isA<InvalidGenerationConfigError>()),
    );
  });

  test('prompt 空 → InvalidGenerationConfigError', () async {
    final cfg = await seedConfigNode(prompt: '   ');
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk',
    );
    expect(
      () => buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<InvalidGenerationConfigError>()),
    );
    expect(nodes.creates, isEmpty,
        reason: '参数校验失败，不该创 result 节点');
  });

  test('未注册 Provider → ProviderNotRegisteredError', () async {
    final cfg = await seedConfigNode(providerIdOverride: 'nope');
    expect(
      () => buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<ProviderNotRegisteredError>()),
    );
    expect(nodes.creates, isEmpty);
  });

  test('API Key 未配置 → MissingApiKeyError，不创 result', () async {
    final cfg = await seedConfigNode();
    expect(
      () => buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<MissingApiKeyError>()),
    );
    expect(nodes.creates, isEmpty);
  });

  test('Provider 失败（done = failure）→ 末态 JobFailed + result 节点 softDelete',
      () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk',
    );
    queue.finalStatus = const JobStatus.failure(
      error: ProviderError(code: InkErrorCode.providerServer),
    );

    await buildCtrl().submitFromConfigNode(cfg);
    await pumpEventQueue();

    expect(jobsRegistry.events.last, isA<JobFailed>());
    expect(nodes.softDeleted, contains(nodes.creates.first['id']));
  });

  test('取消（done = failure，error 为 CancelledError）→ 末态 JobCancelled + softDelete',
      () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk',
    );
    queue.finalStatus = const JobStatus.failure(
      error: CancelledError.byUser(),
    );

    await buildCtrl().submitFromConfigNode(cfg);
    await pumpEventQueue();

    expect(jobsRegistry.events.last, isA<JobCancelled>());
    expect(nodes.softDeleted, contains(nodes.creates.first['id']));
  });

  test('jobs.create 抛错 → 预创建的 result 被清 + rethrow', () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk',
    );
    jobs.createThrows = true;

    await expectLater(
      buildCtrl().submitFromConfigNode(cfg),
      throwsStateError,
    );
    expect(nodes.softDeleted, hasLength(1));
  });

  group('data edge → refImagePaths', () {
    test('多条 reference data edge 聚合为 refImagePaths + mode=imageToImage',
        () async {
      final cfg = await seedConfigNode();
      await secure.store(
        SecureStorageKeys.providerApiKey(providerId),
        'sk',
      );
      seedRefImageNode(id: 'img1', imageUrl: 'images/a.png');
      seedRefImageNode(id: 'img2', imageUrl: 'images/b.png');
      seedDataEdge(sourceId: 'img1', targetId: cfg);
      seedDataEdge(sourceId: 'img2', targetId: cfg);

      await buildCtrl().submitFromConfigNode(cfg);
      final task = queue.lastTask!;
      expect(task.mode, GenerationMode.imageToImage);
      expect(task.refImagePaths, hasLength(2));
      expect(task.refImagePaths.first, contains('/proj-1/cvx/images/'));
    });

    test('first_frame / last_frame role 分流到独立字段', () async {
      final cfg = await seedConfigNode();
      await secure.store(
        SecureStorageKeys.providerApiKey(providerId),
        'sk',
      );
      seedRefImageNode(id: 'ff', imageUrl: 'images/first.png');
      seedRefImageNode(id: 'lf', imageUrl: 'images/last.png');
      seedRefImageNode(id: 'r1', imageUrl: 'images/ref.png');
      seedDataEdge(sourceId: 'ff', targetId: cfg, role: 'first_frame');
      seedDataEdge(sourceId: 'lf', targetId: cfg, role: 'last_frame');
      seedDataEdge(sourceId: 'r1', targetId: cfg);

      await buildCtrl().submitFromConfigNode(cfg);
      final task = queue.lastTask!;
      expect(task.firstFramePath, contains('images/first.png'));
      expect(task.lastFramePath, contains('images/last.png'));
      expect(task.refImagePaths, hasLength(1));
      expect(task.refImagePaths.first, contains('images/ref.png'));
    });

    test('源节点已删 / image_url 空 → 该边静默跳过', () async {
      final cfg = await seedConfigNode();
      await secure.store(
        SecureStorageKeys.providerApiKey(providerId),
        'sk',
      );
      // img1 有 url；img2 url 空；img3 不存在（FakeNodeRepo.findById 返回 null）
      seedRefImageNode(id: 'img1', imageUrl: 'images/ok.png');
      seedRefImageNode(id: 'img2', imageUrl: '');
      seedDataEdge(sourceId: 'img1', targetId: cfg);
      seedDataEdge(sourceId: 'img2', targetId: cfg);
      seedDataEdge(sourceId: 'img3-missing', targetId: cfg);

      await buildCtrl().submitFromConfigNode(cfg);
      final task = queue.lastTask!;
      expect(task.refImagePaths, hasLength(1));
    });

    test('projectId 为空（单测占位）→ 不解析 refImages', () async {
      final cfg = await seedConfigNode(projectId: null);
      await secure.store(
        SecureStorageKeys.providerApiKey(providerId),
        'sk',
      );
      seedRefImageNode(id: 'img1', imageUrl: 'images/a.png');
      seedDataEdge(sourceId: 'img1', targetId: cfg);

      await buildCtrl().submitFromConfigNode(cfg);
      final task = queue.lastTask!;
      expect(task.refImagePaths, isEmpty);
      expect(task.mode, GenerationMode.textToImage);
    });

    test('narrative / generation_source edge 不参与 refImages', () async {
      final cfg = await seedConfigNode();
      await secure.store(
        SecureStorageKeys.providerApiKey(providerId),
        'sk',
      );
      seedRefImageNode(id: 'img1', imageUrl: 'images/a.png');
      // narrative 不该被消费
      edges.rows.add({
        'id': 'e1',
        'canvas_id': 'cvx',
        'source_node_id': 'img1',
        'target_node_id': cfg,
        'edge_type': 'narrative',
        'role': 'reference',
      });

      await buildCtrl().submitFromConfigNode(cfg);
      expect(queue.lastTask!.refImagePaths, isEmpty);
      expect(queue.lastTask!.mode, GenerationMode.textToImage);
    });
  });
}
