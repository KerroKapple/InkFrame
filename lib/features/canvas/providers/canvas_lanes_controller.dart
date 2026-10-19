// CanvasLanesController — DB-backed 画布泳道集合（按 canvasId 分族）。
// 乐观更新 + 失败回滚，与 CanvasNodesController 同策略（ME-27 _alive 守卫）。
//
// 解散泳道 / 删除泳道和内容（文件末尾）不是乐观移除：道里的节点在同一个事务里直写 scope.nodes
// （不经节点控制器），提交后让节点 / 边控制器失效、等节点重载完，最后才改泳道 state。撤销令牌与
// 位置换算在 util/lane_dissolve.dart；带 BuildContext 的动作（撤销卡、确认框、取消任务）在
// util/canvas_lane_actions.dart。两项都不登记撤销栈。
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/style_lane_repository.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../models/style_lane.dart';
import '../util/lane_dissolve.dart';
import '../util/lane_geometry.dart';
import 'canvas_edges_controller.dart';
import 'canvas_nodes_controller.dart';
import 'serial_mutation_queue.dart';

final canvasLanesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasLanesController, List<StyleLane>, String>(
  CanvasLanesController.new,
  name: 'canvasLanesControllerProvider',
);

class CanvasLanesController
    extends AutoDisposeFamilyAsyncNotifier<List<StyleLane>, String>
    with SerialMutationQueue {
  bool _alive = false;

  @override
  Future<List<StyleLane>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(styleLaneRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    final lanes = rows.map(StyleLane.fromRow).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return lanes;
  }

  StyleLaneRepository get _repo {
    final repo = ref.read(styleLaneRepositoryProvider).valueOrNull;
    if (repo == null) throw StateError('styleLaneRepositoryProvider not ready');
    return repo;
  }

  Future<StyleLane> createLane({
    String label = '',
    String stylePrompt = '',
    String? tintColor,
  }) {
    final repo = _repo;
    final canvasId = arg;
    return serialize<StyleLane>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <StyleLane>[]) : const <StyleLane>[];
      final nextOrder = previous.isEmpty
          ? 0
          : previous.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      final id = await repo.create(
        canvasId: canvasId,
        label: label,
        stylePrompt: stylePrompt,
        sortOrder: nextOrder,
        tintColor: tintColor,
      );
      final lane = StyleLane(
        id: id,
        canvasId: canvasId,
        label: label,
        stylePrompt: stylePrompt,
        sortOrder: nextOrder,
        tintColor: tintColor,
      );
      if (_alive) state = AsyncData([...previous, lane]);
      return lane;
    });
  }

  Future<void> updateLane(
    String id, {
    String? label,
    String? stylePrompt,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <StyleLane>[]) : const <StyleLane>[];
      final patch = <String, Object?>{
        StyleLaneCol.label: ?label,
        StyleLaneCol.stylePrompt: ?stylePrompt,
        if (clearTint)
          StyleLaneCol.tintColor: null
        else
          StyleLaneCol.tintColor: ?tintColor,
        StyleLaneCol.size: ?size,
      };
      if (patch.isEmpty) return;
      if (_alive) {
        state = AsyncData([
          for (final l in previous)
            if (l.id == id)
              l.copyWith(
                label: label,
                stylePrompt: stylePrompt,
                tintColor: tintColor,
                clearTint: clearTint,
                size: size,
              )
            else
              l,
        ]);
      }
      try {
        await repo.update(id, patch);
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 按给定 id 顺序重排泳道，sort_order=下标。乐观更新 + 失败回滚。
  /// 所有 sort_order 更新落在单个 UnitOfWork 事务内（原子，半重排不可见）。
  Future<void> reorderLanes(List<String> orderedIds) {
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <StyleLane>[]) : const <StyleLane>[];
      final byId = {for (final l in previous) l.id: l};
      final reordered = <StyleLane>[];
      for (var i = 0; i < orderedIds.length; i++) {
        final lane = byId[orderedIds[i]];
        if (lane != null) reordered.add(lane.copyWith(sortOrder: i));
      }
      if (reordered.length != previous.length) return; // 不完整顺序，跳过
      if (_alive) state = AsyncData(reordered);
      try {
        final uow = await uowFuture;
        await uow.run((scope) async {
          for (var i = 0; i < reordered.length; i++) {
            if (byId[reordered[i].id]!.sortOrder != i) {
              await scope.styleLanes.update(
                  reordered[i].id, <String, Object?>{StyleLaneCol.sortOrder: i});
            }
          }
        });
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  // ===== 解散泳道 / 删除泳道和内容 =====

  /// 解散泳道（节点留下）：一个事务里把**库里** lane_id == [laneId] 的节点 lane_id 清空（[positions] 里有的
  /// 一并写新世界坐标——屏幕上不动的那一点，见 lane_dissolve.dart 的 dissolvedPositions），再软删道。
  ///
  /// 道内节点按库查：内存里没载到、但库里还指着这条道的也一并清掉。令牌里的旧坐标取事务里读到的行。
  /// 不是乐观移除：提交后先让节点控制器重载、等它载完，再把道从 state 里拿掉——反过来道先消失、卡片
  /// 还按旧 lane_id 画，会闪一帧。道不在 state 里 ⇒ null、不碰库。事务失败 ⇒ state 原样、节点控制器
  /// 不失效，InkError 上抛。
  Future<LaneDissolution?> dissolveLane(
    String laneId, {
    required Map<String, Offset> positions,
  }) {
    final canvasId = arg;
    final requested = Map<String, Offset>.of(positions); // 调用方之后改 map 不影响这次
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析
    return serialize<LaneDissolution?>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <StyleLane>[]) : const <StyleLane>[];
      final lane = _laneIn(previous, laneId);
      if (lane == null) return null;
      final uow = await uowFuture;
      final snapshots = await uow.run<List<LaneNodeSnapshot>>((scope) async {
        final rows = await scope.nodes.listByCanvas(canvasId);
        final taken = <LaneNodeSnapshot>[];
        for (final row in rows) {
          if (row.optId(NodeCol.laneId) != laneId) continue;
          final id = row.reqId(NodeCol.id);
          taken.add((
            nodeId: id,
            position: Offset(
              row.optDouble(NodeCol.positionX) ?? 0,
              row.optDouble(NodeCol.positionY) ?? 0,
            ),
          ));
          final to = requested[id];
          await scope.nodes.update(id, <String, Object?>{
            if (to != null) NodeCol.positionX: to.dx,
            if (to != null) NodeCol.positionY: to.dy,
            NodeCol.laneId: null,
          });
        }
        await scope.styleLanes.softDelete(laneId);
        return taken;
      });
      await _reloadNodes(canvasId);
      _dropLane(laneId, previous);
      return LaneDissolution(lane: lane, nodes: snapshots);
    });
  }

  /// 撤销解散：一个事务里复原道，节点写回旧世界坐标与旧 lane_id（撤销前已被删的节点跳过）；
  /// 复原的道与现存道 sort_order 撞号时同一事务里重排编号，复原的道回到旧下标。
  ///
  /// 道已经复原过（restore 0 行）⇒ 空操作。画布已关（控制器已 dispose）⇒ 空操作、不抛。
  /// 先把道放回 state、再重载节点：节点重载前还按道外坐标画在原处，道回来后它们换回道内坐标，屏幕不跳。
  Future<void> restoreDissolved(LaneDissolution token) {
    // 入口守卫（先于任何同步 ref.read）：撤销卡在画布关掉后仍可点，理由同 CanvasNodesController.restore。
    if (!_alive) return Future<void>.value();
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<void>(() async {
      final uow = await uowFuture;
      final lanes = await uow.run<List<StyleLane>?>((scope) async {
        if (await scope.styleLanes.restore(token.lane.id) == 0) return null;
        for (final s in token.nodes) {
          if (await scope.nodes.findById(s.nodeId) == null) continue; // 撤销前已被删
          await scope.nodes.update(s.nodeId, <String, Object?>{
            NodeCol.positionX: s.position.dx,
            NodeCol.positionY: s.position.dy,
            NodeCol.laneId: token.lane.id,
          });
        }
        return _reseatRestoredLane(scope, canvasId, token.lane.id);
      });
      if (lanes == null) return;
      if (_alive) state = AsyncData(lanes);
      await _reloadNodes(canvasId);
    });
  }

  /// 删除泳道和内容：一个事务里软删道内全部节点（按库查 lane_id，含产物节点）、这些节点的全部入 / 出边
  /// （去重）、再软删道。道外节点之间的边不动。
  ///
  /// 事务内分两段（同 CanvasNodesController.removeNodes）：先列完全部边并去重，再统一软删边 → 节点 → 道。
  /// 提交后边控制器失效、等节点重载完，最后把道从 state 里拿掉。道不在 state 里 ⇒ null、不碰库。
  /// 事务失败 ⇒ state 原样、InkError 上抛。生成中任务的确认与取消在动作层，这里不管。
  Future<LaneContentsDeletion?> deleteLaneWithContents(String laneId) {
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析
    return serialize<LaneContentsDeletion?>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <StyleLane>[]) : const <StyleLane>[];
      final lane = _laneIn(previous, laneId);
      if (lane == null) return null;
      final uow = await uowFuture;
      final token = await uow.run<LaneContentsDeletion>((scope) async {
        final rows = await scope.nodes.listByCanvas(canvasId);
        final nodeIds = <String>[
          for (final row in rows)
            if (row.optId(NodeCol.laneId) == laneId) row.reqId(NodeCol.id),
        ];
        // 第一段：只读——列边、去重。
        final seen = <String>{};
        final edgeIds = <String>[];
        for (final id in nodeIds) {
          final outgoing = await scope.edges.listOutgoing(id);
          final incoming = await scope.edges.listIncoming(id);
          for (final r in <Map<String, Object?>>[...outgoing, ...incoming]) {
            final eid = r.reqId(EdgeCol.id);
            if (seen.add(eid)) edgeIds.add(eid);
          }
        }
        // 第二段：写——边、节点、道。
        for (final eid in edgeIds) {
          await scope.edges.softDelete(eid);
        }
        for (final id in nodeIds) {
          await scope.nodes.softDelete(id);
        }
        await scope.styleLanes.softDelete(laneId);
        return LaneContentsDeletion(lane: lane, nodeIds: nodeIds, edgeIds: edgeIds);
      });
      _invalidateEdges(canvasId);
      await _reloadNodes(canvasId);
      _dropLane(laneId, previous);
      return token;
    });
  }

  /// 撤销删除泳道和内容：一个事务里复原道、节点、边；sort_order 撞号时同 [restoreDissolved] 重排。
  /// 被取消的任务不复原（确认框写明了）。道已经复原过 ⇒ 空操作；画布已关 ⇒ 空操作、不抛。
  Future<void> restoreLaneContents(LaneContentsDeletion token) {
    if (!_alive) return Future<void>.value(); // 入口守卫，同 restoreDissolved
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<void>(() async {
      final uow = await uowFuture;
      final lanes = await uow.run<List<StyleLane>?>((scope) async {
        if (await scope.styleLanes.restore(token.lane.id) == 0) return null;
        for (final id in token.nodeIds) {
          await scope.nodes.restore(id);
        }
        for (final eid in token.edgeIds) {
          await scope.edges.restore(eid);
        }
        return _reseatRestoredLane(scope, canvasId, token.lane.id);
      });
      if (lanes == null) return;
      if (_alive) state = AsyncData(lanes);
      _invalidateEdges(canvasId);
      await _reloadNodes(canvasId);
    });
  }

  static StyleLane? _laneIn(List<StyleLane> lanes, String laneId) {
    for (final l in lanes) {
      if (l.id == laneId) return l;
    }
    return null;
  }

  /// 把 [laneId] 从此刻的 state 里拿掉（state 不可用时以 [fallback] 为底）。
  void _dropLane(String laneId, List<StyleLane> fallback) {
    if (!_alive) return;
    state = AsyncData(<StyleLane>[
      for (final l in state.valueOrNull ?? fallback)
        if (l.id != laneId) l,
    ]);
  }

  /// 节点控制器此刻挂着（画布页在）就让它失效并等它从库里重载完；没挂就什么都不做（下次挂载自然从库读）。
  /// 没有 exists 这道守卫的话，没人 listen 时 read 出来的新实例可能在 future 完成前就被回收。
  Future<void> _reloadNodes(String canvasId) async {
    if (!_alive) return;
    final provider = canvasNodesControllerProvider(canvasId);
    if (!ref.exists(provider)) return;
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } on InkError catch (_) {
      // 库里已经提交；重载失败由节点控制器自己的错误态呈现，泳道照常往下改。
    }
  }

  void _invalidateEdges(String canvasId) {
    if (!_alive) return;
    final provider = canvasEdgesControllerProvider(canvasId);
    if (ref.exists(provider)) ref.invalidate(provider);
  }

  /// 复原 [laneId] 之后（同一事务里）的泳道顺序：与现存道 sort_order 不撞号 ⇒ 按库里的顺序原样返回；
  /// 撞号（解散后又重排过）⇒ 复原的道插回旧下标（现存道里 sort_order 比它小的有几条，它就排第几），
  /// 其余顺延，sort_order 重写成下标，只写变了的行。
  static Future<List<StyleLane>> _reseatRestoredLane(
    RepositoryScope scope,
    String canvasId,
    String laneId,
  ) async {
    final rows = await scope.styleLanes.listByCanvas(canvasId); // sort_order, created_at 升序
    final all = rows.map(StyleLane.fromRow).toList(growable: false);
    StyleLane? restored;
    final others = <StyleLane>[];
    for (final l in all) {
      if (l.id == laneId) {
        restored = l;
      } else {
        others.add(l);
      }
    }
    if (restored == null) return all;
    final int order = restored.sortOrder;
    if (!others.any((l) => l.sortOrder == order)) return all;
    final at = others.where((l) => l.sortOrder < order).length;
    final ordered = <StyleLane>[...others]..insert(at, restored);
    final out = <StyleLane>[];
    for (var i = 0; i < ordered.length; i++) {
      final l = ordered[i];
      if (l.sortOrder != i) {
        await scope.styleLanes.update(l.id, <String, Object?>{StyleLaneCol.sortOrder: i});
      }
      out.add(l.copyWith(sortOrder: i));
    }
    return out;
  }
}

/// 画布泳道方向（读 canvases.lane_direction）。
final canvasLaneDirectionProvider =
    FutureProvider.autoDispose.family<LaneDirection, String>((ref, canvasId) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final row = await repo.findById(canvasId);
  return laneDirectionFromString(
      row?.optString(CanvasCol.laneDirection) ?? 'horizontal');
});

/// 切换并持久化泳道方向，然后失效方向 provider 触发重读。
/// 取 WidgetRef（read/invalidate 即够用）——调用方均为 widget。
Future<void> setLaneDirection(WidgetRef ref, String canvasId, LaneDirection dir) async {
  final repo = await ref.read(canvasRepositoryProvider.future);
  await repo
      .update(canvasId, {CanvasCol.laneDirection: laneDirectionToString(dir)});
  ref.invalidate(canvasLaneDirectionProvider(canvasId));
}
