// CanvasEdgesController — canvasId-family，DB-backed 连线集合。
//
// 与 CanvasNodesController 设计对齐：load / add / remove 经 EdgeRepository，
// 失败回滚内存。此 MVP 不覆盖 role 修改（firstFrame/lastFrame 切换归后续 PR）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../models/canvas_edge.dart';

final canvasEdgesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasEdgesController, List<CanvasEdge>, String>(
  CanvasEdgesController.new,
  name: 'canvasEdgesControllerProvider',
);

class CanvasEdgesController
    extends AutoDisposeFamilyAsyncNotifier<List<CanvasEdge>, String> {
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
  }) async {
    final canvasId = arg;
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    try {
      final id = await _repo.create(
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
  }

  Future<void> removeEdge(String id) async {
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    state = AsyncData(previous.where((e) => e.id != id).toList(growable: false));
    try {
      await _repo.softDelete(id);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }

  /// 变更已存在连线的 role（data edge 专用：reference / firstFrame / lastFrame）。
  /// 乐观更新内存后 DB 失败回滚。
  Future<void> updateRole(String id, EdgeRole role) async {
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    final next = [
      for (final e in previous)
        if (e.id == id) e.copyWith(role: role) else e,
    ];
    state = AsyncData(next);
    try {
      await _repo.update(id, <String, Object?>{
        'role': CanvasEdgeMapping.roleToDb(role),
      });
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
}
