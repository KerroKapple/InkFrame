import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';

import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_unit_of_work.dart';

class _FakeLaneRepo implements StyleLaneRepository {
  final Map<String, Map<String, Object?>> store = {};
  int _seq = 0;
  @override
  Future<String> create({required String canvasId, String label = '', String stylePrompt = '', int sortOrder = 0, String? tintColor, double size = 400.0}) async {
    final id = 'lane-${_seq++}';
    store[id] = {'id': id, 'canvas_id': canvasId, 'label': label, 'style_prompt': stylePrompt, 'sort_order': sortOrder, 'tint_color': tintColor, 'size': size};
    return id;
  }
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      store.values.where((r) => r['canvas_id'] == canvasId).toList();
  @override
  Future<int> update(String id, Map<String, Object?> patch) async { store[id]?.addAll(patch); return 1; }
  @override
  Future<int> softDelete(String id) async => store.remove(id) == null ? 0 : 1;
  @override
  Future<Map<String, Object?>?> findById(String id) async => store[id];
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => store.remove(id) == null ? 0 : 1;
}

/// update 调用时抛出 InkError，用于回滚测试。
class _ThrowingOnUpdateRepo extends _FakeLaneRepo {
  @override
  Future<int> update(String id, Map<String, Object?> patch) =>
      Future.error(const LocalIOError(extra: {'op': 'update'}));
}

/// create 先阻塞在 gate，用于制造两次 createLane 交错（LB-04）。
class _GatedCreateLaneRepo extends _FakeLaneRepo {
  final Completer<void> gate = Completer<void>();
  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async {
    await gate.future;
    return super.create(
      canvasId: canvasId,
      label: label,
      stylePrompt: stylePrompt,
      sortOrder: sortOrder,
      tintColor: tintColor,
      size: size,
    );
  }
}

// ===== 解散 / 删除泳道和内容的装配 =====
//
// InMemory 三件套（软删 / 复原 / 出入边都是真语义）同一组实例：scope 里给原实例，顶层三个 provider 给一层
// 「只转发读、写就抛 StateError」的包装——写只要漏到事务外，用例当场红。

/// 顶层节点仓储：只转发读（节点控制器 build 用 listByCanvas）；顺带数 listByCanvas 被调几次 = 节点控制器
/// 从库里载了几次（事务里读的是 scope 里的原实例，不经这里）。
class _ReadOnlyNodes implements NodeRepository {
  _ReadOnlyNodes(this._inner);
  final NodeRepository _inner;
  int loads = 0;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    loads++;
    return _inner.listByCanvas(canvasId);
  }

  @override
  Future<Map<String, Object?>?> findById(String id) => _inner.findById(id);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('top-level node repo write: ${invocation.memberName}');
}

class _ReadOnlyEdges implements EdgeRepository {
  _ReadOnlyEdges(this._inner);
  final EdgeRepository _inner;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) => _inner.listByCanvas(canvasId);

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) =>
      _inner.listOutgoing(sourceNodeId);

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) =>
      _inner.listIncoming(targetNodeId);

  @override
  Future<Map<String, Object?>?> findById(String id) => _inner.findById(id);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('top-level edge repo write: ${invocation.memberName}');
}

class _ReadOnlyLanes implements StyleLaneRepository {
  _ReadOnlyLanes(this._inner);
  final StyleLaneRepository _inner;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) => _inner.listByCanvas(canvasId);

  @override
  Future<Map<String, Object?>?> findById(String id) => _inner.findById(id);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('top-level lane repo write: ${invocation.memberName}');
}

/// softDelete 抛 InkError：事务失败（真 PG 整体回滚；这里只钉内存态与失效与否）。
class _ThrowingSoftDeleteLanes extends InMemoryStyleLaneRepository {
  @override
  Future<int> softDelete(String id) =>
      Future<int>.error(const LocalIOError(extra: <String, Object?>{'op': 'softDelete'}));
}

/// 数 `run` 次数的 UnitOfWork：包一层 FakeUnitOfWork，每次 run 先计数再原样转交。
/// 照 canvas_nodes_controller_test.dart 的 _CountingUnitOfWork。
class _CountingUnitOfWork implements UnitOfWork {
  _CountingUnitOfWork(this.inner, {required this.onRun});
  final UnitOfWork inner;
  final void Function() onRun;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) {
    onRun();
    return inner.run(action);
  }
}

const String _cv = 'cv';

/// 一张画布的库 + 容器。节点控制器用 listen 挂住（autoDispose；不挂住它，泳道控制器就走不到「重载节点」分支）。
/// [tearDown] 为 false 时由用例自己 dispose 容器（「画布已关」那条）。
class _World {
  _World({InMemoryStyleLaneRepository? lanes, bool tearDown = true})
      : lanes = lanes ?? InMemoryStyleLaneRepository() {
    topNodes = _ReadOnlyNodes(nodes);
    c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => _ReadOnlyLanes(this.lanes)),
      nodeRepositoryProvider.overrideWith((ref) async => topNodes),
      edgeRepositoryProvider.overrideWith((ref) async => _ReadOnlyEdges(edges)),
      unitOfWorkProvider.overrideWith(
        (ref) async => _CountingUnitOfWork(
          FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges, styleLanes: this.lanes)),
          onRun: () => uowRuns++,
        ),
      ),
    ]);
    if (tearDown) addTearDown(c.dispose);
  }

  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
  final InMemoryStyleLaneRepository lanes;
  late final _ReadOnlyNodes topNodes;
  late final ProviderContainer c;
  int uowRuns = 0;

  CanvasLanesController get controller => c.read(canvasLanesControllerProvider(_cv).notifier);
  List<StyleLane> get laneState => c.read(canvasLanesControllerProvider(_cv)).valueOrNull!;
  List<CanvasNode> get nodeState => c.read(canvasNodesControllerProvider(_cv)).valueOrNull!;

  Future<String> lane(String label, int sortOrder) =>
      lanes.create(canvasId: _cv, label: label, sortOrder: sortOrder);

  Future<String> node(String? laneId, Offset at, {String role = 'config', String? sourceNodeId}) =>
      nodes.create(
        canvasId: _cv,
        type: 'image',
        nodeRole: role,
        laneId: laneId,
        sourceNodeId: sourceNodeId,
        positionX: at.dx,
        positionY: at.dy,
      );

  Future<String> edge(String from, String to) =>
      edges.create(canvasId: _cv, sourceNodeId: from, targetNodeId: to, edgeType: 'data');

  /// 种完数据后再调：挂住节点控制器、载好两个控制器，uow 计数清零。
  Future<void> load() async {
    c.listen(canvasNodesControllerProvider(_cv), (_, _) {});
    c.listen(canvasLanesControllerProvider(_cv), (_, _) {});
    await c.read(canvasNodesControllerProvider(_cv).future);
    await c.read(canvasLanesControllerProvider(_cv).future);
    uowRuns = 0;
  }

  Map<String, Object?> nodeRow(String id) => nodes.rows[id]!;
  Map<String, Object?> laneRow(String id) => lanes.rows[id]!;
  Map<String, Object?> edgeRow(String id) => edges.rows[id]!;
}

void main() {
  test('createLane appends and updates state', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final lane = await c.read(canvasLanesControllerProvider('cv').notifier).createLane(label: 'A');
    expect(lane.label, 'A');
    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes.map((l) => l.id), contains(lane.id));
  });

  test('createLane 两次并发交错不丢更新（LB-04 串行化）', () async {
    final repo = _GatedCreateLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);

    final fa = notifier.createLane(label: 'A');
    final fb = notifier.createLane(label: 'B');
    repo.gate.complete();
    await Future.wait([fa, fb]);

    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes, hasLength(2),
        reason: '两次并发 createLane 都应保留，交错快照不得覆盖');
    expect(lanes.map((l) => l.sortOrder).toSet(), <int>{0, 1},
        reason: '串行化后 sort_order 应各自递增，不撞号');
  });

  test('reorderLanes [c,a,b] → 状态顺序 c,a,b 且 sort_order=0,1,2，repo 收到更新', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
      unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(FakeRepositoryScope(styleLanes: repo))),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    final b = await notifier.createLane(label: 'b');
    final lane = await notifier.createLane(label: 'c');
    // 重排为 c,a,b
    await notifier.reorderLanes([lane.id, a.id, b.id]);
    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes.map((l) => l.label), ['c', 'a', 'b']);
    expect(lanes.map((l) => l.sortOrder), [0, 1, 2]);
    // repo 中 sort_order 已更新
    expect(repo.store[lane.id]!['sort_order'], 0);
    expect(repo.store[a.id]!['sort_order'], 1);
    expect(repo.store[b.id]!['sort_order'], 2);
  });

  test('reorderLanes → repo.update 抛出 InkError 时回滚状态', () async {
    final repo = _ThrowingOnUpdateRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
      unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(FakeRepositoryScope(styleLanes: repo))),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    final b = await notifier.createLane(label: 'b');
    final lane = await notifier.createLane(label: 'c');
    final before = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    await expectLater(
      notifier.reorderLanes([lane.id, a.id, b.id]),
      throwsA(isA<InkError>()),
    );
    // 状态回滚到重排前
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.map((l) => l.id), before.map((l) => l.id));
    expect(after.map((l) => l.sortOrder), before.map((l) => l.sortOrder));
  });

  test('reorderLanes 收到不完整 id 列表（少于现有数量）→ 状态不变、不重排', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final a = await notifier.createLane(label: 'a');
    await notifier.createLane(label: 'b');
    await notifier.createLane(label: 'c');
    final before = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    // 只给 1 个 id（< 现有 3 条）→ 控制器早退保持原状（length 不匹配 guard）。
    await notifier.reorderLanes([a.id]);
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.map((l) => l.id), before.map((l) => l.id));
    expect(after.map((l) => l.sortOrder), before.map((l) => l.sortOrder));
  });

  test('updateLane → repo.update 抛 InkError 时回滚 size', () async {
    final repo = _ThrowingOnUpdateRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final lane = await notifier.createLane(label: 'a');
    final origSize = c
        .read(canvasLanesControllerProvider('cv'))
        .valueOrNull!
        .firstWhere((l) => l.id == lane.id)
        .size;
    await expectLater(
      notifier.updateLane(lane.id, size: origSize + 500),
      throwsA(isA<InkError>()),
    );
    // 乐观写 size 已回滚。
    final after = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(after.firstWhere((l) => l.id == lane.id).size, origSize);
  });

  // ===== 解散泳道（节点留下）=====
  //
  // 变异对照：不写 lane_id: null ⇒「道内节点 lane_id 清空」红；只按内存列表找道内节点 ⇒「库里有、内存没有」红；
  // 写漏到事务外 / 拆成多次 run ⇒「一次 uow.run」红；restoreDissolved 只恢复道 ⇒「节点回旧坐标与旧 lane_id」红；
  // 不跳过已删节点 ⇒「已删节点被跳过」红；撞号不重排 ⇒「sort_order 撞号」红。
  group('dissolveLane / restoreDissolved', () {
    test('dissolveLane：道软删、道内节点 lane_id 清空并写入新坐标，道外节点不动', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final cyber = await w.lane('Cyber', 1);
      final n1 = await w.node(ink, const Offset(100, 120));
      final n2 = await w.node(ink, const Offset(400, 200), role: 'result', sourceNodeId: n1);
      final other = await w.node(cyber, const Offset(50, 500));
      final free = await w.node(null, const Offset(900, 900));
      await w.load();

      final token = await w.controller.dissolveLane(ink, positions: <String, Offset>{
        n1: const Offset(100, 777),
        n2: const Offset(400, 888),
      });

      expect(token, isNotNull);
      expect(token!.lane.id, ink);
      expect(w.laneRow(ink)['deleted_at'], isNotNull, reason: '道软删');
      expect(w.laneState.map((l) => l.id), <String>[cyber], reason: '道从 state 里拿掉');
      expect(w.nodeRow(n1)['lane_id'], isNull);
      expect(w.nodeRow(n1)['position_x'], 100);
      expect(w.nodeRow(n1)['position_y'], 777);
      expect(w.nodeRow(n2)['lane_id'], isNull, reason: '产物节点同样清');
      expect(w.nodeRow(n2)['position_y'], 888);
      expect(w.nodeRow(other)['lane_id'], cyber, reason: '别的道的节点不动');
      expect(w.nodeRow(other)['position_y'], 500);
      expect(w.nodeRow(free)['position_y'], 900);
      // 节点控制器已从库重载：内存里同样是道外节点、新坐标。
      final n1Mem = w.nodeState.firstWhere((n) => n.id == n1);
      expect(n1Mem.laneId, isNull);
      expect(n1Mem.position, const Offset(100, 777));
      // 令牌里是解散前的世界坐标。
      expect(
        {for (final s in token.nodes) s.nodeId: s.position},
        <String, Offset>{n1: const Offset(100, 120), n2: const Offset(400, 200)},
      );
    });

    test('dissolveLane：库里有、内存没有的道内节点也被清 lane_id', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final seen = await w.node(ink, const Offset(10, 10));
      await w.load();
      // 节点控制器载完之后才进库的道内节点：内存里没有它。
      final hidden = await w.node(ink, const Offset(20, 30));
      expect(w.nodeState.map((n) => n.id), isNot(contains(hidden)), reason: '前置：内存里确实没有');

      await w.controller.dissolveLane(ink, positions: <String, Offset>{seen: const Offset(10, 10)});

      expect(w.nodeRow(hidden)['lane_id'], isNull);
      expect(w.nodeRow(hidden)['position_y'], 30, reason: 'positions 里没有的只清 lane_id、不动坐标');
      expect(w.nodeRow(seen)['lane_id'], isNull);
    });

    test('dissolveLane：所有写在一次 uow.run 里（顶层仓储无写入）', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final n1 = await w.node(ink, const Offset(0, 0));
      final n2 = await w.node(ink, const Offset(0, 50));
      await w.load();

      await w.controller.dissolveLane(ink, positions: <String, Offset>{
        n1: const Offset(0, 1),
        n2: const Offset(0, 2),
      });

      expect(w.uowRuns, 1);
      expect(w.nodeRow(n1)['lane_id'], isNull);
    });

    test('dissolveLane 事务抛错：泳道 state 原样、节点控制器未失效、InkError 上抛', () async {
      final w = _World(lanes: _ThrowingSoftDeleteLanes());
      final ink = await w.lane('Ink', 0);
      await w.node(ink, const Offset(0, 0));
      await w.load();
      final before = w.laneState;
      final loadsBefore = w.topNodes.loads;

      await expectLater(
        w.controller.dissolveLane(ink, positions: const <String, Offset>{}),
        throwsA(isA<InkError>()),
      );

      expect(w.laneState, before);
      expect(w.topNodes.loads, loadsBefore, reason: '失败不让节点控制器重载');
    });

    test('dissolveLane：未知 laneId ⇒ null、不碰库', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final n1 = await w.node(ink, const Offset(0, 0));
      await w.load();

      expect(await w.controller.dissolveLane('nope', positions: const <String, Offset>{}), isNull);
      expect(w.uowRuns, 0);
      expect(w.nodeRow(n1)['lane_id'], ink);
    });

    test('restoreDissolved：道回来、节点回旧坐标与旧 lane_id', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final cyber = await w.lane('Cyber', 1);
      final n1 = await w.node(ink, const Offset(100, 120));
      await w.load();
      final token = await w.controller.dissolveLane(ink, positions: <String, Offset>{
        n1: const Offset(100, 999),
      });

      await w.controller.restoreDissolved(token!);

      expect(w.laneRow(ink)['deleted_at'], isNull);
      expect(w.laneState.map((l) => l.id), <String>[ink, cyber], reason: '同名同风格、原下标');
      expect(w.laneState.first.label, 'Ink');
      expect(w.nodeRow(n1)['lane_id'], ink);
      expect(w.nodeRow(n1)['position_x'], 100);
      expect(w.nodeRow(n1)['position_y'], 120);
      final n1Mem = w.nodeState.firstWhere((n) => n.id == n1);
      expect(n1Mem.laneId, ink, reason: '节点控制器已重载');
      expect(n1Mem.position, const Offset(100, 120));
    });

    test('restoreDissolved：撤销前已被删的节点被跳过，其余照复原', () async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      final n1 = await w.node(ink, const Offset(0, 100));
      final n2 = await w.node(ink, const Offset(0, 200));
      await w.load();
      final token = await w.controller.dissolveLane(ink, positions: <String, Offset>{
        n1: const Offset(0, 101),
        n2: const Offset(0, 201),
      });
      await w.nodes.softDelete(n2);

      await w.controller.restoreDissolved(token!);

      expect(w.nodeRow(n1)['lane_id'], ink);
      expect(w.nodeRow(n2)['lane_id'], isNull, reason: '已删的节点不写回');
      expect(w.nodeRow(n2)['position_y'], 201);
      expect(w.nodeRow(n2)['deleted_at'], isNotNull, reason: '也不被顺手复原');
    });

    test('restoreDissolved：sort_order 撞号时复原的道回到旧下标', () async {
      final w = _World();
      final a = await w.lane('A', 0);
      final b = await w.lane('B', 1);
      final cLane = await w.lane('C', 2);
      await w.load();
      final token = await w.controller.dissolveLane(b, positions: const <String, Offset>{});
      // 解散后重排成 C, A ⇒ C 0、A 1：A 与 B 的旧 sort_order 1 撞号。
      await w.controller.reorderLanes(<String>[cLane, a]);

      await w.controller.restoreDissolved(token!);

      expect(w.laneState.map((l) => l.id), <String>[cLane, b, a]);
      expect(w.laneState.map((l) => l.sortOrder), <int>[0, 1, 2]);
      expect(w.laneRow(cLane)['sort_order'], 0);
      expect(w.laneRow(b)['sort_order'], 1);
      expect(w.laneRow(a)['sort_order'], 2);
    });

    test('restoreDissolved：画布已关（控制器 dispose）⇒ 空操作、不抛', () async {
      final w = _World(tearDown: false);
      final ink = await w.lane('Ink', 0);
      await w.load();
      final controller = w.controller;
      final token = await controller.dissolveLane(ink, positions: const <String, Offset>{});
      w.c.dispose(); // 关画布：控制器随容器 dispose
      w.uowRuns = 0;

      await controller.restoreDissolved(token!);

      expect(w.uowRuns, 0);
      expect(w.laneRow(ink)['deleted_at'], isNotNull);
    });
  });

  // ===== 删除泳道和内容 =====
  //
  // 变异对照：只删出边 ⇒「入 / 出边软删」红；删边与删节点拆进两次 run ⇒「一次 uow.run」红。
  group('deleteLaneWithContents / restoreLaneContents', () {
    /// 道 Ink 里 n1（配置）+ r1（n1 的产物）；道外 x、y。边：x→n1（入）、n1→y（出）、n1→r1（道内，出入各列一次）、
    /// x→y（道外两节点之间）。
    Future<
        ({
          _World w,
          String ink,
          String n1,
          String r1,
          String x,
          String y,
          String eIn,
          String eOut,
          String eInner,
          String eOutside,
        })> seed() async {
      final w = _World();
      final ink = await w.lane('Ink', 0);
      await w.lane('Cyber', 1);
      final n1 = await w.node(ink, const Offset(0, 0));
      final r1 = await w.node(ink, const Offset(300, 0), role: 'result', sourceNodeId: n1);
      final x = await w.node(null, const Offset(0, 900));
      final y = await w.node(null, const Offset(300, 900));
      final eIn = await w.edge(x, n1);
      final eOut = await w.edge(n1, y);
      final eInner = await w.edge(n1, r1);
      final eOutside = await w.edge(x, y);
      await w.load();
      return (
        w: w,
        ink: ink,
        n1: n1,
        r1: r1,
        x: x,
        y: y,
        eIn: eIn,
        eOut: eOut,
        eInner: eInner,
        eOutside: eOutside,
      );
    }

    test('道 + 道内节点 + 入 / 出边软删，边去重；道外两节点之间的边不动', () async {
      final s = await seed();
      final w = s.w;

      final token = await w.controller.deleteLaneWithContents(s.ink);

      expect(token, isNotNull);
      expect(token!.nodeIds.toSet(), <String>{s.n1, s.r1});
      expect(token.edgeIds.toSet(), <String>{s.eIn, s.eOut, s.eInner});
      expect(token.edgeIds, hasLength(3), reason: '道内那条边只记一次');
      expect(w.laneRow(s.ink)['deleted_at'], isNotNull);
      expect(w.nodeRow(s.n1)['deleted_at'], isNotNull);
      expect(w.nodeRow(s.r1)['deleted_at'], isNotNull, reason: '产物节点一并删');
      expect(w.edgeRow(s.eIn)['deleted_at'], isNotNull, reason: '入边');
      expect(w.edgeRow(s.eOut)['deleted_at'], isNotNull, reason: '出边');
      expect(w.edgeRow(s.eInner)['deleted_at'], isNotNull);
      expect(w.edgeRow(s.eOutside)['deleted_at'], isNull, reason: '道外两节点之间的边不动');
      expect(w.nodeRow(s.x)['deleted_at'], isNull);
      expect(w.nodeRow(s.y)['deleted_at'], isNull);
      expect(w.laneState.map((l) => l.id), isNot(contains(s.ink)));
      expect(w.nodeState.map((n) => n.id).toSet(), <String>{s.x, s.y}, reason: '节点控制器已重载');
    });

    test('一次 uow.run（顶层仓储无写入）', () async {
      final s = await seed();

      await s.w.controller.deleteLaneWithContents(s.ink);

      expect(s.w.uowRuns, 1);
    });

    test('restoreLaneContents：道、节点、边全部复原', () async {
      final s = await seed();
      final w = s.w;
      final token = await w.controller.deleteLaneWithContents(s.ink);

      await w.controller.restoreLaneContents(token!);

      expect(w.laneRow(s.ink)['deleted_at'], isNull);
      for (final id in <String>[s.n1, s.r1]) {
        expect(w.nodeRow(id)['deleted_at'], isNull);
        expect(w.nodeRow(id)['lane_id'], s.ink);
      }
      for (final id in <String>[s.eIn, s.eOut, s.eInner, s.eOutside]) {
        expect(w.edgeRow(id)['deleted_at'], isNull);
      }
      expect(w.laneState.first.id, s.ink, reason: '回到原下标');
      expect(w.nodeState.map((n) => n.id).toSet(), <String>{s.n1, s.r1, s.x, s.y});
    });

    test('未知 laneId ⇒ null、无写入', () async {
      final s = await seed();

      expect(await s.w.controller.deleteLaneWithContents('nope'), isNull);

      expect(s.w.uowRuns, 0);
      expect(s.w.nodeRow(s.n1)['deleted_at'], isNull);
      expect(s.w.edgeRow(s.eIn)['deleted_at'], isNull);
      expect(s.w.laneRow(s.ink)['deleted_at'], isNull);
    });
  });
}
