// CanvasNodesController 单测 —— 用 fake NodeRepository 打桩，不接真 PG。
//
// 覆盖：初始 load、addNode 乐观更新 + DB create 参数透传、removeNode 乐观删除 +
// DB 失败回滚、moveNode 持久化位置 + 泳道 + InkError 回滚。

import 'dart:async';
import 'dart:ui' show Size;

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
  final List<String> restored = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  String? createError;
  String? softDeleteError;
  String? restoreError;
  String? updateError;

  /// 置入后 create 会先 await 此 gate，用于制造两次 create 交错（LB-04）。
  Completer<void>? createGate;

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
    if (createGate != null) await createGate!.future;
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
      'type_config': typeConfig,
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
  Future<int> softDeleteEmptyOrphanResults() async => 0;

  @override
  Future<List<String>> listAllMediaUrls() async => const <String>[];
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
  Future<int> restore(String id) async {
    if (restoreError != null) {
      throw LocalIOError(
          extra: {'op': 'restore', 'table': 'nodes', 'msg': restoreError});
    }
    restored.add(id);
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async => 0;
}

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = [];
  final List<String> softDeleted = [];
  final List<String> restored = [];

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
  Future<int> restore(String id) async {
    restored.add(id);
    return 1;
  }

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

    test('addNode 不传 size → 按类型取默认尺寸（media 类更大）', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final image = await ctrl.addNode(label: 'I', type: CanvasNodeType.image);
      final video = await ctrl.addNode(label: 'V', type: CanvasNodeType.video);
      final shot = await ctrl.addNode(label: 'S', type: CanvasNodeType.shot);
      final text = await ctrl.addNode(label: 'T', type: CanvasNodeType.text);

      expect(image.size, defaultNodeSize(CanvasNodeType.image));
      expect(video.size, defaultNodeSize(CanvasNodeType.video));
      expect(shot.size, defaultNodeSize(CanvasNodeType.shot));
      expect(text.size, defaultNodeSize(CanvasNodeType.text));
      // media 类默认尺寸大于紧凑类
      expect(image.size.width, greaterThan(text.size.width));
      // 透传到 Repository.create
      expect(repo.createCalls.first['width'],
          defaultNodeSize(CanvasNodeType.image).width);
    });

    test('addNode 显式传 size → 覆盖类型默认', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final n = await ctrl.addNode(
        label: 'X',
        type: CanvasNodeType.image,
        size: const Size(111, 99),
      );
      expect(n.size, const Size(111, 99));
    });

    test('addNode 透传 typeConfig：乐观对象 + Repository.create 都带上', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted = await ctrl.addNode(
        label: 'S',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'wide shot'},
      );

      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['type_config'],
          <String, Object?>{'prompt': 'wide shot'});
      expect(inserted.typeConfig, <String, Object?>{'prompt': 'wide shot'});

      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.single.typeConfig,
          <String, Object?>{'prompt': 'wide shot'});
    });

    test('addNode 不传 typeConfig → 默认空 map，行为不变', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted =
          await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      expect(repo.createCalls.first['type_config'], isEmpty);
      expect(inserted.typeConfig, isEmpty);
    });

    test('addNode 两次并发交错不丢更新（LB-04 串行化）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);

      // gate 挂起两次 create，使二者在任一写回 state 之前都读到同一空快照。
      final gate = Completer<void>();
      repo.createGate = gate;

      final fa = ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final fb = ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      gate.complete();
      await Future.wait([fa, fb]);

      final state = container.read(canvasNodesControllerProvider(canvasId));
      // 未串行化时后者用空快照覆盖前者 → 只剩 1 个（RED）。
      expect(state.valueOrNull, hasLength(2),
          reason: '两次并发 addNode 都应保留，交错快照不得覆盖');
      expect(
        state.valueOrNull!.map((n) => n.label),
        containsAll(<String>['A', 'B']),
      );
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

    test('removeNode 返回撤销令牌：节点 + 级联 edge id（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final e1 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      final e2 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: b.id,
        targetNodeId: a.id,
        edgeType: 'narrative',
      );

      final deletion = await ctrl.removeNode(a.id);

      expect(deletion, isNotNull);
      expect(deletion!.node.id, a.id);
      expect(deletion.edgeIds, containsAll(<String>[e1, e2]));
    });

    test('restore 复原节点 + 级联 edges，节点回到 state（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final e1 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );

      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);
      expect(
        container
            .read(canvasNodesControllerProvider(canvasId))
            .valueOrNull!
            .any((n) => n.id == a.id),
        isFalse,
      );

      await ctrl.restore(deletion!);

      expect(repo.restored, contains(a.id));
      expect(edgeRepo.restored, contains(e1));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.any((n) => n.id == a.id), isTrue);
    });

    test('restore DB 失败 → 乐观复原回滚（节点仍不在内存）（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);
      repo.restoreError = 'nope';

      await expectLater(
          ctrl.restore(deletion!), throwsA(isA<LocalIOError>()));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.any((n) => n.id == a.id), isFalse);
    });

    test('restore 在 provider dispose 后 no-op，不抛 StateError（PL-4a 入口守卫）',
        () async {
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: repo, edges: edgeRepo),
          ),
        ),
      ]);
      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);

      c.dispose(); // 画布关闭 → notifier autoDispose，_alive=false

      // 窗口内点 Undo：入口 _alive 守卫先于 ref.read → no-op，绝不 StateError。
      await expectLater(ctrl.restore(deletion!), completes);
      expect(repo.restored, isEmpty, reason: 'dispose 后 restore 不落 DB');
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
