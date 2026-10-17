// 真 PG 事务回滚集成测：UnitOfWork.run 中途抛错 → 整体回滚，无残留行。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/storage/postgres_unit_of_work.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:postgres/postgres.dart';

import 'schema/pg_test_harness.dart';

class _Skip implements Exception {}

/// 跨 scope 共享的 softDelete 计数：放在 scope 工厂外面。若计数跟着每个 scope 新建，
/// 「每张各开一个 uow.run」的变异会因计数每次归零而根本不抛——红的原因就不是「前两张已提交」。
class _SoftDeleteCounter {
  int calls = 0;
}

/// 委托给真仓储的 NodeRepository；第 [failAt] 次 softDelete（按共享计数）抛 LocalIOError。
class _FailNthSoftDeleteNodes implements NodeRepository {
  _FailNthSoftDeleteNodes(this._inner, this._counter, this._failAt);

  final NodeRepository _inner;
  final _SoftDeleteCounter _counter;
  final int _failAt;

  @override
  Future<int> softDelete(String id) async {
    _counter.calls++;
    if (_counter.calls == _failAt) {
      throw const LocalIOError(
          extra: <String, Object?>{'op': 'softDelete', 'table': 'nodes', 'injected': true});
    }
    return _inner.softDelete(id);
  }

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) =>
      _inner.create(
        canvasId: canvasId,
        type: type,
        nodeRole: nodeRole,
        label: label,
        sourceNodeId: sourceNodeId,
        laneId: laneId,
        positionX: positionX,
        positionY: positionY,
        width: width,
        height: height,
        zIndex: zIndex,
        typeConfig: typeConfig,
      );

  @override
  Future<Map<String, Object?>?> findById(String id) => _inner.findById(id);
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) =>
      _inner.listByCanvas(canvasId);
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) =>
      _inner.listOrphanResults(canvasId);
  @override
  Future<int> update(String id, Map<String, Object?> patch) => _inner.update(id, patch);
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) =>
      _inner.patchTypeConfig(id, patch);
  @override
  Future<int> restore(String id) => _inner.restore(id);
  @override
  Future<int> hardDelete(String id) => _inner.hardDelete(id);
  @override
  Future<int> softDeleteEmptyOrphanResults() => _inner.softDeleteEmptyOrphanResults();
  @override
  Future<List<String>> listAllMediaUrls() => _inner.listAllMediaUrls();
}

/// 生产装配 [base] 原样重装一份，只把 nodes 换成「第 [failAt] 次 softDelete 抛错」的包装。
RepositoryScope _failNthNodeSoftDelete(
  RepositoryScope base,
  _SoftDeleteCounter counter,
  int failAt,
) =>
    RepositoryScopeData(
      nodes: _FailNthSoftDeleteNodes(base.nodes, counter, failAt),
      edges: base.edges,
      canvas: base.canvas,
      projects: base.projects,
      jobs: base.jobs,
      styleLanes: base.styleLanes,
      batchResults: base.batchResults,
      characters: base.characters,
      promptPresets: base.promptPresets,
    );

/// 建一个项目 / 画布 / 三张节点 a、b、c + 两条边 a→b、b→c（直连仓储，不走事务）。
Future<({String canvasId, List<String> nodeIds})> _seedThreeNodesTwoEdges(
  Connection conn,
) async {
  final pid = await PostgresProjectRepository(conn).create(name: 'Batch');
  final cid = await PostgresCanvasRepository(conn).create(projectId: pid, name: 'C');
  final nodes = PostgresNodeRepository(conn);
  final ids = <String>[
    for (var i = 0; i < 3; i++)
      await nodes.create(canvasId: cid, type: 'image', nodeRole: 'config', label: 'N$i'),
  ];
  final edges = PostgresEdgeRepository(conn);
  await edges.create(
      canvasId: cid, sourceNodeId: ids[0], targetNodeId: ids[1], edgeType: 'data');
  await edges.create(
      canvasId: cid, sourceNodeId: ids[1], targetNodeId: ids[2], edgeType: 'data');
  return (canvasId: cid, nodeIds: ids);
}

/// 画布控制器的容器：build 读真节点仓储，removeNodes 走给定的工作单元。
ProviderContainer _canvasContainer(Connection conn, UnitOfWork uow) => ProviderContainer(
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => PostgresNodeRepository(conn)),
        unitOfWorkProvider.overrideWith((ref) async => uow),
      ],
    );

/// **就是**生产的工作单元装配（`postgresRepositoryScope`），不是副本。
///
/// 此前这里手抄了一份「与生产同构」的装配：生产里某个仓储接错会话，它的写入
/// 逃出事务、回滚不掉——而这个测试拿的是自己的副本，永远发现不了。
PostgresUnitOfWork _uow(SessionExecutor exec) =>
    PostgresUnitOfWork(exec, postgresRepositoryScope);

/// 某张表的行数（裸 SQL：要验的是"库里到底剩了什么"，不经仓储的过滤口径）。
Future<int> _count(Session conn, String table) async {
  final r = await conn.execute('SELECT count(*) FROM $table');
  return (r.first[0]! as num).toInt();
}

/// 某张表里没被软删的行数。
Future<int> _countLive(Session conn, String table) async {
  final r = await conn.execute('SELECT count(*) FROM $table WHERE deleted_at IS NULL');
  return (r.first[0]! as num).toInt();
}

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'tx');
  });
  tearDown(() async {
    await harness?.close();
  });

  PgTestHarness req() {
    final x = harness;
    if (x == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      throw _Skip();
    }
    return x;
  }

  test('闭包中途抛错 → 已写入的 project 行回滚（不残留）', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);
      final projects = PostgresProjectRepository(h.conn);

      await expectLater(
        uow.run((scope) async {
          await scope.projects.create(name: 'Alpha');
          // 第二步用不存在的 project_id 触发 FK 违例 → guard 翻成 LocalIOError → 回滚。
          await scope.canvas.create(
            projectId: '00000000-0000-0000-0000-000000000000',
            name: 'X',
          );
        }),
        throwsA(isA<LocalIOError>()),
      );

      // 回滚后 projects 表应为空。
      expect(await projects.listAll(), isEmpty);
    } on _Skip {
      return;
    }
  });

  test('闭包全部成功 → project + canvas 双双提交', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);
      final projects = PostgresProjectRepository(h.conn);
      final canvases = PostgresCanvasRepository(h.conn);

      await uow.run((scope) async {
        final pid = await scope.projects.create(name: 'Alpha');
        await scope.canvas.create(projectId: pid, name: 'C1');
      });

      final all = await projects.listAll();
      expect(all, hasLength(1));
      final cs = await canvases.listByProject(all.single['id']!.toString());
      expect(cs, hasLength(1));
    } on _Skip {
      return;
    }
  });

  // ON-2b 评审 P3①（BOARD 196）：与 `createSample` 同构的四步——项目 → 画布 →
  // 泳道 → 节点。上面两条只走了 projects + canvas 两个仓储；泳道和节点各是一个
  // 独立仓储，任何一个接错会话，就会在「第四步失败」时留下半截示例项目。
  test('示例项目同构四步：第四步失败 ⇒ 项目 / 画布 / 泳道一行不剩', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);

      await expectLater(
        uow.run((scope) async {
          final pid = await scope.projects.create(name: 'Sample');
          final cid = await scope.canvas.create(projectId: pid, name: 'C');
          await scope.styleLanes.create(canvasId: cid, label: 'L');
          // 第四步：不存在的 canvas_id ⇒ FK 违例 ⇒ 整个事务回滚。
          await scope.nodes.create(
            canvasId: '00000000-0000-0000-0000-000000000000',
            type: 'image',
            nodeRole: 'config',
          );
        }),
        throwsA(isA<LocalIOError>()),
      );

      expect(
        <String, int>{
          'projects': await _count(h.conn, 'projects'),
          'canvases': await _count(h.conn, 'canvases'),
          'style_lanes': await _count(h.conn, 'style_lanes'),
          'nodes': await _count(h.conn, 'nodes'),
        },
        <String, int>{
          'projects': 0,
          'canvases': 0,
          'style_lanes': 0,
          'nodes': 0,
        },
        reason: '有表留下了行 ⇒ 那个仓储的写入逃出了事务（接错会话）',
      );
    } on _Skip {
      return;
    }
  });

  test('示例项目同构四步：全部成功 ⇒ 四张表各一行', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);

      await uow.run((scope) async {
        final pid = await scope.projects.create(name: 'Sample');
        final cid = await scope.canvas.create(projectId: pid, name: 'C');
        final lid = await scope.styleLanes.create(canvasId: cid, label: 'L');
        await scope.nodes.create(
          canvasId: cid,
          type: 'image',
          nodeRole: 'config',
          laneId: lid,
        );
      });

      for (final String table in <String>[
        'projects',
        'canvases',
        'style_lanes',
        'nodes',
      ]) {
        expect(await _count(h.conn, table), 1, reason: '$table 应恰好一行');
      }
    } on _Skip {
      return;
    }
  });

  // 示例项目现在是两镜 + 第一镜 → 第二镜一条叙事边（序列标签打开就不空）：边是第五个独立
  // 仓储。它接错会话的话，「边那一步失败」时项目 / 画布 / 泳道 / 两镜节点都会留下来。
  test('示例项目同构：叙事边那一步失败 ⇒ 项目 / 画布 / 泳道 / 节点 / 边一行不剩', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);

      await expectLater(
        uow.run((scope) async {
          final pid = await scope.projects.create(name: 'Sample');
          final cid = await scope.canvas.create(projectId: pid, name: 'C');
          final lid = await scope.styleLanes.create(canvasId: cid, label: 'L');
          final first = await scope.nodes.create(
            canvasId: cid,
            type: 'image',
            nodeRole: 'config',
            laneId: lid,
          );
          await scope.nodes.create(
            canvasId: cid,
            type: 'image',
            nodeRole: 'config',
            laneId: lid,
          );
          // 不存在的 target_node_id ⇒ FK 违例 ⇒ 整个事务回滚。
          await scope.edges.create(
            canvasId: cid,
            sourceNodeId: first,
            targetNodeId: '00000000-0000-0000-0000-000000000000',
            edgeType: 'narrative',
          );
        }),
        throwsA(isA<LocalIOError>()),
      );

      expect(
        <String, int>{
          'projects': await _count(h.conn, 'projects'),
          'canvases': await _count(h.conn, 'canvases'),
          'style_lanes': await _count(h.conn, 'style_lanes'),
          'nodes': await _count(h.conn, 'nodes'),
          'edges': await _count(h.conn, 'edges'),
        },
        <String, int>{
          'projects': 0,
          'canvases': 0,
          'style_lanes': 0,
          'nodes': 0,
          'edges': 0,
        },
        reason: '有表留下了行 ⇒ 那个仓储的写入逃出了事务（接错会话）',
      );
    } on _Skip {
      return;
    }
  });

  test('示例项目同构：两镜 + 叙事边全部成功 ⇒ 两个节点、一条边', () async {
    try {
      final h = req();
      final uow = _uow(h.conn);

      await uow.run((scope) async {
        final pid = await scope.projects.create(name: 'Sample');
        final cid = await scope.canvas.create(projectId: pid, name: 'C');
        final lid = await scope.styleLanes.create(canvasId: cid, label: 'L');
        final first = await scope.nodes.create(
          canvasId: cid,
          type: 'image',
          nodeRole: 'config',
          laneId: lid,
        );
        final second = await scope.nodes.create(
          canvasId: cid,
          type: 'image',
          nodeRole: 'config',
          laneId: lid,
        );
        await scope.edges.create(
          canvasId: cid,
          sourceNodeId: first,
          targetNodeId: second,
          edgeType: 'narrative',
        );
      });

      expect(await _count(h.conn, 'nodes'), 2);
      expect(await _count(h.conn, 'edges'), 1);
    } on _Skip {
      return;
    }
  });

  // 画布多选删除（CanvasNodesController.removeNodes）：整批一个事务。
  // 变异：把 removeNodes 的单个 uow.run 改成每张各开一个 ⇒ 下面第一条红（前两张已提交）。
  // 计数器跨 scope 共享（见 _SoftDeleteCounter），所以那条变异红的原因确实是「前两张已提交」。
  test('节点批量删除：第 3 张 softDelete 失败 ⇒ 三张节点与相连边一行没删', () async {
    try {
      final h = req();
      final seed = await _seedThreeNodesTwoEdges(h.conn);
      final counter = _SoftDeleteCounter();
      final uow = PostgresUnitOfWork(
        h.conn,
        (s) => _failNthNodeSoftDelete(postgresRepositoryScope(s), counter, 3),
      );
      final container = _canvasContainer(h.conn, uow);
      addTearDown(container.dispose);
      final keep = container.listen(
          canvasNodesControllerProvider(seed.canvasId), (_, _) {});
      addTearDown(keep.close);

      await container.read(canvasNodesControllerProvider(seed.canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(seed.canvasId).notifier);

      await expectLater(
        ctrl.removeNodes(seed.nodeIds.toSet()),
        throwsA(isA<LocalIOError>()),
      );

      expect(counter.calls, 3, reason: '前提：确实走到了第 3 张 softDelete');
      expect(
        <String, int>{
          'nodes': await _countLive(h.conn, 'nodes'),
          'edges': await _countLive(h.conn, 'edges'),
        },
        <String, int>{'nodes': 3, 'edges': 2},
        reason: '有行被软删 ⇒ 批量删除不是一个事务（前几步已提交）',
      );
    } on _Skip {
      return;
    }
  });

  test('节点批量删除：全部成功 ⇒ 三张节点与相连边 deleted_at 都有值', () async {
    try {
      final h = req();
      final seed = await _seedThreeNodesTwoEdges(h.conn);
      final container = _canvasContainer(h.conn, _uow(h.conn));
      addTearDown(container.dispose);
      final keep = container.listen(
          canvasNodesControllerProvider(seed.canvasId), (_, _) {});
      addTearDown(keep.close);

      await container.read(canvasNodesControllerProvider(seed.canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(seed.canvasId).notifier);

      final deletions = await ctrl.removeNodes(seed.nodeIds.toSet());

      expect(deletions.map((d) => d.node.id), seed.nodeIds);
      expect(await _countLive(h.conn, 'nodes'), 0);
      expect(await _countLive(h.conn, 'edges'), 0);
      expect(await _count(h.conn, 'nodes'), 3, reason: '软删：行还在，deleted_at 有值');
      expect(await _count(h.conn, 'edges'), 2, reason: '软删：行还在，deleted_at 有值');
    } on _Skip {
      return;
    }
  });
}
