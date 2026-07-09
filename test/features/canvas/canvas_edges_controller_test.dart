// CanvasEdgesController 单测——FakeEdgeRepository 覆盖 build / add / remove /
// DB 失败回滚。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];
  final List<String> restored = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];
  bool createThrows = false;
  bool softDeleteThrows = false;
  bool restoreThrows = false;
  bool updateThrows = false;

  /// 置入后 create 会先 await 此 gate，用于制造两次 create 交错（LB-04）。
  Completer<void>? createGate;

  int _seq = 0;

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    if (createGate != null) await createGate!.future;
    if (createThrows) {
      throw const LocalIOError(extra: {'op': 'create', 'table': 'edges'});
    }
    final id = 'e${++_seq}';
    createCalls.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    });
    rows.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      rows.where((r) => r['canvas_id'] == canvasId).toList(growable: false);

  @override
  Future<int> softDelete(String id) async {
    if (softDeleteThrows) {
      throw const LocalIOError(extra: {'op': 'softDelete', 'table': 'edges'});
    }
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  // 未使用接口
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (updateThrows) {
      throw const LocalIOError(extra: {'op': 'update', 'table': 'edges'});
    }
    updateCalls.add({'id': id, ...patch});
    final idx = rows.indexWhere((r) => r['id'] == id);
    if (idx >= 0) rows[idx] = {...rows[idx], ...patch};
    return 1;
  }
  @override
  Future<int> restore(String id) async {
    if (restoreThrows) {
      throw const LocalIOError(extra: {'op': 'restore', 'table': 'edges'});
    }
    restored.add(id);
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async => 0;
}

class _GatedEdgeRepo implements EdgeRepository {
  final Completer<void> gate = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    await gate.future; // 阻塞，模拟 await 期间 provider 被 dispose
    return 'e1';
  }
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;
  @override
  Future<int> softDelete(String id) async => 1;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  late _FakeEdgeRepo repo;
  late ProviderContainer container;
  const canvasId = 'cvx';

  setUp(() {
    repo = _FakeEdgeRepo();
    container = ProviderContainer(overrides: [
      edgeRepositoryProvider.overrideWith((ref) async => repo),
    ]);
  });
  tearDown(() => container.dispose());

  group('CanvasEdgesController', () {
    test('build 空画布', () async {
      final edges = await container
          .read(canvasEdgesControllerProvider(canvasId).future);
      expect(edges, isEmpty);
    });

    test('addEdge 透传 Repository.create + 写入内存', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);

      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      expect(e.edgeType, EdgeType.data);
      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['edge_type'], 'data');
      expect(repo.createCalls.first['role'], 'reference');

      final state =
          container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addEdge 支持 first_frame role + generation_source 类型', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);

      await ctrl.addEdge(
        sourceNodeId: 'img',
        targetNodeId: 'vid',
        edgeType: EdgeType.data,
        role: EdgeRole.firstFrame,
      );
      await ctrl.addEdge(
        sourceNodeId: 'cfg',
        targetNodeId: 'res',
        edgeType: EdgeType.generationSource,
      );

      expect(repo.createCalls.last['edge_type'], 'generation_source');
      expect(repo.createCalls[0]['role'], 'first_frame');
    });

    test('addEdge 两次并发交错不丢更新（LB-04 串行化）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasEdgesControllerProvider(canvasId).notifier);

      final gate = Completer<void>();
      repo.createGate = gate;

      final fa = ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final fb = ctrl.addEdge(sourceNodeId: 'c', targetNodeId: 'd');
      gate.complete();
      await Future.wait([fa, fb]);

      final state = container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(2),
          reason: '两次并发 addEdge 都应保留，交错快照不得覆盖');
    });

    test('addEdge DB 失败 → 回滚 + rethrow', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      repo.createThrows = true;

      await expectLater(
        ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b'),
        throwsA(isA<LocalIOError>()),
      );
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('removeEdge 乐观删除 + DB softDelete', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      await ctrl.removeEdge(e.id);

      expect(repo.softDeleted, contains(e.id));
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('removeEdge 返回被删边（PL-4a undo 令牌）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      final removed = await ctrl.removeEdge(e.id);

      expect(removed, isNotNull);
      expect(removed!.id, e.id);
    });

    test('restore 复原连线到内存 + repo.restore（PL-4a）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final removed = await ctrl.removeEdge(e.id);
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);

      await ctrl.restore(removed!);

      expect(repo.restored, contains(e.id));
      final state = container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
      expect(state.valueOrNull!.first.id, e.id);
    });

    test('restore DB 失败 → 乐观复原回滚（PL-4a）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final removed = await ctrl.removeEdge(e.id);
      repo.restoreThrows = true;

      await expectLater(
          ctrl.restore(removed!), throwsA(isA<LocalIOError>()));
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('updateRole 写 DB role 字段 + 内存更新', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      await ctrl.updateRole(e.id, EdgeRole.firstFrame);

      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['role'], 'first_frame');
      final state = container.read(canvasEdgesControllerProvider(canvasId));
      final updated =
          state.valueOrNull!.firstWhere((x) => x.id == e.id);
      expect(updated.role, EdgeRole.firstFrame);
    });

    test('updateRole DB 失败 → 回滚', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      repo.updateThrows = true;

      await expectLater(
        ctrl.updateRole(e.id, EdgeRole.lastFrame),
        throwsA(isA<LocalIOError>()),
      );
      final updated = container
          .read(canvasEdgesControllerProvider(canvasId))
          .valueOrNull!
          .firstWhere((x) => x.id == e.id);
      expect(updated.role, EdgeRole.reference);
    });

    test('removeEdge DB 失败 → 回滚', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      repo.softDeleteThrows = true;

      await expectLater(ctrl.removeEdge(e.id), throwsA(isA<LocalIOError>()));
      final state =
          container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addEdge 在 await 期间被 dispose 不抛 StateError (ME-27 _alive 守卫)',
        () async {
      final gated = _GatedEdgeRepo();
      final c = ProviderContainer(overrides: [
        edgeRepositoryProvider.overrideWith((ref) async => gated),
      ]);
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasEdgesControllerProvider(canvasId).notifier);
      final future = ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      c.dispose(); // await 期间销毁 notifier
      gated.gate.complete(); // 放行 create
      await expectLater(future, completes); // 守卫存在 → 无 StateError
    });
  });
}
