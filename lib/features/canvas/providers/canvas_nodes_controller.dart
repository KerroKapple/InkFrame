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
//
// 导入媒体：addImportShell 建无来源的导入壳（role = result、origin = import），
// discardImportShell 硬删复制失败的空壳；二者与 addNode 共用 _insert / 同一条串行队列。
//
// 批量写（文件末尾）：moveNodes / removeNodes / restoreAll / patchTypeConfigMany 各一个
// 事务，失败整批回滚内存；replaceTypeConfig 单语句整列覆盖。都与单个写走同一条串行队列。

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/import_keys.dart';
import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/node_repository.dart';
import '../models/canvas_node.dart';
import '../models/canvas_node_import.dart';
import '../util/canvas_extent.dart';
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

/// moveNodes 里一张卡的挪法：与 moveNode(id, delta, laneId:) 同语义——
/// 新位置 = 当前位置 + [delta]（夹在 ±kWorldReach），[laneId] 为 null 即移出泳道。
typedef NodeMove = ({Offset delta, String? laneId});

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
    // 存量越界坐标（旧生长模型 >50k）加载期收敛进可达范围——只改内存不回写，
    // 幂等；用户后续拖动经 moveNode 才落库（#186 评审 P2-1）。
    return rows
        .map(CanvasNodeMapping.fromRow)
        .map((n) {
          final clamped = clampIntoWorldReach(n.position);
          return identical(clamped, n.position) ? n : n.copyWith(position: clamped);
        })
        .toList(growable: false);
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
    String? laneId,
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
    return _insert(
      label: label,
      type: type,
      role: role,
      sourceNodeId: sourceNodeId,
      laneId: laneId,
      position: position,
      size: nodeSize,
      typeConfig: typeConfig,
      projectId: null,
    );
  }

  /// 导入媒体的壳节点：role = result、sourceNodeId = null（没有来源配置节点），
  /// type_config 只有 origin = import 与原文件名——url 等复制完由导入控制器回写。
  ///
  /// origin 由本方法写死，调用方传不进别的值。[label] 由调用方截到 ≤ 200 个字符
  /// （库约束 chk_node_label_len）。[projectId] 写进内存节点：卡片拿它解析产物路径，
  /// 为 null 时只画占位。乐观插入，DB 失败回滚并上抛。
  Future<CanvasNode> addImportShell({
    required String label,
    required CanvasNodeType type,
    required String projectId,
    String? laneId,
    Offset position = Offset.zero,
    String? originalName,
  }) async {
    assert(
      type == CanvasNodeType.image || type == CanvasNodeType.video,
      'import shell must be an image or video node',
    );
    return _insert(
      label: label,
      type: type,
      role: NodeRole.result,
      sourceNodeId: null,
      laneId: laneId,
      position: position,
      size: defaultNodeSize(type),
      typeConfig: <String, Object?>{
        ImportKeys.origin: ImportKeys.originImport,
        if (originalName != null) ImportKeys.originalName: originalName,
      },
      projectId: projectId,
    );
  }

  /// 删掉复制失败的导入壳：**硬删**（失败的壳不进回收站）。
  ///
  /// 内存里有这张卡：必须是导入节点且 image_url / video_url / thumbnail_url 都为空，否则什么也
  /// 不做（防误删已完成的导入或别的节点）；乐观移出内存再硬删。内存里没有（复制途中用户删了它 /
  /// 画布已重载）：照样硬删——调用方只有导入控制器，只会传它自己刚建的壳。
  /// 成功后让 CanvasEdgesController 失效：复制期间用户若从壳上拉过线，库里 ON DELETE CASCADE
  /// 已经删了边。DB 失败 ⇒ 内存回滚，InkError 上抛。
  Future<void> discardImportShell(String id) {
    final repo = _repo; // 入口一次性解析，串行 op 内不再触 ref
    final canvasId = arg;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      CanvasNode? target;
      for (final n in previous) {
        if (n.id == id) target = n;
      }
      if (target != null) {
        final bool emptyShell = target.isImported &&
            target.imageUrl == null &&
            target.videoUrl == null &&
            target.thumbnailUrl == null;
        if (!emptyShell) return;
        if (_alive) {
          state = AsyncData(previous.where((n) => n.id != id).toList(growable: false));
        }
      }
      try {
        await repo.hardDelete(id);
        if (_alive) ref.invalidate(canvasEdgesControllerProvider(canvasId));
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// addNode / addImportShell 共用的串行插入体：先写库、成功后插进内存，失败 state 停在原样。
  Future<CanvasNode> _insert({
    required String label,
    required CanvasNodeType type,
    required NodeRole role,
    required String? sourceNodeId,
    required String? laneId,
    required Offset position,
    required Size size,
    required Map<String, Object?> typeConfig,
    required String? projectId,
  }) {
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
          laneId: laneId,
          positionX: position.dx,
          positionY: position.dy,
          width: size.width,
          height: size.height,
          typeConfig: typeConfig,
        );
        final inserted = CanvasNode(
          id: id,
          label: label,
          type: type,
          role: role,
          projectId: projectId,
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          laneId: laneId,
          typeConfig: typeConfig,
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
      // 全向无限画布：负坐标合法，落点 clamp 到可漫游范围 ±kWorldReach
      // （距 100k 居中定舞台边缘留余量，见 util/canvas_extent.dart）。
      final raw = target.position + delta;
      final newPos = Offset(
        raw.dx.clamp(-kWorldReach, kWorldReach),
        raw.dy.clamp(-kWorldReach, kWorldReach),
      );
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

  // ===== 批量写：各一个事务，失败整批回滚内存 =====

  /// 整组挪动：一个事务里逐个写 position_x / position_y / lane_id。
  ///
  /// 只处理此刻在内存里的 id（不在的跳过）；落点夹在 ±kWorldReach；laneId 为 null 即移出泳道。
  /// 空 map 或一个都不在 ⇒ 不碰库。任一行写失败 ⇒ 内存整批回到调用前，InkError 上抛。
  Future<void> moveNodes(Map<String, NodeMove> moves) {
    if (moves.isEmpty) return Future<void>.value();
    final requested = Map<String, NodeMove>.of(moves); // 调用方之后改 map 不影响这次
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析，串行 op 内不触 ref
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      final byId = <String, CanvasNode>{for (final n in previous) n.id: n};
      final targets = <String, ({Offset position, String? laneId})>{};
      for (final entry in requested.entries) {
        final node = byId[entry.key];
        if (node == null) continue;
        final raw = node.position + entry.value.delta;
        targets[entry.key] = (
          position: Offset(
            raw.dx.clamp(-kWorldReach, kWorldReach),
            raw.dy.clamp(-kWorldReach, kWorldReach),
          ),
          laneId: entry.value.laneId,
        );
      }
      if (targets.isEmpty) return;
      if (_alive) {
        state = AsyncData([
          for (final n in previous)
            if (targets.containsKey(n.id))
              n.copyWith(
                position: targets[n.id]!.position,
                laneId: targets[n.id]!.laneId,
                clearLaneId: targets[n.id]!.laneId == null,
              )
            else
              n,
        ]);
      }
      try {
        final uow = await uowFuture;
        await uow.run((scope) async {
          for (final entry in targets.entries) {
            await scope.nodes.update(entry.key, <String, Object?>{
              NodeCol.positionX: entry.value.position.dx,
              NodeCol.positionY: entry.value.position.dy,
              NodeCol.laneId: entry.value.laneId,
            });
          }
        });
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 整批删除：一个事务里软删全部节点及其入 / 出边，返回撤销令牌（顺序 = [ids] 的迭代顺序）。
  ///
  /// 事务内分两段：**先**按 [ids] 顺序列完全部入 / 出边并去重（同一条边只归第一个列到它的节点的
  /// 令牌），**再**统一软删边与节点——交错着「列一张删一张」的话，后面那张已经列不到本事务刚软删的
  /// 边，去重形同虚设。不在内存里的 id 照 removeNode 口径仍软删、但不产令牌。空集合 ⇒ 不碰库。
  /// 任一步失败 ⇒ 库里整批回滚（真事务），内存整批放回，InkError 上抛。
  Future<List<NodeDeletion>> removeNodes(Set<String> ids) {
    if (ids.isEmpty) return Future<List<NodeDeletion>>.value(const <NodeDeletion>[]);
    final order = List<String>.of(ids, growable: false);
    final idSet = order.toSet();
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析，串行 op 内不触 ref
    return serialize<List<NodeDeletion>>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      final byId = <String, CanvasNode>{for (final n in previous) n.id: n};
      if (_alive) {
        state = AsyncData(
          previous.where((n) => !idSet.contains(n.id)).toList(growable: false),
        ); // 乐观更新
      }
      try {
        final uow = await uowFuture;
        final edgeIdsOf = await uow.run((scope) async {
          // 第一段：只读——列边、去重、归属。
          final seen = <String>{};
          final planned = <String, List<String>>{};
          for (final id in order) {
            final outgoing = await scope.edges.listOutgoing(id);
            final incoming = await scope.edges.listIncoming(id);
            final mine = <String>[];
            for (final r in <Map<String, Object?>>[...outgoing, ...incoming]) {
              final eid = r.reqId(EdgeCol.id);
              if (seen.add(eid)) mine.add(eid);
            }
            planned[id] = mine;
          }
          // 第二段：写——先边后节点。
          for (final id in order) {
            for (final eid in planned[id]!) {
              await scope.edges.softDelete(eid);
            }
          }
          for (final id in order) {
            await scope.nodes.softDelete(id);
          }
          return planned;
        });
        if (_alive) ref.invalidate(canvasEdgesControllerProvider(canvasId));
        return <NodeDeletion>[
          for (final id in order)
            if (byId.containsKey(id))
              (node: byId[id]!, edgeIds: edgeIdsOf[id] ?? const <String>[]),
        ];
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 撤销 removeNodes：一个事务里复原全部令牌的节点与边（节点 / 边 id 各自去重）；
  /// 内存里已经在的节点不重复插入。
  ///
  /// 返回 Σ nodes.restore 的受影响行数：全部为 0（行已被硬删）⇒ 调用方可判「对象已不在」。
  /// 受影响行数为 0 的节点不留在内存里（库里没有它，留着就是一张点什么都写失败的卡）。
  /// 失败 ⇒ 内存回到调用前、InkError 上抛。画布已关（provider 已 dispose）⇒ 直接返回 0。
  Future<int> restoreAll(List<NodeDeletion> deletions) {
    // 入口守卫（先于任何同步 ref.read），理由同 restore。
    if (!_alive) return Future<int>.value(0);
    if (deletions.isEmpty) return Future<int>.value(0);
    final tokens = List<NodeDeletion>.of(deletions, growable: false);
    final canvasId = arg;
    final uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<int>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      final present = <String>{for (final n in previous) n.id};
      final inserted = <CanvasNode>[];
      for (final d in tokens) {
        if (present.add(d.node.id)) inserted.add(d.node);
      }
      if (_alive) state = AsyncData([...previous, ...inserted]); // 乐观复原
      final nodeIds = <String>{for (final d in tokens) d.node.id};
      final edgeIds = <String>{for (final d in tokens) ...d.edgeIds};
      final gone = <String>{};
      try {
        final uow = await uowFuture;
        final affected = await uow.run((scope) async {
          var sum = 0;
          for (final id in nodeIds) {
            final n = await scope.nodes.restore(id);
            if (n == 0) gone.add(id);
            sum += n;
          }
          for (final eid in edgeIds) {
            await scope.edges.restore(eid);
          }
          return sum;
        });
        if (_alive) {
          ref.invalidate(canvasEdgesControllerProvider(canvasId));
          final insertedIds = <String>{for (final n in inserted) n.id};
          final phantom = gone.intersection(insertedIds);
          if (phantom.isNotEmpty) {
            state = AsyncData([
              for (final n in state.valueOrNull ?? const <CanvasNode>[])
                if (!phantom.contains(n.id)) n,
            ]);
          }
        }
        return affected;
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 多张卡的 type_config 一起 patch：一个事务里逐个 patchTypeConfig。
  ///
  /// 内存按 `{...旧, ...patch}` 合并——值为 null 即写 JSON null、不删键（与 jsonb `||` 一致）；
  /// 不在内存的 id 跳过。任一行失败 ⇒ 内存整批回滚，InkError 上抛。
  Future<void> patchTypeConfigMany(Map<String, Map<String, Object?>> patches) {
    if (patches.isEmpty) return Future<void>.value();
    final requested = <String, Map<String, Object?>>{
      for (final e in patches.entries) e.key: Map<String, Object?>.of(e.value),
    };
    final uowFuture = ref.read(unitOfWorkProvider.future); // 入口解析，串行 op 内不触 ref
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      final present = <String>{for (final n in previous) n.id};
      final targets = <String, Map<String, Object?>>{
        for (final e in requested.entries)
          if (present.contains(e.key)) e.key: e.value,
      };
      if (targets.isEmpty) return;
      if (_alive) {
        state = AsyncData([
          for (final n in previous)
            if (targets.containsKey(n.id))
              n.copyWith(
                typeConfig: <String, Object?>{...n.typeConfig, ...targets[n.id]!},
              )
            else
              n,
        ]);
      }
      try {
        final uow = await uowFuture;
        await uow.run((scope) async {
          for (final e in targets.entries) {
            await scope.nodes.patchTypeConfig(e.key, e.value);
          }
        });
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 整列覆盖一张卡的 type_config（撤销改参数时要删掉原来没有的键，patch 做不到）。
  ///
  /// 走 NodeRepository.update（type_config 整列 `::jsonb` 覆盖），单语句不需要事务；
  /// 节点不在内存 ⇒ 什么也不做。失败 ⇒ 回滚该节点的 type_config，InkError 上抛。
  Future<void> replaceTypeConfig(String id, Map<String, Object?> full) {
    final repo = _repo; // 入口一次性解析，串行 op 内不再触 ref
    final config = Map<String, Object?>.of(full);
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasNode>[]) : const <CanvasNode>[];
      if (!previous.any((n) => n.id == id)) return;
      if (_alive) {
        state = AsyncData([
          for (final n in previous)
            if (n.id == id) n.copyWith(typeConfig: config) else n,
        ]);
      }
      try {
        await repo.update(id, <String, Object?>{NodeCol.typeConfig: config});
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }
}
