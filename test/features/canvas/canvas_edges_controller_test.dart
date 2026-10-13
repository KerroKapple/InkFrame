// CanvasEdgesController 单测——FakeEdgeRepository 覆盖 build / add / remove /
// DB 失败回滚。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';

import '../../_harness/fake_unit_of_work.dart';

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];
  final List<String> restored = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];
  bool createThrows = false;
  bool softDeleteThrows = false;
  bool restoreThrows = false;
  bool updateThrows = false;

  /// 置 n 后：第 n+1 次起的 update 抛错（前 n 次正常落下）。
  /// 用于「降级成功、设置失败」这种只有一半落地的夹缝。
  int? updateThrowsAfter;

  /// 置入后 create 会先 await 此 gate，用于制造两次 create 交错（LB-04）。
  Completer<void>? createGate;

  int _seq = 0;

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    if (createGate != null) await createGate!.future;
    if (createThrows) {
      throw const LocalIOError(extra: {'op': 'create', 'table': 'edges'});
    }
    final id = 'e${++_seq}';
    createCalls.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    });
    rows.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      rows.where((r) => r['canvas_id'] == canvasId).toList(growable: false);

  @override
  Future<int> softDelete(String id) async {
    if (softDeleteThrows) {
      throw const LocalIOError(extra: {'op': 'softDelete', 'table': 'edges'});
    }
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  // 未使用接口
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (updateThrows ||
        (updateThrowsAfter != null &&
            updateCalls.length >= updateThrowsAfter!)) {
      throw const LocalIOError(extra: {'op': 'update', 'table': 'edges'});
    }
    updateCalls.add({'id': id, ...patch});
    final idx = rows.indexWhere((r) => r['id'] == id);
    if (idx >= 0) rows[idx] = {...rows[idx], ...patch};
    return 1;
  }
  @override
  Future<int> restore(String id) async {
    if (restoreThrows) {
      throw const LocalIOError(extra: {'op': 'restore', 'table': 'edges'});
    }
    restored.add(id);
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async => 0;
}

class _GatedEdgeRepo implements EdgeRepository {
  final Completer<void> gate = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    await gate.future; // 阻塞，模拟 await 期间 provider 被 dispose
    return 'e1';
  }
  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async => [];
  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async => [];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;
  @override
  Future<int> softDelete(String id) async => 1;
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => 0;
}

void main() {
  late _FakeEdgeRepo repo;
  late ProviderContainer container;
  const canvasId = 'cvx';

  setUp(() {
    repo = _FakeEdgeRepo();
    container = ProviderContainer(overrides: [
      edgeRepositoryProvider.overrideWith((ref) async => repo),
    ]);
  });
  tearDown(() => container.dispose());

  group('CanvasEdgesController', () {
    test('build 空画布', () async {
      final edges = await container
          .read(canvasEdgesControllerProvider(canvasId).future);
      expect(edges, isEmpty);
    });

    test('addEdge 透传 Repository.create + 写入内存', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);

      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      expect(e.edgeType, EdgeType.data);
      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['edge_type'], 'data');
      expect(repo.createCalls.first['role'], 'reference');

      final state =
          container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addEdge 支持 first_frame role + generation_source 类型', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);

      await ctrl.addEdge(
        sourceNodeId: 'img',
        targetNodeId: 'vid',
        edgeType: EdgeType.data,
        role: EdgeRole.firstFrame,
      );
      await ctrl.addEdge(
        sourceNodeId: 'cfg',
        targetNodeId: 'res',
        edgeType: EdgeType.generationSource,
      );

      expect(repo.createCalls.last['edge_type'], 'generation_source');
      expect(repo.createCalls[0]['role'], 'first_frame');
    });

    test('addEdge 两次并发交错不丢更新（LB-04 串行化）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasEdgesControllerProvider(canvasId).notifier);

      final gate = Completer<void>();
      repo.createGate = gate;

      final fa = ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final fb = ctrl.addEdge(sourceNodeId: 'c', targetNodeId: 'd');
      gate.complete();
      await Future.wait([fa, fb]);

      final state = container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(2),
          reason: '两次并发 addEdge 都应保留，交错快照不得覆盖');
    });

    test('addEdge DB 失败 → 回滚 + rethrow', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      repo.createThrows = true;

      await expectLater(
        ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b'),
        throwsA(isA<LocalIOError>()),
      );
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('removeEdge 乐观删除 + DB softDelete', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      await ctrl.removeEdge(e.id);

      expect(repo.softDeleted, contains(e.id));
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('removeEdge 返回被删边（PL-4a undo 令牌）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      final removed = await ctrl.removeEdge(e.id);

      expect(removed, isNotNull);
      expect(removed!.id, e.id);
    });

    test('restore 复原连线到内存 + repo.restore（PL-4a）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final removed = await ctrl.removeEdge(e.id);
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);

      await ctrl.restore(removed!);

      expect(repo.restored, contains(e.id));
      final state = container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
      expect(state.valueOrNull!.first.id, e.id);
    });

    test('restore DB 失败 → 乐观复原回滚（PL-4a）', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final removed = await ctrl.removeEdge(e.id);
      repo.restoreThrows = true;

      await expectLater(
          ctrl.restore(removed!), throwsA(isA<LocalIOError>()));
      expect(container
              .read(canvasEdgesControllerProvider(canvasId))
              .valueOrNull,
          isEmpty);
    });

    test('restore 在 provider dispose 后 no-op，不抛 StateError（PL-4a 入口守卫）',
        () async {
      final c = ProviderContainer(overrides: [
        edgeRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      final removed = await ctrl.removeEdge(e.id);
      expect(removed, isNotNull);

      c.dispose(); // 画布关闭 → notifier autoDispose，_alive=false

      // 窗口内点 Undo：入口 _alive 守卫先于 _repo 的 ref.read → no-op，无 StateError。
      await expectLater(ctrl.restore(removed!), completes);
      expect(repo.restored, isEmpty, reason: 'dispose 后 restore 不落 DB');
    });

    test('updateRole 写 DB role 字段 + 内存更新', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');

      await ctrl.updateRole(e.id, EdgeRole.firstFrame);

      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['role'], 'first_frame');
      final state = container.read(canvasEdgesControllerProvider(canvasId));
      final updated =
          state.valueOrNull!.firstWhere((x) => x.id == e.id);
      expect(updated.role, EdgeRole.firstFrame);
    });

    test('updateRole DB 失败 → 回滚', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      repo.updateThrows = true;

      await expectLater(
        ctrl.updateRole(e.id, EdgeRole.lastFrame),
        throwsA(isA<LocalIOError>()),
      );
      final updated = container
          .read(canvasEdgesControllerProvider(canvasId))
          .valueOrNull!
          .firstWhere((x) => x.id == e.id);
      expect(updated.role, EdgeRole.reference);
    });

    test('removeEdge DB 失败 → 回滚', () async {
      await container.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasEdgesControllerProvider(canvasId).notifier);
      final e = await ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      repo.softDeleteThrows = true;

      await expectLater(ctrl.removeEdge(e.id), throwsA(isA<LocalIOError>()));
      final state =
          container.read(canvasEdgesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addEdge 在 await 期间被 dispose 不抛 StateError (ME-27 _alive 守卫)',
        () async {
      final gated = _GatedEdgeRepo();
      final c = ProviderContainer(overrides: [
        edgeRepositoryProvider.overrideWith((ref) async => gated),
      ]);
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasEdgesControllerProvider(canvasId).notifier);
      final future = ctrl.addEdge(sourceNodeId: 'a', targetNodeId: 'b');
      c.dispose(); // await 期间销毁 notifier
      gated.gate.complete(); // 放行 create
      await expectLater(future, completes); // 守卫存在 → 无 StateError
    });
  });

  // ===== 首帧 / 尾帧在同一目标节点上单选 =====
  //
  // 为什么这是个真缺陷而不是洁癖：`GenerationTask` 的 firstFramePath /
  // lastFramePath 各只装得下一个值，生成侧是 `firstFrame ??= absPath`。两条同角色
  // 入边 ⇒ 其中一条的图被静默丢掉，而界面上两条都显示「首帧」。
  // schema 拦不住它——uq_edges_live 只拦同 source 同 role，不同 source 的同 role
  // 入边在表层合法。
  group('首帧 / 尾帧单选', () {
    late ProviderContainer c;
    late int uowRuns;

    setUp(() {
      uowRuns = 0;
      c = ProviderContainer(overrides: <Override>[
        edgeRepositoryProvider.overrideWith((ref) async => repo),
        unitOfWorkProvider.overrideWith(
          (ref) async => _CountingUnitOfWork(
            FakeRepositoryScope(edges: repo),
            onRun: () => uowRuns++,
          ),
        ),
      ]);
      addTearDown(c.dispose);
    });

    Future<CanvasEdgesController> boot() async {
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      return c.read(canvasEdgesControllerProvider(canvasId).notifier);
    }

    List<CanvasEdge> edgesNow() =>
        c.read(canvasEdgesControllerProvider(canvasId)).valueOrNull!;

    EdgeRole roleOf(String id) => edgesNow().firstWhere((e) => e.id == id).role;

    test('把第二条入边改成首帧 ⇒ 原来那条降级为参考图（一个事务）', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);
      repo.updateCalls.clear();
      uowRuns = 0;

      await ctrl.updateRole(b.id, EdgeRole.firstFrame);

      expect(roleOf(b.id), EdgeRole.firstFrame);
      expect(roleOf(a.id), EdgeRole.reference,
          reason: '同一节点上两条首帧里必有一条的图被丢掉，所以旧那条必须降级');
      // 降级先、设置后：拆成两次独立写时若后一步失败，这个节点一条首帧都不剩。
      expect(
        repo.updateCalls.map((m) => '${m['id']}=${m['role']}').toList(),
        <String>['${a.id}=reference', '${b.id}=first_frame'],
      );
      expect(uowRuns, 1, reason: '两次写必须在同一个事务里，不能各走一次往返');
    });

    test('改成参考图不降级任何人（只有首 / 尾帧是单选）', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);
      await ctrl.updateRole(b.id, EdgeRole.lastFrame);
      uowRuns = 0;

      // b: lastFrame → reference。a 的首帧与 b 无冲突，不该被碰。
      await ctrl.updateRole(b.id, EdgeRole.reference);

      expect(roleOf(a.id), EdgeRole.firstFrame);
      expect(roleOf(b.id), EdgeRole.reference);
      expect(uowRuns, 0, reason: '无冲突时不该付事务的代价');
    });

    test('首帧与尾帧互不相干（同一节点上各可有一条）', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);

      await ctrl.updateRole(b.id, EdgeRole.lastFrame);

      expect(roleOf(a.id), EdgeRole.firstFrame, reason: '尾帧不该把首帧挤掉');
      expect(roleOf(b.id), EdgeRole.lastFrame);
    });

    test('不同目标节点的首帧互不影响', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v1');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v2');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);

      await ctrl.updateRole(b.id, EdgeRole.firstFrame);

      expect(roleOf(a.id), EdgeRole.firstFrame,
          reason: '单选是"每个目标节点一条"，不是"整张画布一条"');
      expect(roleOf(b.id), EdgeRole.firstFrame);
    });

    test('降级落下、设置失败 ⇒ 内存把两条一起回滚（且证明降级真发出去了）', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);
      repo.updateCalls.clear();
      // 让降级那一次写成功、设置那一次失败——这正是"两次独立写"会留下
      // 「一条首帧都不剩」的那个夹缝，也是必须共用一个事务的理由。
      repo.updateThrowsAfter = 1;

      await expectLater(
        ctrl.updateRole(b.id, EdgeRole.firstFrame),
        throwsA(isA<LocalIOError>()),
      );

      expect(
        repo.updateCalls.map((m) => '${m['id']}=${m['role']}').toList(),
        <String>['${a.id}=reference'],
        reason: '降级确实先发出去了（真事务里它会随设置失败一起回滚，'
            '这个 fake 没有事务，所以只到这里为止）',
      );
      expect(roleOf(a.id), EdgeRole.firstFrame, reason: '内存回滚要把降级也撤掉');
      expect(roleOf(b.id), EdgeRole.reference);
    });

    test('撤销删除：放回首帧那条 ⇒ 期间顶上来的那条降级', () async {
      final ctrl = await boot();
      final a = await ctrl.addEdge(sourceNodeId: 'i1', targetNodeId: 'v');
      final b = await ctrl.addEdge(sourceNodeId: 'i2', targetNodeId: 'v');
      await ctrl.updateRole(a.id, EdgeRole.firstFrame);
      final CanvasEdge? removed = await ctrl.removeEdge(a.id);
      // 用户在 Undo 窗口内把 b 改成了首帧。
      await ctrl.updateRole(b.id, EdgeRole.firstFrame);

      await ctrl.restore(removed!);

      expect(roleOf(a.id), EdgeRole.firstFrame,
          reason: 'Undo 要把删之前的状态放回来');
      expect(roleOf(b.id), EdgeRole.reference,
          reason: 'b 当上首帧只是因为 a 被删了；撤销删除就该把它让回去');
    });

    // 这条是 BOARD「link 智能默认 role 竞态残留」的红测。
    test('并发连两条 image→video：解析器在队列内求值 ⇒ 只产出一条首帧', () async {
      final ctrl = await boot();
      // LinkActionController 传进来的就是这个形状的解析器（纯函数，只吃列表）。
      EdgeRole resolver(List<CanvasEdge> current) => current.any((e) =>
              e.targetNodeId == 'v' &&
              e.edgeType == EdgeType.data &&
              e.role == EdgeRole.firstFrame)
          ? EdgeRole.reference
          : EdgeRole.firstFrame;

      // 第一条的 DB 往返还在途时就发第二条——修复前两次都读到"还没有首帧"。
      final gate = Completer<void>();
      repo.createGate = gate;
      final f1 = ctrl.addEdge(
          sourceNodeId: 'i1', targetNodeId: 'v', roleResolver: resolver);
      final f2 = ctrl.addEdge(
          sourceNodeId: 'i2', targetNodeId: 'v', roleResolver: resolver);
      gate.complete();
      final a = await f1;
      final b = await f2;

      expect(a.role, EdgeRole.firstFrame);
      expect(b.role, EdgeRole.reference,
          reason: '第二条必须看见第一条已经落下的首帧；'
              '在队列外算 role 时两次都判"还没有" ⇒ 双首帧');
      expect(
        repo.createCalls.map((m) => m['role']).toList(),
        <String>['first_frame', 'reference'],
        reason: '落库的 role 也要是解析器在队列内算出来的那个，不是调用时的快照',
      );
    });
  });
}

/// 数 `run` 次数的 FakeUnitOfWork：用来钉死「降级 + 设置在**一个**事务里」。
class _CountingUnitOfWork implements UnitOfWork {
  _CountingUnitOfWork(this.scope, {required this.onRun});
  final RepositoryScope scope;
  final void Function() onRun;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) {
    onRun();
    return action(scope);
  }
}
