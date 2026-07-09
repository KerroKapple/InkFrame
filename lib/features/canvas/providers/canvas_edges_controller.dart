// CanvasEdgesController — canvasId-family，DB-backed 连线集合。
//
// 与 CanvasNodesController 设计对齐：load / add / remove / updateRole 经
// EdgeRepository，失败回滚内存。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../models/canvas_edge.dart';
import 'serial_mutation_queue.dart';

final canvasEdgesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasEdgesController, List<CanvasEdge>, String>(
  CanvasEdgesController.new,
  name: 'canvasEdgesControllerProvider',
);

class CanvasEdgesController
    extends AutoDisposeFamilyAsyncNotifier<List<CanvasEdge>, String>
    with SerialMutationQueue {
  bool _alive = false;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(edgeRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    return rows.map(CanvasEdgeMapping.fromRow).toList(growable: false);
  }

  EdgeRepository get _repo {
    final async = ref.read(edgeRepositoryProvider);
    final repo = async.valueOrNull;
    if (repo == null) {
      throw StateError('edgeRepositoryProvider is not ready');
    }
    return repo;
  }

  /// 创建连线。await create 成功后写内存；失败 rethrow（与 nodes/lanes 对齐 ME-27 守卫）。
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    int sortOrder = 0,
  }) {
    final canvasId = arg;
    final repo = _repo;
    return serialize<CanvasEdge>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      try {
        final id = await repo.create(
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          targetNodeId: targetNodeId,
          edgeType: CanvasEdgeMapping.typeToDb(edgeType),
          role: CanvasEdgeMapping.roleToDb(role),
          sortOrder: sortOrder,
        );
        final edge = CanvasEdge(
          id: id,
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          targetNodeId: targetNodeId,
          edgeType: edgeType,
          role: role,
          sortOrder: sortOrder,
        );
        if (_alive) state = AsyncData([...previous, edge]);
        return edge;
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 软删除连线。返回被删 [CanvasEdge] 供 PL-4a undo；连线不在内存时返回 null。
  Future<CanvasEdge?> removeEdge(String id) {
    final repo = _repo;
    return serialize<CanvasEdge?>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      CanvasEdge? removed;
      for (final e in previous) {
        if (e.id == id) removed = e;
      }
      if (_alive) {
        state =
            AsyncData(previous.where((e) => e.id != id).toList(growable: false));
      }
      try {
        await repo.softDelete(id);
        return removed;
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 撤销 removeEdge（PL-4a 删除防误伤）：清 deleted_at + 把连线放回内存；
  /// DB 失败回滚并上抛。
  Future<void> restore(CanvasEdge edge) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      if (_alive) state = AsyncData([...previous, edge]); // 乐观复原
      try {
        await repo.restore(edge.id);
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 变更已存在连线的 role（data edge 专用：reference / firstFrame / lastFrame）。
  /// 乐观更新内存后 DB 失败回滚。
  Future<void> updateRole(String id, EdgeRole role) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      if (_alive) {
        state = AsyncData([
          for (final e in previous)
            if (e.id == id) e.copyWith(role: role) else e,
        ]);
      }
      try {
        await repo.update(id, <String, Object?>{
          'role': CanvasEdgeMapping.roleToDb(role),
        });
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }
}
