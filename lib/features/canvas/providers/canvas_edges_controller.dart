// CanvasEdgesController — canvasId-family，DB-backed 连线集合。
//
// 与 CanvasNodesController 设计对齐：load / add / remove / updateRole 经
// EdgeRepository，失败回滚内存。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/edge_repository.dart';
import '../../../core/interfaces/unit_of_work.dart';
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
}
