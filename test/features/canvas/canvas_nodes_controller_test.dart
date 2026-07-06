// CanvasNodesController 单测 —— 用 fake NodeRepository 打桩，不接真 PG。
//
// 覆盖：初始 load、addNode 乐观更新 + DB create 参数透传、removeNode 乐观删除 +
// DB 失败回滚、moveNode 持久化位置 + 泳道 + InkError 回滚。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';

import '../../_harness/fake_unit_of_work.dart';

class _FakeNodeRepository implements NodeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  String? createError;
  String? softDeleteError;
  String? updateError;

  int _idCounter = 0;

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
    createCalls.add(<String, Object?>{
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'label': label,
      'source_node_id': sourceNodeId,
      'position_x': positionX,
      'position_y': positionY,
      'width': width,
      'height': height,
    });
    if (createError != null) {
      throw LocalIOError(extra: {'op': 'create', 'table': 'nodes', 'msg': createError});
    }
    final id = 'n${++_idCounter}';
    rows.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'label': label,
      'source_node_id': sourceNodeId,
      'position_x': positionX,
      'position_y': positionY,
      'width': width,
      'height': height,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    return rows
        .where((r) => r['canvas_id'] == canvasId)
        .toList(growable: false);
  }

  @override
  Future<int> softDelete(String id) async {
    if (softDeleteError != null) {
      throw LocalIOError(
          extra: {'op': 'softDelete', 'table': 'nodes', 'msg': softDeleteError});
    }
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  // ---- 未用到的接口 ----
  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      rows.firstWhere((r) => r['id'] == id, orElse: () => const {});
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      const [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    updateCalls.add(<String, Object?>{'id': id, ...patch});
    if (updateError != null) {
      throw LocalIOError(extra: {'op': 'update', 'table': 'nodes', 'msg': updateError});
    }
    final row = rows.firstWhere((r) => r['id'] == id, orElse: () => <String, Object?>{});
    row.addAll(patch);
    return 1;
  }
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async =>
      0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = [];
  final List<String> softDeleted = [];

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
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async =>
      rows.where((r) => r['source_node_id'] == s).toList();

  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async =>
      rows.where((r) => r['target_node_id'] == t).toList();

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  late _FakeNodeRepository repo;
  late _FakeEdgeRepo edgeRepo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeNodeRepository();
    edgeRepo = _FakeEdgeRepo();
    container = ProviderContainer(
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: repo, edges: edgeRepo),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  const canvasId = 'cvx';

  group('CanvasNodesController', () {
    test('build 从 Repository 加载节点', () async {
      repo.rows.add(<String, Object?>{
        'id': 'seed',
        'canvas_id': canvasId,
        'type': 'image',
        'node_role': 'config',
        'label': 'Seed',
        'position_x': 10.0,
        'position_y': 20.0,
      });
      final nodes = await container
          .read(canvasNodesControllerProvider(canvasId).future);
      expect(nodes, hasLength(1));
      expect(nodes.first.id, 'seed');
      expect(nodes.first.role, NodeRole.config);
      expect(nodes.first.position, const Offset(10, 20));
    });

    test('addNode 乐观更新 + 透传 Repository.create 参数', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(100, 200),
      );

      expect(inserted.id, isNotEmpty);
      expect(inserted.role, NodeRole.config);
      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['node_role'], 'config');
      expect(repo.createCalls.first['position_x'], 100.0);

      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addNode DB 失败抛给调用方，内存不写入', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      repo.createError = 'boom';

      await expectLater(
        ctrl.addNode(label: 'X', type: CanvasNodeType.image),
        throwsA(isA<LocalIOError>()),
      );
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, isEmpty);
      expect(repo.rows, isEmpty,
          reason: '失败路径不该在 fake DB 里落下行');
    });

    test('result 节点必须带 sourceNodeId（assert）', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      expect(
        () => ctrl.addNode(
          label: 'R',
          type: CanvasNodeType.image,
          role: NodeRole.result,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('removeNode 乐观删除 + DB softDelete', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      await ctrl.removeNode(n.id);

      expect(repo.softDeleted, contains(n.id));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, isEmpty);
    });

    test('removeNode DB 失败回滚内存', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      repo.softDeleteError = 'nope';

      await expectLater(ctrl.removeNode(n.id), throwsA(isA<LocalIOError>()));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
      expect(state.valueOrNull!.first.id, n.id);
    });

    test('removeNode 级联软删相邻 edges（入+出）— 单事务', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);

      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: c.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: b.id,
        targetNodeId: a.id,
        edgeType: 'narrative',
      );

      await ctrl.removeNode(b.id);

      // b 的 2 条入边 + 1 条出边都应被 softDelete
      expect(edgeRepo.softDeleted, hasLength(3));
      expect(repo.softDeleted, contains(b.id));
    });

    test('removeNode 无关联 edges → 只软删节点', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'X', type: CanvasNodeType.image);
      await ctrl.removeNode(n.id);
      expect(repo.softDeleted, contains(n.id));
      expect(edgeRepo.softDeleted, isEmpty);
    });

    test('removeNode await 期间 provider dispose → 不抛 StateError（ME-27）',
        () async {
      final gate = Completer<void>();
      final gnode = _FakeNodeRepository()..softDeleteError = 'late failure';
      final gedge = _FakeEdgeRepo();
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => gnode),
        edgeRepositoryProvider.overrideWith((ref) async => gedge),
        unitOfWorkProvider.overrideWith(
          (ref) async => GatedFakeUnitOfWork(
            FakeRepositoryScope(nodes: gnode, edges: gedge),
            gate.future,
          ),
        ),
      ]);

      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      // 事务在 gate 上挂起；dispose 后 gate 放行 → node softDelete 失败。
      final pending = ctrl.removeNode(n.id);
      c.dispose(); // await 挂起期间整个容器销毁
      gate.complete();

      // dispose 后不得触 ref/state——只允许原始 InkError 冒泡，绝不 StateError。
      await expectLater(pending, throwsA(isA<LocalIOError>()));
    });

    test('moveNode 更新内存位置', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(10, 10),
      );

      await ctrl.moveNode(n.id, const Offset(5, -3), laneId: null);
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final moved = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(moved.position, const Offset(15, 7));
    });

    test('moveNode 持久化 position + lane_id 并更新 state', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(0, 0),
      );

      await ctrl.moveNode(n.id, const Offset(50, 60), laneId: 'lane-9');

      // repo.update 收到正确的持久化负载
      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['position_x'], 50.0);
      expect(repo.updateCalls.first['position_y'], 60.0);
      expect(repo.updateCalls.first['lane_id'], 'lane-9');

      // state 已乐观更新
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final moved = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(moved.position, const Offset(50, 60));
      expect(moved.laneId, 'lane-9');
    });

    test('moveNode DB 失败回滚内存位置', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(10, 10),
      );

      repo.updateError = 'disk full';

      await expectLater(
        ctrl.moveNode(n.id, const Offset(50, 60), laneId: 'lane-9'),
        throwsA(isA<LocalIOError>()),
      );

      // 内存回滚到移动前的坐标
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final rolled = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(rolled.position, const Offset(10, 10));
      expect(rolled.laneId, isNull);
    });
  });
}
