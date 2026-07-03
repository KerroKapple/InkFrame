// GenerationController 提示词注入测试（PRD §7.4）。
// 覆盖：
//   - config 节点有 lane_id + canvas base前缀/后缀 + 文本节点 → fullPrompt 按公式组装
//   - ignore_lane_style:true → 泳道段被丢弃
//   - canvas/lane 查询返回 null → 降级为纯 userPrompt
//   - 文本节点无内容 → associatedTexts 为空

import 'dart:async';
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
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/providers/provider_registry.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_character.dart';
import '../../_harness/fake_unit_of_work.dart';

// ---- fakes ---------------------------------------------------------------

class _FakeNodeRepo implements NodeRepository {
  final Map<String, Map<String, Object?>> rows = {};
  final List<Map<String, Object?>> creates = [];
  int _seq = 0;

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
    final id = 'n${++_seq}';
    creates.add({'id': id, 'canvas_id': canvasId, 'type': type, 'node_role': nodeRole});
    rows[id] = {
      'id': id, 'canvas_id': canvasId, 'type': type,
      'node_role': nodeRole, 'source_node_id': sourceNodeId, 'type_config': typeConfig,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];
  @override
  Future<int> softDelete(String id) async { rows.remove(id); return 1; }
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c) async => [];
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String c) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> p) async => 0;
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> p) async => 0;
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
      'full_prompt': fullPrompt,
      'user_prompt': userPrompt,
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
  Future<int> update(String id, Map<String, Object?> p) async => 0;
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
  final Map<String, String> _d = {};
  @override
  Future<void> store(String k, String v) async => _d[k] = v;
  @override
  Future<String?> retrieve(String k) async => _d[k];
  @override
  Future<void> delete(String k) async => _d.remove(k);
  @override
  Future<bool> exists(String k) async => _d.containsKey(k);
}

class _FakeHandle implements JobHandle {
  _FakeHandle(this._jobId);
  final String _jobId;
  @override
  String get jobId => _jobId;
  @override
  Stream<JobStatus> get status => const Stream.empty();
  @override
  Future<JobStatus> get done =>
      Future.microtask(() => const JobStatus.success(remoteUrls: []));
}

class _FakeQueue implements JobQueueService {
  GenerationTask? lastTask;
  @override
  Future<void> init() async {}
  @override
  Future<JobHandle> submit(GenerationTask task) async {
    lastTask = task;
    return _FakeHandle(task.jobId);
  }
  @override
  Future<void> cancel(String jobId) async {}
  @override
  void dispose() {}
}

class _RecordingRegistry extends JobsRegistry {
  @override
  void upsert(JobState job) {}
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
      'id': id, 'canvas_id': canvasId,
      'source_node_id': sourceNodeId, 'target_node_id': targetNodeId,
      'edge_type': edgeType, 'role': role,
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
  Future<int> update(String id, Map<String, Object?> p) async => 0;
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
  File resolve({required String projectId, required String canvasId, required String relativePath}) =>
      File('/fake/$relativePath');
  @override
  String toRelative({required String projectId, required String canvasId, required File source}) =>
      source.path;
}

/// 支持配置 base前缀/后缀 的假 CanvasRepository。
class _FakeCanvasRepo implements CanvasRepository {
  String? prefix;
  String? suffix;
  @override
  Future<Map<String, Object?>?> findById(String id) async {
    if (prefix == null && suffix == null) return null;
    return <String, Object?>{
      'base_style_prefix': prefix ?? '',
      'base_style_suffix': suffix ?? '',
    };
  }
  @override
  Future<String> create({required String projectId, required String name, String baseStylePrefix = '', String baseStyleSuffix = ''}) async => '';
  @override
  Future<List<Map<String, Object?>>> listByProject(String p) async => [];
  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> ps) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> p) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

/// 支持配置 style_prompt 的假 StyleLaneRepository。
class _FakeLaneRepo implements StyleLaneRepository {
  final Map<String, String> stylePrompts = {};
  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final sp = stylePrompts[id];
    if (sp == null) return null;
    return <String, Object?>{'style_prompt': sp};
  }
  @override
  Future<String> create({required String canvasId, String label = '', String stylePrompt = '', int sortOrder = 0, String? tintColor, double size = 400.0}) async => '';
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> p) async => 0;
  @override
  Future<int> softDelete(String id) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

// ---- tests ---------------------------------------------------------------

void main() {
  const providerId = 'gemini-image';

  late _FakeNodeRepo nodes;
  late _FakeEdgeRepo edges;
  late _FakeJobRepo jobs;
  late _FakeSecure secure;
  late _FakeQueue queue;
  late _FakeCanvasRepo canvasRepo;
  late _FakeLaneRepo laneRepo;
  late _RecordingRegistry jobsRegistry;

  GenerationController buildCtrl() => GenerationController(
        nodes: nodes,
        edges: edges,
        jobs: jobs,
        secure: secure,
        queue: queue,
        registry: CachingProviderRegistry({
          providerId: () => throw UnimplementedError(),
        }),
        resolver: _FakeResolver(),
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
    jobs = _FakeJobRepo();
    secure = _FakeSecure();
    queue = _FakeQueue();
    canvasRepo = _FakeCanvasRepo();
    laneRepo = _FakeLaneRepo();
    jobsRegistry = _RecordingRegistry();
  });

  /// config 节点含 lane_id；canvas 有 base前缀/后缀；text 节点通过 data edge 接入。
  test('lane_id + canvas base + 文本节点 → fullPrompt 按 §7.4 公式组装', () async {
    canvasRepo.prefix = 'cinematic';
    canvasRepo.suffix = '8k';
    laneRepo.stylePrompts['lane-1'] = 'dramatic lighting';

    // 文本节点
    nodes.rows['txt1'] = {
      'id': 'txt1', 'canvas_id': 'cvx', 'type': 'text', 'node_role': 'content',
      'label': 'with fog',
      'type_config': <String, Object?>{'text': 'with fog'},
    };
    // config 节点，含 lane_id
    nodes.rows['cfg1'] = {
      'id': 'cfg1', 'canvas_id': 'cvx', 'project_id': 'proj-1',
      'type': 'image', 'node_role': 'config', 'lane_id': 'lane-1',
      'type_config': <String, Object?>{'prompt': 'a cat', 'provider_id': providerId},
    };
    // data edge: txt1 → cfg1
    edges.rows.add({
      'id': 'e1', 'canvas_id': 'cvx',
      'source_node_id': 'txt1', 'target_node_id': 'cfg1',
      'edge_type': 'data', 'role': 'reference',
    });

    await secure.store(SecureStorageKeys.providerApiKey(providerId), 'sk-x');
    await buildCtrl().submitFromConfigNode('cfg1');

    // 期望：cinematic, dramatic lighting, with fog, a cat, 8k
    expect(jobs.creates.first['full_prompt'],
        'cinematic, dramatic lighting, with fog, a cat, 8k');
    expect(jobs.creates.first['user_prompt'], 'a cat');
    expect(queue.lastTask!.prompt,
        'cinematic, dramatic lighting, with fog, a cat, 8k');
  });

  test('ignore_lane_style:true → fullPrompt 不含泳道风格段', () async {
    canvasRepo.prefix = 'cinematic';
    laneRepo.stylePrompts['lane-1'] = 'dramatic lighting';

    nodes.rows['cfg2'] = {
      'id': 'cfg2', 'canvas_id': 'cvx', 'project_id': 'proj-1',
      'type': 'image', 'node_role': 'config', 'lane_id': 'lane-1',
      'type_config': <String, Object?>{
        'prompt': 'a cat',
        'provider_id': providerId,
        'ignore_lane_style': true,
      },
    };

    await secure.store(SecureStorageKeys.providerApiKey(providerId), 'sk-x');
    await buildCtrl().submitFromConfigNode('cfg2');

    // 泳道段 'dramatic lighting' 应缺席
    final fp = jobs.creates.first['full_prompt'] as String;
    expect(fp, contains('cinematic'));
    expect(fp, contains('a cat'));
    expect(fp, isNot(contains('dramatic lighting')));
  });

  test('canvas/lane 均返回 null → fullPrompt 等于 userPrompt（降级）', () async {
    // canvasRepo 和 laneRepo 默认 findById 返回 null
    nodes.rows['cfg3'] = {
      'id': 'cfg3', 'canvas_id': 'cvx', 'project_id': 'proj-1',
      'type': 'image', 'node_role': 'config', 'lane_id': 'lane-x',
      'type_config': <String, Object?>{'prompt': 'a dog', 'provider_id': providerId},
    };

    await secure.store(SecureStorageKeys.providerApiKey(providerId), 'sk-x');
    await buildCtrl().submitFromConfigNode('cfg3');

    expect(jobs.creates.first['full_prompt'], 'a dog');
    expect(queue.lastTask!.prompt, 'a dog');
  });

  test('config 节点无 lane_id → fullPrompt 仅含 base + userPrompt', () async {
    canvasRepo.prefix = 'film grain';
    nodes.rows['cfg4'] = {
      'id': 'cfg4', 'canvas_id': 'cvx', 'project_id': 'proj-1',
      'type': 'image', 'node_role': 'config',
      'type_config': <String, Object?>{'prompt': 'a bird', 'provider_id': providerId},
    };

    await secure.store(SecureStorageKeys.providerApiKey(providerId), 'sk-x');
    await buildCtrl().submitFromConfigNode('cfg4');

    expect(jobs.creates.first['full_prompt'], 'film grain, a bird');
  });
}
