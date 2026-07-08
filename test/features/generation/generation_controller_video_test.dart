// GenerationController video 分支测试：
//   - video config 节点提交 → resultNode.type == 'video'
//   - 无 data edge → task.mode == textToVideo
//   - 有 reference data edge → task.mode == imageToVideo
//   - duration_ms / camera 从 typeConfig 映射到 GenerationTask

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_character.dart';
import '../../_harness/fake_providers.dart';
import '../../_harness/fake_unit_of_work.dart';

// ---- fakes ------------------------------------------------------------

class _FakeNodeRepo implements NodeRepository {
  final Map<String, Map<String, Object?>> rows = {};
  final List<Map<String, Object?>> creates = [];
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
    rows.remove(id);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      [];
  @override
  Future<int> softDeleteEmptyOrphanResults() async => 0;
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
    final id = 'j${creates.length + 1}';
    creates.add({
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'result_node_id': resultNodeId,
      'provider_id': providerId,
      'job_type': jobType,
      'parameters': parameters,
    });
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> s) async => [];
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
  Future<int> bulkTransition({
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async =>
      0;
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
  @override
  Future<JobStatus> get done => Future<JobStatus>.microtask(() => _done);
}

class _FakeJobQueue implements JobQueueService {
  JobStatus finalStatus = const JobStatus.success(remoteUrls: []);
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
  }) =>
      throw UnimplementedError();
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

class _FakeCanvasRepo implements CanvasRepository {
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<String> create({required String projectId, required String name, String baseStylePrefix = '', String baseStyleSuffix = ''}) async => '';
  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async => [];
  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeLaneRepo implements StyleLaneRepository {
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<String> create({required String canvasId, String label = '', String stylePrompt = '', int sortOrder = 0, String? tintColor, double size = 400.0}) async => '';
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
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
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

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
  const providerId = 'wanx-t2v';
  late _FakeNodeRepo nodes;
  late _FakeEdgeRepo edges;
  late _FakeJobRepo jobs;
  late _FakeSecure secure;
  late _FakeJobQueue queue;
  late ProviderRegistry registry;
  late _FakeResolver resolver;
  late _FakeCanvasRepo canvasRepo;
  late _FakeLaneRepo laneRepo;
  late _RecordingRegistry jobsRegistry;

  GenerationController buildCtrl() => GenerationController(
        nodes: nodes,
        edges: edges,
        jobs: jobs,
        secure: secure,
        queue: queue,
        registry: registry,
        resolver: resolver,
        canvas: canvasRepo,
        lanes: laneRepo,
        characters: FakeCharacterRepo(),
        characterAssets: FakeCharacterAssetService(),
        batchResults: FakeBatchResultRepo(),
        uow: FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, jobs: jobs)),
        jobsRegistry: jobsRegistry,
      );

  setUp(() {
    nodes = _FakeNodeRepo();
    edges = _FakeEdgeRepo();
    resolver = _FakeResolver();
    jobs = _FakeJobRepo();
    secure = _FakeSecure();
    queue = _FakeJobQueue();
    registry = CachingProviderRegistry({
      providerId: () => throw UnimplementedError('not called in tests'),
    });
    canvasRepo = _FakeCanvasRepo();
    laneRepo = _FakeLaneRepo();
    jobsRegistry = _RecordingRegistry();
  });

  Future<String> seedVideoConfigNode({
    String prompt = 'a flying cat',
    int? durationMs,
    String? camera,
  }) async {
    const id = 'cfgV';
    final typeConfig = <String, Object?>{
      'prompt': prompt,
      'provider_id': providerId,
    };
    if (durationMs != null) typeConfig['duration_ms'] = durationMs;
    if (camera != null) typeConfig['camera'] = camera;
    nodes.rows[id] = {
      'id': id,
      'canvas_id': 'cvx',
      'project_id': 'proj-1',
      'type': 'video',
      'node_role': 'config',
      'type_config': typeConfig,
    };
    return id;
  }

  void seedRefImageNode({required String id, required String imageUrl}) {
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

  test('video config + 无 data edge → resultNode.type=video + mode=textToVideo',
      () async {
    final cfg = await seedVideoConfigNode(
      durationMs: 5000,
      camera: 'pushIn',
    );
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );

    await buildCtrl().submitFromConfigNode(cfg);

    // 预创建 result 节点 type 必须是 video
    expect(nodes.creates, hasLength(1));
    expect(nodes.creates.first['type'], 'video');
    expect(nodes.creates.first['node_role'], 'result');

    // job_type 透传 video
    expect(jobs.creates, hasLength(1));
    expect(jobs.creates.first['job_type'], 'video');

    // task.mode / durationSeconds / camera
    final task = queue.lastTask!;
    expect(task.mode, GenerationMode.textToVideo);
    expect(task.durationSeconds, 5);
    expect(task.camera, CameraMovement.pushIn);
  });

  test('video config + reference data edge → mode=imageToVideo', () async {
    final cfg = await seedVideoConfigNode(durationMs: 10000);
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );
    seedRefImageNode(id: 'img1', imageUrl: 'images/a.png');
    seedDataEdge(sourceId: 'img1', targetId: cfg);

    await buildCtrl().submitFromConfigNode(cfg);

    final task = queue.lastTask!;
    expect(task.mode, GenerationMode.imageToVideo);
    expect(task.refImagePaths, hasLength(1));
    expect(task.durationSeconds, 10);
    // 未提供 camera → null
    expect(task.camera, isNull);
  });

  /// 注册带首/尾帧能力位的 fake video provider（帧能力校验经 registry.get 读取）。
  void useVideoProvider({bool first = false, bool last = false}) {
    registry = CachingProviderRegistry({
      providerId: () => FakeProvider(
        capabilities: fakeVideoCapabilities(
          id: providerId,
          modes: const <GenerationMode>[
            GenerationMode.textToVideo,
            GenerationMode.imageToVideo,
          ],
          supportsFirstFrame: first,
          supportsLastFrame: last,
        ),
      ),
    });
  }

  test('video config + first_frame data edge → mode=imageToVideo', () async {
    useVideoProvider(first: true);
    final cfg = await seedVideoConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );
    seedRefImageNode(id: 'ff', imageUrl: 'images/first.png');
    seedDataEdge(sourceId: 'ff', targetId: cfg, role: 'first_frame');

    await buildCtrl().submitFromConfigNode(cfg);

    final task = queue.lastTask!;
    expect(task.mode, GenerationMode.imageToVideo);
    expect(task.firstFramePath, contains('images/first.png'));
  });

  test('provider 不支持首帧 + first_frame 边 → InvalidGenerationConfigError，无副作用', () async {
    useVideoProvider(); // supportsFirstFrame: false
    final cfg = await seedVideoConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );
    seedRefImageNode(id: 'ff', imageUrl: 'images/first.png');
    seedDataEdge(sourceId: 'ff', targetId: cfg, role: 'first_frame');

    await expectLater(
      buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<InvalidGenerationConfigError>().having(
        (e) => e.reason,
        'reason',
        'first_frame_unsupported',
      )),
    );
    // fail-fast：不留半行（result 节点 / job 都不建）。
    expect(nodes.creates, isEmpty);
    expect(jobs.creates, isEmpty);
  });

  test('provider 不支持尾帧 + last_frame 边 → InvalidGenerationConfigError（不静默丢）', () async {
    useVideoProvider(first: true); // supportsLastFrame: false
    final cfg = await seedVideoConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );
    seedRefImageNode(id: 'lf', imageUrl: 'images/last.png');
    seedDataEdge(sourceId: 'lf', targetId: cfg, role: 'last_frame');

    await expectLater(
      buildCtrl().submitFromConfigNode(cfg),
      throwsA(isA<InvalidGenerationConfigError>().having(
        (e) => e.reason,
        'reason',
        'last_frame_unsupported',
      )),
    );
    expect(jobs.creates, isEmpty);
  });

  test('首尾帧全支持 + 双边 → firstFramePath/lastFramePath 都注入', () async {
    useVideoProvider(first: true, last: true);
    final cfg = await seedVideoConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );
    seedRefImageNode(id: 'ff', imageUrl: 'images/first.png');
    seedRefImageNode(id: 'lf', imageUrl: 'images/last.png');
    seedDataEdge(sourceId: 'ff', targetId: cfg, role: 'first_frame');
    seedDataEdge(sourceId: 'lf', targetId: cfg, role: 'last_frame');

    await buildCtrl().submitFromConfigNode(cfg);

    final task = queue.lastTask!;
    expect(task.mode, GenerationMode.imageToVideo);
    expect(task.firstFramePath, contains('images/first.png'));
    expect(task.lastFramePath, contains('images/last.png'));
  });

  test('非 image/video type → InvalidGenerationConfigError', () async {
    nodes.rows['bad'] = {
      'id': 'bad',
      'canvas_id': 'cvx',
      'project_id': 'proj-1',
      'type': 'text',
      'node_role': 'config',
      'type_config': <String, Object?>{'prompt': 'x', 'provider_id': providerId},
    };

    expect(
      () => buildCtrl().submitFromConfigNode('bad'),
      throwsA(isA<InvalidGenerationConfigError>()),
    );
    expect(nodes.creates, isEmpty);
  });
}
