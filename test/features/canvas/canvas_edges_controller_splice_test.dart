// CanvasEdgesController 叙事链拼接（applySplice / spliceInsert / changeEdgeType /
// removeEdges / addEdgesInTx / replaceRoleEdge）单测。
//
// fake 仓储照 canvas_edges_controller_test.dart 的 _FakeEdgeRepo 抄一份，另加：
//   - uq_edges_live 模拟：rows 里已有同 source / target / edge_type 的在世行时 create 抛
//     LocalIOError(extra: {'db_code': '23505'})（与 link_action_controller 读 extra['db_code'] 同形）；
//   - 第 n 次 create / softDelete 抛错的开关；
//   - ops：按发生顺序记下每一次写（钉死「先删 → 再改序 → 最后建」）。
// FakeUnitOfWork 不模拟库回滚：回滚用例只断言内存与抛错。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/edge_endpoints.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/util/narrative_splice.dart';

import '../../_harness/fake_unit_of_work.dart';

class _SpliceEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];
  final List<String> restored = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  /// 每一次写，按发生顺序：'softDelete:<id>' / 'update:<id>' / 'create:<src>-><tgt>'。
  final List<String> ops = <String>[];

  bool createThrows = false;
  bool softDeleteThrows = false;
  bool restoreThrows = false;
  bool updateThrows = false;

  /// 置 n 后：第 n 次 create（从 1 数）抛错。
  int? createFailOn;

  /// 置 n 后：第 n 次 softDelete（从 1 数）抛错。
  int? softDeleteFailOn;

  /// 置 n 后：第 n+1 次起的 update 抛错（前 n 次正常落下）。
  int? updateThrowsAfter;

  /// 置入后 create 会先 await 此 gate。
  Completer<void>? createGate;

  int _seq = 0;
  int _creates = 0;
  int _softDeletes = 0;

  /// 直接塞一行在世边（build 时读进内存）。
  void seed(
    String id,
    String source,
    String target, {
    String edgeType = 'narrative',
    String role = 'reference',
    int sortOrder = 0,
  }) {
    rows.add(<String, Object?>{
      'id': id,
      'canvas_id': _canvasId,
      'source_node_id': source,
      'target_node_id': target,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    });
  }

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
    _creates++;
    if (createThrows || createFailOn == _creates) {
      throw const LocalIOError(extra: {'op': 'create', 'table': 'edges'});
    }
    final bool clash = rows.any((Map<String, Object?> r) =>
        r['source_node_id'] == sourceNodeId &&
        r['target_node_id'] == targetNodeId &&
        r['edge_type'] == edgeType);
    if (clash) {
      throw const LocalIOError(extra: {'db_code': '23505'});
    }
    final id = 'e${++_seq}';
    ops.add('create:$sourceNodeId->$targetNodeId');
    final Map<String, Object?> row = <String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
      'edge_type': edgeType,
      'role': role,
      'sort_order': sortOrder,
    };
    createCalls.add(row);
    rows.add(Map<String, Object?>.of(row));
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      rows.where((r) => r['canvas_id'] == canvasId).toList(growable: false);

  @override
  Future<int> softDelete(String id) async {
    _softDeletes++;
    if (softDeleteThrows || softDeleteFailOn == _softDeletes) {
      throw const LocalIOError(extra: {'op': 'softDelete', 'table': 'edges'});
    }
    ops.add('softDelete:$id');
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
    ops.add('update:$id');
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

const String _canvasId = 'cvx';

SpliceEdgeSpec _narr(String s, String t, int sortOrder) => (
      sourceNodeId: s,
      targetNodeId: t,
      edgeType: EdgeType.narrative,
      role: EdgeRole.reference,
      sortOrder: sortOrder,
    );

EdgeEndpoints _key(String s, String t,
        {EdgeType type = EdgeType.narrative,
        EdgeRole role = EdgeRole.reference}) =>
    EdgeEndpoints(
        sourceNodeId: s, targetNodeId: t, edgeType: type, role: role);

/// 一套独立的仓储 + 容器 + 事务计数。
class _Env {
  _Env() {
    container = ProviderContainer(overrides: <Override>[
      edgeRepositoryProvider.overrideWith((ref) async => repo),
      unitOfWorkProvider.overrideWith(
        (ref) async => _CountingUnitOfWork(
          FakeRepositoryScope(edges: repo),
          onRun: () => uowRuns++,
        ),
      ),
    ]);
  }

  final _SpliceEdgeRepo repo = _SpliceEdgeRepo();
  late final ProviderContainer container;
  int uowRuns = 0;

  Future<CanvasEdgesController> boot() async {
    await container.read(canvasEdgesControllerProvider(_canvasId).future);
    return container.read(canvasEdgesControllerProvider(_canvasId).notifier);
  }

  List<CanvasEdge> edgesNow() =>
      container.read(canvasEdgesControllerProvider(_canvasId)).valueOrNull!;

  CanvasEdge edge(String id) => edgesNow().firstWhere((e) => e.id == id);
}

void main() {
  late _Env env;

  setUp(() {
    env = _Env();
    addTearDown(env.container.dispose);
  });

  group('applySplice', () {
    test('applySplice 一个事务：先删后改序再建；内存同步，返回令牌', () async {
      env.repo
        ..seed('ab', 'A', 'B', sortOrder: 5)
        ..seed('pa', 'P', 'a')
        ..seed('pb', 'P', 'b', sortOrder: 1);
      final ctrl = await env.boot();
      final CanvasEdge ab = env.edge('ab');

      final SpliceApplied applied = await ctrl.applySplice(SplicePlan(
        removeEdgeIds: const <String>{'ab'},
        addEdges: <SpliceEdgeSpec>[_narr('A', 'X', 5), _narr('X', 'B', 0)],
        sortOrders: const <String, int>{'pb': 0, 'pa': 1},
      ));

      expect(env.repo.ops, <String>[
        'softDelete:ab',
        'update:pb',
        'update:pa',
        'create:A->X',
        'create:X->B',
      ], reason: '先软删腾出 uq_edges_live 槽位，再改序，最后建');
      expect(env.uowRuns, 1, reason: '整批一个事务');
      expect(env.repo.updateCalls.map((m) => '${m['id']}=${m['sort_order']}'),
          <String>['pb=0', 'pa=1']);

      // 内存：ab 没了，pa / pb 换序，两条新边带新 id。
      final List<CanvasEdge> now = env.edgesNow();
      expect(now.map((e) => e.id).toSet(), <String>{'pa', 'pb', 'e1', 'e2'});
      expect(env.edge('pa').sortOrder, 1);
      expect(env.edge('pb').sortOrder, 0);
      expect(env.edge('e1').sourceNodeId, 'A');
      expect(env.edge('e1').targetNodeId, 'X');
      expect(env.edge('e1').sortOrder, 5);
      expect(env.edge('e1').edgeType, EdgeType.narrative);

      // 返回值与令牌。
      expect(applied.removed, <CanvasEdge>[ab]);
      expect(applied.added.map((e) => e.id), <String>['e1', 'e2']);
      expect(applied.token.removed, hasLength(1));
      expect(applied.token.removed.single.key.matches(ab), isTrue);
      expect(applied.token.removed.single.sortOrder, 5);
      expect(applied.token.added, <EdgeEndpoints>[
        _key('A', 'X'),
        _key('X', 'B'),
      ]);
      expect(applied.token.previousSortOrders, <EdgeEndpoints, int>{
        _key('P', 'a'): 0,
        _key('P', 'b'): 1,
      });
    });

    test('applySplice 删 A→B 再建 A→B（同两端）不撞唯一索引', () async {
      env.repo.seed('ab', 'A', 'B', sortOrder: 1);
      final ctrl = await env.boot();

      final SpliceApplied applied = await ctrl.applySplice(SplicePlan(
        removeEdgeIds: const <String>{'ab'},
        addEdges: <SpliceEdgeSpec>[_narr('A', 'B', 2)],
      ));

      expect(env.repo.ops, <String>['softDelete:ab', 'create:A->B']);
      expect(applied.added.single.sortOrder, 2);
      expect(env.edgesNow().map((e) => e.id), <String>['e1']);
    });

    test('applySplice 第 2 个 create 失败 ⇒ 内存整批回到调用前、抛 InkError', () async {
      env.repo
        ..seed('ab', 'A', 'B', sortOrder: 5)
        ..seed('pa', 'P', 'a');
      final ctrl = await env.boot();
      final List<CanvasEdge> before = env.edgesNow();
      env.repo.createFailOn = 2;

      await expectLater(
        ctrl.applySplice(SplicePlan(
          removeEdgeIds: const <String>{'ab'},
          addEdges: <SpliceEdgeSpec>[_narr('A', 'X', 5), _narr('X', 'B', 0)],
          sortOrders: const <String, int>{'pa': 3},
        )),
        throwsA(isA<InkError>()),
      );

      expect(env.edgesNow(), before,
          reason: '乐观删掉的 ab、改了序的 pa 都要回到调用前');
      expect(env.repo.ops, <String>['softDelete:ab', 'update:pa', 'create:A->X'],
          reason: '确实走到了第 2 个 create 才失败');
    });

    test('applySplice 空 plan ⇒ 不碰库、返回空', () async {
      env.repo.seed('ab', 'A', 'B');
      final ctrl = await env.boot();

      final SpliceApplied applied = await ctrl.applySplice(const SplicePlan());

      expect(applied.removed, isEmpty);
      expect(applied.added, isEmpty);
      expect(applied.token.isEmpty, isTrue);
      expect(env.repo.ops, isEmpty);
      expect(env.uowRuns, 0);
    });

    test('applySplice 在事务中途画布被关 ⇒ 不抛 StateError', () async {
      final _SpliceEdgeRepo repo = _SpliceEdgeRepo()..seed('ab', 'A', 'B');
      final Completer<void> gate = Completer<void>();
      final ProviderContainer c = ProviderContainer(overrides: <Override>[
        edgeRepositoryProvider.overrideWith((ref) async => repo),
        unitOfWorkProvider.overrideWith((ref) async =>
            GatedFakeUnitOfWork(FakeRepositoryScope(edges: repo), gate.future)),
      ]);
      await c.read(unitOfWorkProvider.future);
      await c.read(canvasEdgesControllerProvider(_canvasId).future);
      final ctrl = c.read(canvasEdgesControllerProvider(_canvasId).notifier);

      final Future<SpliceApplied> future = ctrl.applySplice(SplicePlan(
        removeEdgeIds: const <String>{'ab'},
        addEdges: <SpliceEdgeSpec>[_narr('A', 'X', 0)],
      ));
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      gate.complete();

      await expectLater(future, completes);
    });
  });

  group('spliceInsert', () {
    test('spliceInsert：叙事边 A→B 插 X ⇒ 与 applySplice(insertPlan(...)) 结果相同',
        () async {
      env.repo.seed('ab', 'A', 'B', sortOrder: 5);
      final ctrl = await env.boot();

      final SpliceApplied? viaInsert = await ctrl.spliceInsert('ab', 'X');

      final _Env other = _Env();
      addTearDown(other.container.dispose);
      other.repo.seed('ab', 'A', 'B', sortOrder: 5);
      final otherCtrl = await other.boot();
      final SplicePlan plan = insertPlan(
        edge: other.edge('ab'),
        newNodeId: 'X',
        edges: other.edgesNow(),
      )!;
      final SpliceApplied viaPlan = await otherCtrl.applySplice(plan);

      expect(viaInsert, isNotNull);
      expect(viaInsert!.removed, viaPlan.removed);
      expect(viaInsert.added, viaPlan.added);
      expect(viaInsert.token.removed, viaPlan.token.removed);
      expect(viaInsert.token.added, viaPlan.token.added);
      expect(env.edgesNow(), other.edgesNow());
      expect(env.repo.ops, other.repo.ops);
      expect(env.repo.ops,
          <String>['softDelete:ab', 'create:A->X', 'create:X->B']);
      expect(env.edge('e1').sortOrder, 5, reason: 'A→X 沿用 A→B 的 sortOrder');
    });

    test('spliceInsert：data 边 / X 已在链上 ⇒ null、不碰库', () async {
      env.repo
        ..seed('d', 'A', 'B', edgeType: 'data')
        ..seed('cd', 'C', 'D')
        ..seed('xy', 'X', 'Y');
      final ctrl = await env.boot();

      expect(await ctrl.spliceInsert('d', 'Z'), isNull, reason: 'data 边不可插');
      expect(await ctrl.spliceInsert('cd', 'X'), isNull, reason: 'X 已在链上');
      expect(await ctrl.spliceInsert('missing', 'Z'), isNull,
          reason: '边不在内存');

      expect(env.repo.ops, isEmpty);
      expect(env.uowRuns, 0);
      expect(env.edgesNow(), hasLength(3));
    });
  });

  group('changeEdgeType', () {
    test('changeEdgeType narrative → data(首帧) ⇒ 同目标原首帧降为参考，同一事务', () async {
      env.repo
        ..seed('d1', 'I', 'V', edgeType: 'data', role: 'first_frame')
        ..seed('n1', 'S', 'V', sortOrder: 3);
      final ctrl = await env.boot();
      final CanvasEdge n1 = env.edge('n1');

      final EdgeTypeChanged? r = await ctrl.changeEdgeType('n1',
          to: EdgeType.data, role: EdgeRole.firstFrame);

      expect(r, isNotNull);
      expect(r!.removed, n1);
      expect(r.demotedIds, <String>{'d1'});
      expect(r.created.edgeType, EdgeType.data);
      expect(r.created.role, EdgeRole.firstFrame);
      expect(r.created.sourceNodeId, 'S');
      expect(r.created.targetNodeId, 'V');

      expect(env.uowRuns, 1, reason: '软删 + 降级 + 新建同一个事务');
      expect(env.repo.ops, <String>['softDelete:n1', 'update:d1', 'create:S->V']);
      expect(env.repo.updateCalls.single['role'], 'reference');
      expect(env.edge('d1').role, EdgeRole.reference,
          reason: '同一节点上两条首帧必有一条的图被丢掉');
      expect(env.edgesNow().map((e) => e.id).toSet(), <String>{'d1', 'e1'});
    });

    test('changeEdgeType data → narrative ⇒ sortOrder 排在源已有分支之后', () async {
      env.repo
        ..seed('n1', 'A', 'B', sortOrder: 3)
        ..seed('d1', 'A', 'C', edgeType: 'data', role: 'first_frame');
      final ctrl = await env.boot();

      final EdgeTypeChanged? r =
          await ctrl.changeEdgeType('d1', to: EdgeType.narrative);

      expect(r!.created.edgeType, EdgeType.narrative);
      expect(r.created.role, EdgeRole.reference, reason: '叙事边 role 一律 reference');
      expect(r.created.sortOrder, 4);
      expect(r.demotedIds, isEmpty);
      expect(env.repo.createCalls.single['edge_type'], 'narrative');
      expect(env.repo.createCalls.single['role'], 'reference');
      expect(env.repo.createCalls.single['sort_order'], 4);
      expect(env.uowRuns, 1);
    });

    test('changeEdgeType 同类型 / 不在内存 ⇒ null、不碰库', () async {
      env.repo
        ..seed('n1', 'A', 'B')
        ..seed('g1', 'C', 'R', edgeType: 'generation_source');
      final ctrl = await env.boot();

      expect(await ctrl.changeEdgeType('n1', to: EdgeType.narrative), isNull);
      expect(await ctrl.changeEdgeType('missing', to: EdgeType.data), isNull);
      expect(await ctrl.changeEdgeType('g1', to: EdgeType.data), isNull,
          reason: 'generationSource 不参与');
      expect(await ctrl.changeEdgeType('n1', to: EdgeType.generationSource),
          isNull);

      expect(env.repo.ops, isEmpty);
      expect(env.uowRuns, 0);
    });

    test('changeEdgeType 失败 ⇒ 内存回滚（含降级）', () async {
      env.repo
        ..seed('d1', 'I', 'V', edgeType: 'data', role: 'first_frame')
        ..seed('n1', 'S', 'V');
      final ctrl = await env.boot();
      final List<CanvasEdge> before = env.edgesNow();
      env.repo.createThrows = true;

      await expectLater(
        ctrl.changeEdgeType('n1', to: EdgeType.data, role: EdgeRole.firstFrame),
        throwsA(isA<LocalIOError>()),
      );
      expect(env.edgesNow(), before);
    });
  });

  group('removeEdges', () {
    test('removeEdges 一次删多条；失败整批回滚', () async {
      env.repo
        ..seed('a', 'A', 'B')
        ..seed('b', 'B', 'C')
        ..seed('c', 'C', 'D');
      final ctrl = await env.boot();
      final CanvasEdge a = env.edge('a');
      final CanvasEdge b = env.edge('b');

      final List<CanvasEdge> removed =
          await ctrl.removeEdges(<String>{'a', 'b', 'ghost'});

      expect(removed.toSet(), <CanvasEdge>{a, b},
          reason: '不在内存的 ghost 不进返回值');
      expect(env.repo.softDeleted, <String>['a', 'b', 'ghost'],
          reason: '不在内存的 id 仍软删');
      expect(env.uowRuns, 1);
      expect(env.edgesNow().map((e) => e.id), <String>['c']);

      // 失败：第 2 条软删抛错 ⇒ 内存整批回到调用前。
      final _Env failing = _Env();
      addTearDown(failing.container.dispose);
      failing.repo
        ..seed('a', 'A', 'B')
        ..seed('b', 'B', 'C')
        ..seed('c', 'C', 'D');
      final failingCtrl = await failing.boot();
      final List<CanvasEdge> before = failing.edgesNow();
      failing.repo.softDeleteFailOn = 2;

      await expectLater(failingCtrl.removeEdges(<String>{'a', 'b'}),
          throwsA(isA<LocalIOError>()));
      expect(failing.edgesNow(), before);
    });

    test('removeEdges 空集合不碰库', () async {
      final ctrl = await env.boot();
      expect(await ctrl.removeEdges(const <String>{}), isEmpty);
      expect(env.uowRuns, 0);
    });
  });

  group('addEdgesInTx', () {
    test('addEdgesInTx 一个事务按序建', () async {
      final ctrl = await env.boot();

      final List<CanvasEdge> created = await ctrl.addEdgesInTx(
          <SpliceEdgeSpec>[_narr('A', 'B', 0), _narr('B', 'C', 1)]);

      expect(created.map((e) => e.id), <String>['e1', 'e2']);
      expect(env.repo.ops, <String>['create:A->B', 'create:B->C']);
      expect(env.uowRuns, 1);
      expect(env.edgesNow(), created);
    });

    test('addEdgesInTx 失败整批回滚', () async {
      env.repo.seed('ab', 'A', 'B');
      final ctrl = await env.boot();
      final List<CanvasEdge> before = env.edgesNow();

      await expectLater(
        ctrl.addEdgesInTx(<SpliceEdgeSpec>[
          _narr('C', 'D', 0),
          _narr('A', 'B', 0), // 撞 uq_edges_live
        ]),
        throwsA(isA<LocalIOError>().having(
            (LocalIOError e) => e.extra['db_code'], 'db_code', '23505')),
      );
      expect(env.edgesNow(), before, reason: '已建的 C→D 不留在内存里');
      expect(env.uowRuns, 1);
    });
  });

  group('replaceRoleEdge', () {
    test('replaceRoleEdge 旧首帧软删、新首帧建立', () async {
      env.repo
        ..seed('f1', 'I1', 'V', edgeType: 'data', role: 'first_frame')
        ..seed('r1', 'I2', 'V', edgeType: 'data')
        ..seed('l1', 'I3', 'V', edgeType: 'data', role: 'last_frame')
        ..seed('f2', 'I1', 'W', edgeType: 'data', role: 'first_frame');
      final ctrl = await env.boot();
      final CanvasEdge f1 = env.edge('f1');

      final RoleEdgeReplaced r = await ctrl.replaceRoleEdge(
          targetNodeId: 'V', role: EdgeRole.firstFrame, newSourceNodeId: 'I4');

      expect(r.removed, <CanvasEdge>[f1]);
      expect(r.created.sourceNodeId, 'I4');
      expect(r.created.targetNodeId, 'V');
      expect(r.created.edgeType, EdgeType.data);
      expect(r.created.role, EdgeRole.firstFrame);
      expect(env.repo.ops, <String>['softDelete:f1', 'create:I4->V']);
      expect(env.uowRuns, 1);
      expect(env.edgesNow().map((e) => e.id).toSet(),
          <String>{'r1', 'l1', 'f2', 'e1'},
          reason: '参考 / 尾帧 / 别的目标的首帧都不动');
    });

    test('replaceRoleEdge 新源已有 data 边 ⇒ 只改 role', () async {
      env.repo
        ..seed('f1', 'I1', 'V', edgeType: 'data', role: 'first_frame')
        ..seed('r1', 'I2', 'V', edgeType: 'data');
      final ctrl = await env.boot();

      final RoleEdgeReplaced r = await ctrl.replaceRoleEdge(
          targetNodeId: 'V', role: EdgeRole.firstFrame, newSourceNodeId: 'I2');

      expect(r.created.id, 'r1');
      expect(r.created.role, EdgeRole.firstFrame);
      expect(env.repo.createCalls, isEmpty);
      expect(env.repo.ops, <String>['softDelete:f1', 'update:r1']);
      expect(env.repo.updateCalls.single['role'], 'first_frame');
      expect(env.edgesNow().map((e) => e.id), <String>['r1']);
      expect(env.edge('r1').role, EdgeRole.firstFrame);
    });

    test('replaceRoleEdge 只收首帧 / 尾帧', () async {
      final ctrl = await env.boot();
      expect(
        () => ctrl.replaceRoleEdge(
            targetNodeId: 'V', role: EdgeRole.reference, newSourceNodeId: 'I'),
        throwsArgumentError,
      );
    });
  });
}

/// 数 `run` 次数的 FakeUnitOfWork（照 canvas_edges_controller_test.dart 末尾抄）。
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
