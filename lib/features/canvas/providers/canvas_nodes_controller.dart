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

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/node_repository.dart';
import '../models/canvas_node.dart';
import 'canvas_edges_controller.dart';
import 'serial_mutation_queue.dart';

final canvasNodesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasNodesController, List<CanvasNode>, String>(
  CanvasNodesController.new,
  name: 'canvasNodesControllerProvider',
);

/// removeNode 的撤销令牌（PL-4a）：被删节点 + 同事务级联软删的 edge id，
/// 供 restore 精确复原节点及其关联连线。
typedef NodeDeletion = ({CanvasNode node, List<String> edgeIds});

class CanvasNodesController
    extends AutoDisposeFamilyAsyncNotifier<List<CanvasNode>, String>
    with SerialMutationQueue {
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

  /// 新增节点。乐观插入——先改内存，DB 失败则回滚。
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    // 未显式传 size → 按类型取默认（media 类更大）。
    final Size nodeSize = size ?? defaultNodeSize(type);
    assert(
      role != NodeRole.result || sourceNodeId != null,
      'result node requires sourceNodeId (PRD 4.5.1)',
    );
    final repo = _repo; // 入口一次性解析，串行 op 内不再触 ref
    final canvasId = arg;
    return serialize<CanvasNode>(() async {
      // 快照在串行 op 内读取，保证读到前序变更已提交的最新态（LB-04）。
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      try {
        final id = await repo.create(
          canvasId: canvasId,
          type: type.name,
          nodeRole: role.name,
          label: label,
          sourceNodeId: sourceNodeId,
          positionX: position.dx,
          positionY: position.dy,
          width: nodeSize.width,
          height: nodeSize.height,
          typeConfig: typeConfig,
        );
        final inserted = CanvasNode(
          id: id,
          label: label,
          type: type,
          role: role,
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          typeConfig: typeConfig,
          position: position,
          size: nodeSize,
        );
        if (_alive) state = AsyncData([...previous, inserted]);
        return inserted;
      } on InkError catch (_) {
        // 保底：确保 state 停在 previous，不被外层框架翻成 AsyncError。
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 软删除节点 + 级联软删所有关联 edges（入/出）——单事务原子（PRD §4.3）。
  ///
  /// schema 的 ON DELETE CASCADE 仅在硬删时兜底；软删走应用层级联。
  /// 乐观更新内存；事务内任一步失败 → 整体回滚 + 内存复原 + InkError 冒泡。
  /// 成功后让 CanvasEdgesController(canvasId) 失效，UI 重新加载新边集。
  ///
  /// 返回撤销令牌（被删节点 + 级联软删的 edge id）供 PL-4a undo；节点不在内存
  /// （已被移除 / provider 已 dispose）时返回 null——无可撤销对象。
  Future<NodeDeletion?> removeNode(String id) {
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析，串行 op 内不触 ref
    return serialize<NodeDeletion?>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      CanvasNode? removed;
      for (final n in previous) {
        if (n.id == id) removed = n;
      }
      final next = previous.where((n) => n.id != id).toList(growable: false);
      if (_alive) state = AsyncData(next); // 乐观更新

      final deletedEdgeIds = <String>[];
      try {
        final uow = await uowFuture;
        await uow.run((scope) async {
          final outgoing = await scope.edges.listOutgoing(id);
          final incoming = await scope.edges.listIncoming(id);
          final edgeIds = <String>{
            for (final r in outgoing) r.reqId(EdgeCol.id),
            for (final r in incoming) r.reqId(EdgeCol.id),
          };
          for (final eid in edgeIds) {
            await scope.edges.softDelete(eid);
          }
          await scope.nodes.softDelete(id);
          deletedEdgeIds.addAll(edgeIds);
        });
        if (_alive) ref.invalidate(canvasEdgesControllerProvider(canvasId));
        if (removed == null) return null;
        return (node: removed, edgeIds: deletedEdgeIds);
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 撤销 removeNode（PL-4a 删除防误伤）：清 deleted_at 复原节点及其级联 edges，
  /// 单事务原子；乐观把节点放回内存，DB 失败回滚并上抛。成功后让
  /// CanvasEdgesController(canvasId) 失效，重新加载复原后的边集。
  Future<void> restore(NodeDeletion deletion) {
    // 入口守卫（先于任何同步 ref.read）：画布关闭后 snackbar 仍挂在全局
    // messenger 上可点，此时 notifier 已 autoDispose——复原进已销毁画布无意义，
    // 且 ref.read 会同步抛 StateError。ME-27 的 _alive 只护 await 后的写，故这里
    // 补一道方法入口守卫。
    if (!_alive) return Future<void>.value();
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      if (_alive) state = AsyncData([...previous, deletion.node]); // 乐观复原
      try {
        final uow = await uowFuture;
        await uow.run((scope) async {
          await scope.nodes.restore(deletion.node.id);
          for (final eid in deletion.edgeIds) {
            await scope.edges.restore(eid);
          }
        });
        if (_alive) ref.invalidate(canvasEdgesControllerProvider(canvasId));
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 拖动结束：持久化新位置 + 归属泳道（laneId 可为 null=移出所有泳道）。
  /// 乐观更新内存，DB 失败回滚并上抛（UI toast）。
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      CanvasNode? target;
      for (final n in previous) {
        if (n.id == id) target = n;
      }
      if (target == null) return;
      final newPos = target.position + delta;
      if (_alive) {
        state = AsyncData([
          for (final n in previous)
            if (n.id == id)
              n.copyWith(
                  position: newPos, laneId: laneId, clearLaneId: laneId == null)
            else
              n,
        ]);
      }
      try {
        await repo.update(id, <String, Object?>{
          NodeCol.positionX: newPos.dx,
          NodeCol.positionY: newPos.dy,
          NodeCol.laneId: laneId,
        });
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }
}
