// CanvasNodesController 单测 —— 用 fake NodeRepository 打桩，不接真 PG。
//
// 覆盖：初始 load、addNode 乐观更新 + DB create 参数透传、removeNode 乐观删除 +
// DB 失败回滚、moveNode 内存位移不落盘。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';

class _FakeNodeRepository implements NodeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];

  String? createError;
  String? softDeleteError;

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
      throw StateError(createError!);
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
      throw StateError(softDeleteError!);
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
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async =>
      0;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  late _FakeNodeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeNodeRepository();
    container = ProviderContainer(
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
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
        throwsStateError,
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

      await expectLater(ctrl.removeNode(n.id), throwsStateError);
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
      expect(state.valueOrNull!.first.id, n.id);
    });

    test('moveNode 仅改内存，不调 Repository', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(10, 10),
      );

      ctrl.moveNode(n.id, const Offset(5, -3));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final moved = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(moved.position, const Offset(15, 7));
    });
  });
}
