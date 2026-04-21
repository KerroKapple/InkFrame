// CanvasEdgesController — canvasId-family，DB-backed 连线集合。
//
// 与 CanvasNodesController 设计对齐：load / add / remove 经 EdgeRepository，
// 失败回滚内存。此 MVP 不覆盖 role 修改（firstFrame/lastFrame 切换归后续 PR）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../models/canvas_edge.dart';

final canvasEdgesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasEdgesController, List<CanvasEdge>, String>(
  CanvasEdgesController.new,
  name: 'canvasEdgesControllerProvider',
);

class CanvasEdgesController
    extends AutoDisposeFamilyAsyncNotifier<List<CanvasEdge>, String> {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async {
    final repo = await ref.watch(edgeRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    return rows.map(CanvasEdgeMapping.fromRow).toList(growable: false);
  }

  EdgeRepository get _repo {
    final async = ref.read(edgeRepositoryProvider);
    final repo = async.valueOrNull;
    if (repo == null) {
      throw StateError('edgeRepositoryProvider 尚未就绪');
    }
    return repo;
  }

  /// 创建连线。乐观写——先更新内存，DB 失败回滚并 rethrow。
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
      state = AsyncData([...previous, edge]);
      return edge;
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> removeEdge(String id) async {
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    state = AsyncData(previous.where((e) => e.id != id).toList(growable: false));
    try {
      await _repo.softDelete(id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
