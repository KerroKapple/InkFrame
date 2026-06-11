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
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../../../core/interfaces/node_repository.dart';
import '../models/canvas_node.dart';
import 'canvas_edges_controller.dart';

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

  /// 按需拉 EdgeRepository。首次触发时走一次 future；未 override 的环境下
  /// 会抛（如离线单测），调用方应 catch 并 best-effort 跳过。
  Future<EdgeRepository?> _edgeRepoOrNull() async {
    try {
      return await ref.read(edgeRepositoryProvider.future);
    } catch (_) {
      return null;
    }
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
    } on InkError catch (_) {
      // 保底：确保 state 停在 previous，不被外层框架翻成 AsyncError。
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// 软删除节点 + 级联软删所有关联 edges（入/出）。
  ///
  /// PRD §4.3 "删除节点时，关联连线标记 deleted_at 而非物理删除（应用层拦截，
  /// 不依赖 CASCADE）"。schema 的 ON DELETE CASCADE 仅在硬删时兜底。
  ///
  /// 顺序：先删 edges（单条失败不阻断，best-effort），再删 node。
  /// Node DB 失败 → 回滚内存；已删 edges 留孤儿，用户可重试 node 删除。
  /// 同时让 CanvasEdgesController(canvasId) 失效，UI 立即重新加载新边集。
  Future<void> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final next = previous.where((n) => n.id != id).toList(growable: false);
    state = AsyncData(next);

    final edgeRepo = await _edgeRepoOrNull();
    if (edgeRepo != null) {
      await _softDeleteConnectedEdges(edgeRepo, id);
      // invalidate edges controller 让 UI 同步。
      ref.invalidate(canvasEdgesControllerProvider(arg));
    }

    try {
      await _repo.softDelete(id);
    } on InkError catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> _softDeleteConnectedEdges(
    EdgeRepository edgeRepo,
    String nodeId,
  ) async {
    final List<Map<String, Object?>> outgoing;
    final List<Map<String, Object?>> incoming;
    try {
      outgoing = await edgeRepo.listOutgoing(nodeId);
      incoming = await edgeRepo.listIncoming(nodeId);
    } on InkError catch (_) {
      return; // 列表失败就放弃级联，不阻断节点删除（best-effort）。
    }
    final ids = <String>{
      for (final r in outgoing) r['id']!.toString(),
      for (final r in incoming) r['id']!.toString(),
    };
    for (final eid in ids) {
      try {
        await edgeRepo.softDelete(eid);
      } on InkError catch (_) {
        // 单条失败不阻断其他——best-effort。
      }
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
