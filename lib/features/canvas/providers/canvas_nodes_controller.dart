// CanvasNodesController — DB-backed 画布节点集合。
//
// 替代早期纯内存的 CanvasViewModel（S1a 之前）。按 canvasId 分族，每个画布一份状态。
//
// 持久化策略（S1b 范围）：
//   - load / add / remove → 经 NodeRepository 过 DB
//   - moveNode 本阶段只改内存，不落盘（避免每像素 UPDATE 风暴）
//     S3 会补：pan 结束防抖 200ms 后 NodeRepository.update(position_x/y)
//
// 失败策略：add/remove 采用"先改内存再持久化"。若 DB 失败则回滚内存并把错误
// 冒泡到调用方；UI 层负责 toast（S4）。

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/interfaces/node_repository.dart';
import '../models/canvas_node.dart';

final canvasNodesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasNodesController, List<CanvasNode>, String>(
  CanvasNodesController.new,
  name: 'canvasNodesControllerProvider',
);

class CanvasNodesController
    extends AutoDisposeFamilyAsyncNotifier<List<CanvasNode>, String> {
  @override
  Future<List<CanvasNode>> build(String canvasId) async {
    final repo = await ref.watch(nodeRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    return rows.map(CanvasNodeMapping.fromRow).toList(growable: false);
  }

  NodeRepository get _repo {
    final async = ref.read(nodeRepositoryProvider);
    final repo = async.valueOrNull;
    if (repo == null) {
      throw StateError('nodeRepositoryProvider 尚未就绪');
    }
    return repo;
  }

  /// 新增节点。乐观插入——先改内存，DB 失败则回滚。
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    Offset position = Offset.zero,
    Size size = const Size(200, 160),
  }) async {
    assert(
      role != NodeRole.result || sourceNodeId != null,
      'result 节点必须带 sourceNodeId（§4.5.1）',
    );
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final canvasId = arg;
    try {
      final id = await _repo.create(
        canvasId: canvasId,
        type: type.name,
        nodeRole: role.name,
        label: label,
        sourceNodeId: sourceNodeId,
        positionX: position.dx,
        positionY: position.dy,
        width: size.width,
        height: size.height,
      );
      final inserted = CanvasNode(
        id: id,
        label: label,
        type: type,
        role: role,
        canvasId: canvasId,
        sourceNodeId: sourceNodeId,
        position: position,
        size: size,
      );
      state = AsyncData([...previous, inserted]);
      return inserted;
    } catch (_) {
      // 保底：确保 state 停在 previous，不被外层框架翻成 AsyncError。
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// 软删除节点。乐观移除——先改内存，DB 失败则回滚。
  Future<void> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final next = previous.where((n) => n.id != id).toList(growable: false);
    state = AsyncData(next);
    try {
      await _repo.softDelete(id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// 本阶段纯内存位移——拖拽结束后持久化由 S3 处理。
  void moveNode(String id, Offset delta) {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final n in previous)
        if (n.id == id) n.copyWith(position: n.position + delta) else n,
    ]);
  }
}
