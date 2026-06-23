// CanvasNodesController — DB-backed 画布节点集合。
//
// 替代早期纯内存的 CanvasViewModel（S1a 之前）。按 canvasId 分族，每个画布一份状态。
//
// 持久化策略：
//   - load / add / remove → 经 NodeRepository 过 DB
//   - moveNode → 拖拽结束后持久化 position_x/y + lane_id（乐观更新 + 失败回滚）
//
// 失败策略：add/remove/move 采用"先改内存再持久化"。若 DB 失败则回滚内存并把错误
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
  /// ME-27：autoDispose family 下，await 期间 provider 可能被 dispose——
  /// 之后再触 ref / state 会抛 StateError。依赖在方法入口一次性解析，
  /// await 之后的 ref / state 访问一律先查本标志。
  bool _alive = false;

  @override
  Future<List<CanvasNode>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(nodeRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    return rows.map(CanvasNodeMapping.fromRow).toList(growable: false);
  }

  NodeRepository get _repo {
    final async = ref.read(nodeRepositoryProvider);
    final repo = async.valueOrNull;
    if (repo == null) {
      throw StateError('nodeRepositoryProvider is not ready');
    }
    return repo;
  }

  /// 按需拉 EdgeRepository。入口同步发起 read，未 override 的环境下
  /// 会抛（如离线单测），调用方应 catch 并 best-effort 跳过。
  Future<EdgeRepository?> _edgeRepoOrNull() async {
    final Future<EdgeRepository> future;
    try {
      future = ref.read(edgeRepositoryProvider.future);
    } catch (_) {
      return null;
    }
    try {
      return await future;
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
      'result node requires sourceNodeId (PRD 4.5.1)',
    );
    final repo = _repo; // 入口一次性解析，await 后不再触 ref
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final canvasId = arg;
    try {
      final id = await repo.create(
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
      if (_alive) state = AsyncData([...previous, inserted]);
      return inserted;
    } on InkError catch (_) {
      // 保底：确保 state 停在 previous，不被外层框架翻成 AsyncError。
      if (_alive) state = AsyncData(previous);
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
    final repo = _repo; // 入口一次性解析，await 后不再触 ref
    final canvasId = arg;
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final next = previous.where((n) => n.id != id).toList(growable: false);
    state = AsyncData(next);

    final edgeRepo = await _edgeRepoOrNull();
    if (edgeRepo != null) {
      await _softDeleteConnectedEdges(edgeRepo, id);
      // invalidate edges controller 让 UI 同步；dispose 后跳过（DB 已删成功）。
      if (_alive) {
        ref.invalidate(canvasEdgesControllerProvider(canvasId));
      }
    }

    try {
      await repo.softDelete(id);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
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

  /// 拖动结束：持久化新位置 + 归属泳道（laneId 可为 null=移出所有泳道）。
  /// 乐观更新内存，DB 失败回滚并上抛（UI toast）。
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? target;
    for (final n in previous) {
      if (n.id == id) target = n;
    }
    if (target == null) return;
    final newPos = target.position + delta;
    state = AsyncData([
      for (final n in previous)
        if (n.id == id)
          n.copyWith(position: newPos, laneId: laneId, clearLaneId: laneId == null)
        else
          n,
    ]);
    try {
      await repo.update(id, <String, Object?>{
        'position_x': newPos.dx,
        'position_y': newPos.dy,
        'lane_id': laneId,
      });
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
}
