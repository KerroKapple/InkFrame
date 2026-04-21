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
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/providers/provider_registry.dart';

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

class _FakeJobHandle implements JobHandle {
  _FakeJobHandle(this.jobId, this._status);
  @override
  final String jobId;
  final JobStatus _status;
  @override
  Stream<JobStatus> get status => Stream.value(_status);
  @override
  Future<JobStatus> get done async => _status;
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
    return _FakeJobHandle(task.jobId, finalStatus);
  }
  @override
  Future<void> cancel(String jobId) async {}
  @override
  void dispose() {}
}

// ---- tests ------------------------------------------------------------

void main() {
  const providerId = 'gemini-image';
  late _FakeNodeRepo nodes;
  late _FakeJobRepo jobs;
  late _FakeSecure secure;
  late _FakeJobQueue queue;
  late ProviderRegistry registry;

  GenerationController buildCtrl() => GenerationController(
        nodes: nodes,
        jobs: jobs,
        secure: secure,
        queue: queue,
        registry: registry,
      );

  setUp(() {
    nodes = _FakeNodeRepo();
    jobs = _FakeJobRepo();
    secure = _FakeSecure();
    queue = _FakeJobQueue(const JobStatus.success(remoteUrls: []));
    registry = ProviderRegistry({
      providerId: () => throw UnimplementedError('not called in tests'),
    });
  });

  Future<String> seedConfigNode({
    String prompt = 'a cat',
    String? providerIdOverride,
  }) async {
    const id = 'cfg1';
    final typeConfig = <String, Object?>{'prompt': prompt};
    if (providerIdOverride != null) {
      typeConfig['provider_id'] = providerIdOverride;
    }
    nodes.rows[id] = {
      'id': id,
      'canvas_id': 'cvx',
      'type': 'image',
      'node_role': 'config',
      'type_config': typeConfig,
    };
    return id;
  }

  test('成功路径：预创建 result + jobs.create + submit + 等 done', () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk-test',
    );

    final outcome = await buildCtrl().submitFromConfigNode(cfg);

    expect(outcome.succeeded, isTrue);
    expect(nodes.creates, hasLength(1));
    expect(nodes.creates.first['node_role'], 'result');
    expect(nodes.creates.first['source_node_id'], cfg);
    expect(jobs.creates, hasLength(1));
    expect(jobs.creates.first['result_node_id'], outcome.resultNodeId);
    expect(queue.lastTask?.prompt, 'a cat');
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

  test('Provider 失败（JobHandle.done = failure）→ result 节点 softDelete',
      () async {
    final cfg = await seedConfigNode();
    await secure.store(
      SecureStorageKeys.providerApiKey(providerId),
      'sk',
    );
    queue.finalStatus = const JobStatus.failure(
      error: ProviderError(code: InkErrorCode.providerServer),
    );

    final outcome = await buildCtrl().submitFromConfigNode(cfg);
    expect(outcome.succeeded, isFalse);
    expect(nodes.softDeleted, contains(outcome.resultNodeId));
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
}
