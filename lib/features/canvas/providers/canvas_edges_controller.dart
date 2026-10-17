// CanvasEdgesController — canvasId-family，DB-backed 连线集合。
//
// 与 CanvasNodesController 设计对齐：load / add / remove / updateRole 经
// EdgeRepository，失败回滚内存。
//
// 叙事链拼接（applySplice / spliceInsert / changeEdgeType / removeEdges /
// addEdgesInTx / replaceRoleEdge）：plan 由 util/narrative_splice.dart 的纯函数算，
// 这里只负责一个事务落库 + 内存同步 + 产撤销令牌；不登记撤销步。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../models/canvas_edge.dart';
import '../models/edge_endpoints.dart';
import '../util/create_menu_model.dart' show nextNarrativeSortOrder;
import '../util/narrative_splice.dart';
import 'serial_mutation_queue.dart';

/// [CanvasEdgesController.applySplice] 的结果：被删边快照、新边（含新 id）与撤销令牌。
typedef SpliceApplied = ({
  List<CanvasEdge> removed,
  List<CanvasEdge> added,
  SpliceUndoToken token,
});

/// [CanvasEdgesController.changeEdgeType] 的结果：软删的旧边、新建的边、同一事务里降为参考的边 id。
typedef EdgeTypeChanged = ({
  CanvasEdge removed,
  CanvasEdge created,
  Set<String> demotedIds,
});

/// [CanvasEdgesController.replaceRoleEdge] 的结果：被软删的同角色旧边、生效的那条。
typedef RoleEdgeReplaced = ({List<CanvasEdge> removed, CanvasEdge created});

const SpliceApplied _kEmptySplice = (
  removed: <CanvasEdge>[],
  added: <CanvasEdge>[],
  token: SpliceUndoToken(),
);

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
  ///
  /// [roleResolver] 不为空时**取代** [role]，并且在串行队列**内部**求值。这不是
  /// 风格偏好：智能默认 role（image→video 默认首帧）要看「目标节点现在有没有
  /// 首帧入边」，而在队列外读快照意味着——第一条首帧边的 DB 写入还在途时连第二
  /// 条，两次都读到「还没有首帧」⇒ 同一个节点上出现两条首帧入边。
  /// `uq_edges_live` 拦不住它（只拦同 source 同 role，不同 source 合法）。
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    EdgeRole Function(List<CanvasEdge> current)? roleResolver,
    int sortOrder = 0,
  }) {
    final canvasId = arg;
    final repo = _repo;
    return serialize<CanvasEdge>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      // 队头之前排着的 addEdge 已经把自己的边写进 state 了（写在 op 内、返回前），
      // 所以 previous 一定看得见它们——这正是解析器要的"现在"。
      final EdgeRole effectiveRole = roleResolver?.call(previous) ?? role;
      try {
        final id = await repo.create(
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          targetNodeId: targetNodeId,
          edgeType: CanvasEdgeMapping.typeToDb(edgeType),
          role: CanvasEdgeMapping.roleToDb(effectiveRole),
          sortOrder: sortOrder,
        );
        final edge = CanvasEdge(
          id: id,
          canvasId: canvasId,
          sourceNodeId: sourceNodeId,
          targetNodeId: targetNodeId,
          edgeType: edgeType,
          role: effectiveRole,
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
    // 入口守卫（先于 _repo 的同步 ref.read）：画布关闭后 snackbar 仍挂全局
    // messenger 可点，此时 notifier 已 autoDispose——复原无意义且 ref.read 会同步
    // 抛 StateError。ME-27 的 _alive 只护 await 后写，这里补方法入口守卫。
    if (!_alive) return Future<void>.value();
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      // 复原同样要守首帧 / 尾帧单选：删掉首帧那条之后用户可能已经把另一条改成
      // 了首帧，此时直接放回去就是两条。降级那一条才是更忠实的"撤销"——它当上
      // 首帧只是因为这一条被删了。
      final Set<String> demote = _conflictingFrameRoles(
        previous,
        targetNodeId: edge.targetNodeId,
        role: edge.role,
        exceptId: edge.id,
      );
      if (_alive) {
        state = AsyncData([
          for (final e in previous)
            if (demote.contains(e.id)) e.copyWith(role: EdgeRole.reference) else e,
          edge, // 乐观复原
        ]);
      }
      try {
        if (demote.isEmpty) {
          await repo.restore(edge.id);
        } else {
          final uow = await ref.read(unitOfWorkProvider.future);
          await uow.run<void>((RepositoryScope scope) async {
            for (final String id in demote) {
              await scope.edges.update(id, <String, Object?>{
                'role': CanvasEdgeMapping.roleToDb(EdgeRole.reference),
              });
            }
            await scope.edges.restore(edge.id);
          });
        }
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 变更已存在连线的 role（data edge 专用：reference / firstFrame / lastFrame）。
  /// 乐观更新内存后 DB 失败回滚。
  ///
  /// 【首帧 / 尾帧在同一目标节点上是单选】`GenerationTask` 的 `firstFramePath` /
  /// `lastFramePath` 各只有一个值，生成侧 `_resolveRefImages` 是
  /// `firstFrame ??= absPath`——两条同角色入边里必然有一条**被静默丢掉**。
  /// 所以改成首帧 / 尾帧时，同节点上原来那条在**同一个事务里**降级成参考图。
  /// 这和 `batch_results.promoted` 的单选同一手法：表上没有唯一约束（不同
  /// source 的同 role 入边在 schema 层是合法的），语义只能由写侧维持。
  ///
  /// 降级是无声的，但不是隐蔽的：被降级那条就在同一个入边区里，它的下拉当场
  /// 变成「参考图」，用户看得见。所以不额外弹提示。
  Future<void> updateRole(String id, EdgeRole role) {
    final repo = _repo;
    return serialize<void>(() async {
      final previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      String? targetNodeId;
      for (final e in previous) {
        if (e.id == id) targetNodeId = e.targetNodeId;
      }
      final Set<String> demote = targetNodeId == null
          ? const <String>{}
          : _conflictingFrameRoles(
              previous,
              targetNodeId: targetNodeId,
              role: role,
              exceptId: id,
            );
      if (_alive) {
        state = AsyncData([
          for (final e in previous)
            if (e.id == id)
              e.copyWith(role: role)
            else if (demote.contains(e.id))
              e.copyWith(role: EdgeRole.reference)
            else
              e,
        ]);
      }
      try {
        if (demote.isEmpty) {
          // 无冲突（绝大多数情况）走原来的单条 update——不为一个不会发生的
          // 冲突给每次改角色都加一次事务开销，也让既有测试的装配面不变。
          await repo.update(id, <String, Object?>{
            'role': CanvasEdgeMapping.roleToDb(role),
          });
        } else {
          await _demoteThenSet(demote: demote, promote: id, role: role);
        }
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 同一目标节点上与 [role] 冲突、必须降级为参考图的其它 data 入边。
  ///
  /// 只有首帧 / 尾帧是单选，参考图不是——所以 [role] 是 reference 时恒返回空集。
  Set<String> _conflictingFrameRoles(
    List<CanvasEdge> edges, {
    required String targetNodeId,
    required EdgeRole role,
    String? exceptId,
  }) {
    if (role == EdgeRole.reference) return const <String>{};
    return <String>{
      for (final e in edges)
        if (e.id != exceptId &&
            e.targetNodeId == targetNodeId &&
            e.edgeType == EdgeType.data &&
            e.role == role)
          e.id,
    };
  }

  /// 一个事务里：把 [demote] 全部降级为参考图，再把 [promote] 设成 [role]。
  ///
  /// 顺序和原子性都要紧。拆成两次独立写的话，降级成功而设置失败 ⇒ 这个节点
  /// 一条首帧都不剩（比两条更糟，用户点了一下反而把原来那条弄丢了）。
  Future<void> _demoteThenSet({
    required Set<String> demote,
    required String promote,
    required EdgeRole role,
  }) async {
    final uow = await ref.read(unitOfWorkProvider.future);
    await uow.run<void>((RepositoryScope scope) async {
      for (final String id in demote) {
        await scope.edges.update(id, <String, Object?>{
          'role': CanvasEdgeMapping.roleToDb(EdgeRole.reference),
        });
      }
      await scope.edges.update(promote, <String, Object?>{
        'role': CanvasEdgeMapping.roleToDb(role),
      });
    });
  }

  // ===== 叙事链拼接 =====
  //
  // 同一套写法：入口解析 unitOfWorkProvider.future（拿到 Future 后在 op 里 await，
  // op 里不再触 ref）→ 整体进 serialize → op 内读 previous → 乐观写内存 → 一个
  // uow.run → on InkError 回滚到 previous 并上抛。事务内顺序固定：先软删（腾出
  // uq_edges_live 的槽位）→ 再改 sortOrder / role → 最后 create。

  /// 一个事务执行 [plan]：先软删 → 再改 sortOrder → 最后建。返回被删边快照、新边与撤销令牌。
  ///
  /// plan 由调用方用读到的边集算好，这里**不重算**：排队期间别处改了边导致 23505 ⇒
  /// 库整批回滚、内存回到调用前、InkError 上抛，调用方出失败卡。
  /// 空 plan / 画布已关 ⇒ 不碰库、返回空结果。不在内存里的 removeEdgeIds 仍软删，
  /// 但不进 removed 与令牌（没有两端可记）。
  Future<SpliceApplied> applySplice(SplicePlan plan) {
    if (plan.isEmpty || !_alive) {
      return Future<SpliceApplied>.value(_kEmptySplice);
    }
    final String canvasId = arg;
    final Future<UnitOfWork> uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<SpliceApplied>(() async {
      final UnitOfWork uow = await uowFuture;
      final List<CanvasEdge> previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      final List<CanvasEdge> removed = <CanvasEdge>[
        for (final CanvasEdge e in previous)
          if (plan.removeEdgeIds.contains(e.id)) e,
      ];
      final Map<EdgeEndpoints, int> previousSortOrders = <EdgeEndpoints, int>{
        for (final CanvasEdge e in previous)
          if (plan.sortOrders.containsKey(e.id) &&
              !plan.removeEdgeIds.contains(e.id))
            EdgeEndpoints.of(e): e.sortOrder,
      };
      final List<CanvasEdge> optimistic = <CanvasEdge>[
        for (final CanvasEdge e in previous)
          if (!plan.removeEdgeIds.contains(e.id))
            plan.sortOrders.containsKey(e.id)
                ? e.copyWith(sortOrder: plan.sortOrders[e.id])
                : e,
      ];
      if (_alive) state = AsyncData(optimistic);
      try {
        final List<CanvasEdge> created =
            await uow.run<List<CanvasEdge>>((RepositoryScope scope) async {
          for (final String id in plan.removeEdgeIds) {
            await scope.edges.softDelete(id);
          }
          for (final MapEntry<String, int> entry in plan.sortOrders.entries) {
            await scope.edges.update(
                entry.key, <String, Object?>{EdgeCol.sortOrder: entry.value});
          }
          return _createAll(scope.edges, canvasId, plan.addEdges);
        });
        if (_alive) state = AsyncData(<CanvasEdge>[...optimistic, ...created]);
        return (
          removed: removed,
          added: created,
          token: SpliceUndoToken(
            removed: <({EdgeEndpoints key, int sortOrder})>[
              for (final CanvasEdge e in removed)
                (key: EdgeEndpoints.of(e), sortOrder: e.sortOrder),
            ],
            added: <EdgeEndpoints>[
              for (final CanvasEdge e in created) EdgeEndpoints.of(e),
            ],
            previousSortOrders: previousSortOrders,
          ),
        );
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 把 [newNodeId] 插进叙事边 [edgeId]（A → 新 → B 一次接好）：在 serialize 外用当前
  /// 内存边集算 [insertPlan]，再交给 [applySplice]。
  ///
  /// 边不在内存 / 不可插（insertPlan 为 null）/ 画布已关 ⇒ 返回 null、不碰库。
  Future<SpliceApplied?> spliceInsert(String edgeId, String newNodeId) async {
    if (!_alive) return null;
    final List<CanvasEdge> current = state.valueOrNull ?? const <CanvasEdge>[];
    final CanvasEdge? edge = _edgeById(current, edgeId);
    if (edge == null) return null;
    final SplicePlan? plan =
        insertPlan(edge: edge, newNodeId: newNodeId, edges: current);
    if (plan == null) return null;
    return applySplice(plan);
  }

  /// 换连线类型（数据 ↔ 叙事）：一个事务软删旧边 + 建新边。
  ///
  /// - 边不在内存、[to] 与原类型相同、任一侧是 generationSource ⇒ null、不碰库；
  /// - data → narrative：role 置 reference，sortOrder 排在源已有分支之后；
  /// - narrative → data：role 取 [role]；首 / 尾帧时同目标同角色的 data 入边在同一事务降为参考
  ///   （[_conflictingFrameRoles]，与 updateRole 同一判据），返回 demotedIds。
  /// 合法性（成环、节点类型、模型支持）由调用方判，这里不判。
  Future<EdgeTypeChanged?> changeEdgeType(
    String edgeId, {
    required EdgeType to,
    EdgeRole role = EdgeRole.reference,
  }) {
    if (!_alive) return Future<EdgeTypeChanged?>.value(null);
    final String canvasId = arg;
    final Future<UnitOfWork> uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<EdgeTypeChanged?>(() async {
      final List<CanvasEdge> previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      final CanvasEdge? old = _edgeById(previous, edgeId);
      if (old == null ||
          old.edgeType == to ||
          old.edgeType == EdgeType.generationSource ||
          to == EdgeType.generationSource) {
        return null;
      }
      final UnitOfWork uow = await uowFuture;
      final bool toNarrative = to == EdgeType.narrative;
      final EdgeRole newRole = toNarrative ? EdgeRole.reference : role;
      final int sortOrder = toNarrative
          ? nextNarrativeSortOrder(anchorId: old.sourceNodeId, edges: previous)
          : 0;
      final Set<String> demote = toNarrative
          ? const <String>{}
          : _conflictingFrameRoles(
              previous,
              targetNodeId: old.targetNodeId,
              role: newRole,
              exceptId: old.id,
            );
      final List<CanvasEdge> optimistic = <CanvasEdge>[
        for (final CanvasEdge e in previous)
          if (e.id != old.id)
            demote.contains(e.id) ? e.copyWith(role: EdgeRole.reference) : e,
      ];
      if (_alive) state = AsyncData(optimistic);
      try {
        final CanvasEdge created =
            await uow.run<CanvasEdge>((RepositoryScope scope) async {
          await scope.edges.softDelete(old.id);
          for (final String id in demote) {
            await scope.edges.update(id, <String, Object?>{
              EdgeCol.role: CanvasEdgeMapping.roleToDb(EdgeRole.reference),
            });
          }
          final List<CanvasEdge> made = await _createAll(
            scope.edges,
            canvasId,
            <SpliceEdgeSpec>[
              (
                sourceNodeId: old.sourceNodeId,
                targetNodeId: old.targetNodeId,
                edgeType: to,
                role: newRole,
                sortOrder: sortOrder,
              ),
            ],
          );
          return made.single;
        });
        if (_alive) state = AsyncData(<CanvasEdge>[...optimistic, created]);
        return (removed: old, created: created, demotedIds: demote);
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  /// 一个事务软删 [ids] 全部（切线：划过的线松手全部断开、一张撤销卡）。
  /// 不在内存的 id 仍软删但不进返回值；空集合不碰库。失败整批回滚。
  Future<List<CanvasEdge>> removeEdges(Set<String> ids) async {
    if (ids.isEmpty) return const <CanvasEdge>[];
    final SpliceApplied applied =
        await applySplice(SplicePlan(removeEdgeIds: ids));
    return applied.removed;
  }

  /// 一个事务按序建 [specs]；任一失败（含 23505）整批回滚并上抛。返回新边（含新 id）。
  Future<List<CanvasEdge>> addEdgesInTx(List<SpliceEdgeSpec> specs) async {
    if (specs.isEmpty) return const <CanvasEdge>[];
    final SpliceApplied applied =
        await applySplice(SplicePlan(addEdges: specs));
    return applied.added;
  }

  /// 把 [targetNodeId] 的 [role]（只能是首帧 / 尾帧）换成来自 [newSourceNodeId]：同一事务里
  /// 软删目标上该角色的其他 data 入边；newSource → target 已有在世 data 边 ⇒ 只改它的 role，
  /// 否则建一条。返回被删的边与生效的那条。
  Future<RoleEdgeReplaced> replaceRoleEdge({
    required String targetNodeId,
    required EdgeRole role,
    required String newSourceNodeId,
  }) {
    if (role == EdgeRole.reference) {
      throw ArgumentError.value(
          role, 'role', 'replaceRoleEdge only takes firstFrame / lastFrame');
    }
    final String canvasId = arg;
    final Future<UnitOfWork> uowFuture = ref.read(unitOfWorkProvider.future);
    return serialize<RoleEdgeReplaced>(() async {
      final UnitOfWork uow = await uowFuture;
      final List<CanvasEdge> previous =
          _alive ? (state.valueOrNull ?? const <CanvasEdge>[]) : const <CanvasEdge>[];
      final List<CanvasEdge> others = <CanvasEdge>[
        for (final CanvasEdge e in previous)
          if (e.edgeType == EdgeType.data &&
              e.targetNodeId == targetNodeId &&
              e.role == role &&
              e.sourceNodeId != newSourceNodeId)
            e,
      ];
      final Set<String> otherIds = <String>{for (final CanvasEdge e in others) e.id};
      CanvasEdge? found;
      for (final CanvasEdge e in previous) {
        if (e.edgeType == EdgeType.data &&
            e.sourceNodeId == newSourceNodeId &&
            e.targetNodeId == targetNodeId) {
          found = e;
        }
      }
      final CanvasEdge? existing = found;
      final List<CanvasEdge> optimistic = <CanvasEdge>[
        for (final CanvasEdge e in previous)
          if (!otherIds.contains(e.id))
            e.id == existing?.id ? e.copyWith(role: role) : e,
      ];
      if (_alive) state = AsyncData(optimistic);
      try {
        final CanvasEdge effective =
            await uow.run<CanvasEdge>((RepositoryScope scope) async {
          for (final CanvasEdge e in others) {
            await scope.edges.softDelete(e.id);
          }
          if (existing != null) {
            await scope.edges.update(existing.id, <String, Object?>{
              EdgeCol.role: CanvasEdgeMapping.roleToDb(role),
            });
            return existing.copyWith(role: role);
          }
          final List<CanvasEdge> made = await _createAll(
            scope.edges,
            canvasId,
            <SpliceEdgeSpec>[
              (
                sourceNodeId: newSourceNodeId,
                targetNodeId: targetNodeId,
                edgeType: EdgeType.data,
                role: role,
                sortOrder: 0,
              ),
            ],
          );
          return made.single;
        });
        if (_alive && existing == null) {
          state = AsyncData(<CanvasEdge>[...optimistic, effective]);
        }
        return (removed: others, created: effective);
      } on InkError catch (_) {
        if (_alive) state = AsyncData(previous);
        rethrow;
      }
    });
  }

  static CanvasEdge? _edgeById(List<CanvasEdge> edges, String id) {
    for (final CanvasEdge e in edges) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 在事务里按序建 [specs]，返回带新 id 的边。
  static Future<List<CanvasEdge>> _createAll(
    EdgeRepository edges,
    String canvasId,
    List<SpliceEdgeSpec> specs,
  ) async {
    final List<CanvasEdge> out = <CanvasEdge>[];
    for (final SpliceEdgeSpec s in specs) {
      final String id = await edges.create(
        canvasId: canvasId,
        sourceNodeId: s.sourceNodeId,
        targetNodeId: s.targetNodeId,
        edgeType: CanvasEdgeMapping.typeToDb(s.edgeType),
        role: CanvasEdgeMapping.roleToDb(s.role),
        sortOrder: s.sortOrder,
      );
      out.add(CanvasEdge(
        id: id,
        canvasId: canvasId,
        sourceNodeId: s.sourceNodeId,
        targetNodeId: s.targetNodeId,
        edgeType: s.edgeType,
        role: s.role,
        sortOrder: s.sortOrder,
      ));
    }
    return out;
  }
}
