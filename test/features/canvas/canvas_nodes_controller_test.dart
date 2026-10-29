// CanvasNodesController 单测 —— 用 fake NodeRepository 打桩，不接真 PG。
//
// 覆盖：初始 load、addNode 乐观更新 + DB create 参数透传、removeNode 乐观删除 +
// DB 失败回滚、moveNode 持久化位置 + 泳道 + InkError 回滚；批量写（moveNodes / removeNodes /
// restoreAll / patchTypeConfigMany / replaceTypeConfig）各一个事务、失败整批回滚内存。

import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';

import '../../_harness/fake_unit_of_work.dart';

class _FakeNodeRepository implements NodeRepository {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  final List<Map<String, Object?>> createCalls = <Map<String, Object?>>[];
  final List<String> softDeleted = <String>[];
  final List<String> restored = <String>[];
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  final List<Map<String, Object?>> patchCalls = <Map<String, Object?>>[];

  String? createError;
  String? softDeleteError;
  String? restoreError;
  String? updateError;

  /// 第 n 次（1 起，从本仓储建好起算）softDelete / update / patchTypeConfig 抛 LocalIOError；
  /// null = 不按次数失败。与上面「每次都抛」的字符串开关并存。
  int? failSoftDeleteAt;
  int? failUpdateAt;
  int? failPatchAt;
  int _softDeleteCount = 0;
  int _updateCount = 0;
  int _patchCount = 0;

  /// restore 返回的受影响行数（0 = 行已被硬删）。
  int restoreAffected = 1;

  /// 置入后 create 会先 await 此 gate，用于制造两次 create 交错（LB-04）。
  Completer<void>? createGate;

  int _idCounter = 0;

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
  }) async {
    if (createGate != null) await createGate!.future;
    createCalls.add(<String, Object?>{
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'label': label,
      'source_node_id': sourceNodeId,
      'position_x': positionX,
      'position_y': positionY,
      'width': width,
      'height': height,
      'type_config': typeConfig,
    });
    if (createError != null) {
      throw LocalIOError(extra: {'op': 'create', 'table': 'nodes', 'msg': createError});
    }
    final id = 'n${++_idCounter}';
    rows.add(<String, Object?>{
      'id': id,
      'canvas_id': canvasId,
      'type': type,
      'node_role': nodeRole,
      'label': label,
      'source_node_id': sourceNodeId,
      'position_x': positionX,
      'position_y': positionY,
      'width': width,
      'height': height,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async {
    return rows
        .where((r) => r['canvas_id'] == canvasId)
        .toList(growable: false);
  }

  @override
  Future<int> softDelete(String id) async {
    if (softDeleteError != null) {
      throw LocalIOError(
          extra: {'op': 'softDelete', 'table': 'nodes', 'msg': softDeleteError});
    }
    if (++_softDeleteCount == failSoftDeleteAt) {
      throw LocalIOError(extra: {'op': 'softDelete', 'table': 'nodes', 'nth': failSoftDeleteAt});
    }
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  // ---- 未用到的接口 ----
  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      rows.firstWhere((r) => r['id'] == id, orElse: () => const {});
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) async =>
      const [];
  @override
  Future<int> softDeleteEmptyOrphanResults() async => 0;

  @override
  Future<List<String>> listAllMediaUrls() async => const <String>[];
  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    updateCalls.add(<String, Object?>{'id': id, ...patch});
    if (updateError != null) {
      throw LocalIOError(extra: {'op': 'update', 'table': 'nodes', 'msg': updateError});
    }
    if (++_updateCount == failUpdateAt) {
      throw LocalIOError(extra: {'op': 'update', 'table': 'nodes', 'nth': failUpdateAt});
    }
    final row = rows.firstWhere((r) => r['id'] == id, orElse: () => <String, Object?>{});
    row.addAll(patch);
    return 1;
  }
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patchCalls.add(<String, Object?>{'id': id, 'patch': patch});
    if (++_patchCount == failPatchAt) {
      throw LocalIOError(
          extra: {'op': 'patchTypeConfig', 'table': 'nodes', 'nth': failPatchAt});
    }
    return 1;
  }
  @override
  Future<int> restore(String id) async {
    if (restoreError != null) {
      throw LocalIOError(
          extra: {'op': 'restore', 'table': 'nodes', 'msg': restoreError});
    }
    restored.add(id);
    return restoreAffected;
  }

  /// hardDelete 收到的 id（按调用顺序）。
  final List<String> hardDeleted = <String>[];
  String? hardDeleteError;

  @override
  Future<int> hardDelete(String id) async {
    hardDeleted.add(id);
    if (hardDeleteError != null) {
      throw LocalIOError(
          extra: {'op': 'hardDelete', 'table': 'nodes', 'msg': hardDeleteError});
    }
    final int before = rows.length;
    rows.removeWhere((r) => r['id'] == id);
    return before - rows.length;
  }
}

class _FakeEdgeRepo implements EdgeRepository {
  final List<Map<String, Object?>> rows = [];
  final List<String> softDeleted = [];
  final List<String> restored = [];

  /// listByCanvas 被调用的次数。discardImportShell 让边控制器失效后应再加 1。
  int listByCanvasCalls = 0;

  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  }) async {
    final id = 'e${rows.length + 1}';
    rows.add({
      'id': id,
      'source_node_id': sourceNodeId,
      'target_node_id': targetNodeId,
    });
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String s) async =>
      rows.where((r) => r['source_node_id'] == s).toList();

  @override
  Future<List<Map<String, Object?>>> listIncoming(String t) async =>
      rows.where((r) => r['target_node_id'] == t).toList();

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    rows.removeWhere((r) => r['id'] == id);
    return 1;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c) async {
    listByCanvasCalls++;
    return rows.where((r) => r['canvas_id'] == c).toList(growable: false);
  }
  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 0;
  @override
  Future<int> restore(String id) async {
    restored.add(id);
    return 1;
  }

  @override
  Future<int> hardDelete(String id) async => 0;
}

/// 数 `run` 次数的 UnitOfWork：包一层 FakeUnitOfWork，每次 run 先计数再原样转交。
/// 照 canvas_edges_controller_test.dart 的 _CountingUnitOfWork。
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

void main() {
  late _FakeNodeRepository repo;
  late _FakeEdgeRepo edgeRepo;
  late ProviderContainer container;

  /// 主容器里 `uow.run` 被调了几次——批量写「一个事务」靠它钉（见「批量写」组头）。
  late int uowRuns;

  setUp(() {
    repo = _FakeNodeRepository();
    edgeRepo = _FakeEdgeRepo();
    uowRuns = 0;
    container = ProviderContainer(
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => _CountingUnitOfWork(
            FakeUnitOfWork(FakeRepositoryScope(nodes: repo, edges: edgeRepo)),
            onRun: () => uowRuns++,
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  const canvasId = 'cvx';

  group('CanvasNodesController', () {
    test('build 从 Repository 加载节点', () async {
      repo.rows.add(<String, Object?>{
        'id': 'seed',
        'canvas_id': canvasId,
        'type': 'image',
        'node_role': 'config',
        'label': 'Seed',
        'position_x': 10.0,
        'position_y': 20.0,
      });
      final nodes = await container
          .read(canvasNodesControllerProvider(canvasId).future);
      expect(nodes, hasLength(1));
      expect(nodes.first.id, 'seed');
      expect(nodes.first.role, NodeRole.config);
      expect(nodes.first.position, const Offset(10, 20));
    });

    test('build 收敛存量越界坐标进 ±kWorldReach（#186 评审 P2-1）', () async {
      // 旧模型（内容驱动生长）允许 >50k 的合法坐标；新定舞台下这些节点
      // 会越出 100k Stack 命中区，永久不可达。加载期一次性收敛（不回写 DB）。
      repo.rows.add(<String, Object?>{
        'id': 'far',
        'canvas_id': canvasId,
        'type': 'image',
        'node_role': 'config',
        'label': 'Far',
        'position_x': 55000.0,
        'position_y': -60000.0,
      });
      repo.rows.add(<String, Object?>{
        'id': 'near',
        'canvas_id': canvasId,
        'type': 'image',
        'node_role': 'config',
        'label': 'Near',
        'position_x': 10.0,
        'position_y': 20.0,
      });
      final nodes = await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final far = nodes.firstWhere((n) => n.id == 'far');
      expect(far.position, const Offset(kWorldReach, -kWorldReach));
      // 界内节点原样保留。
      final near = nodes.firstWhere((n) => n.id == 'near');
      expect(near.position, const Offset(10, 20));
      // 收敛只在内存层，不产生 DB 写。
      expect(repo.updateCalls, isEmpty);
    });

    test('addNode 乐观更新 + 透传 Repository.create 参数', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(100, 200),
      );

      expect(inserted.id, isNotEmpty);
      expect(inserted.role, NodeRole.config);
      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['node_role'], 'config');
      expect(repo.createCalls.first['position_x'], 100.0);

      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
    });

    test('addNode 不传 size → 四类同取卡片渲染尺寸 kNodeCardSize', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final image = await ctrl.addNode(label: 'I', type: CanvasNodeType.image);
      final video = await ctrl.addNode(label: 'V', type: CanvasNodeType.video);
      final shot = await ctrl.addNode(label: 'S', type: CanvasNodeType.shot);
      final text = await ctrl.addNode(label: 'T', type: CanvasNodeType.text);

      expect(image.size, defaultNodeSize(CanvasNodeType.image));
      expect(video.size, defaultNodeSize(CanvasNodeType.video));
      expect(shot.size, defaultNodeSize(CanvasNodeType.shot));
      expect(text.size, defaultNodeSize(CanvasNodeType.text));
      // Workspace v2 稿：所有类型同尺寸 224×172。
      expect(image.size, kNodeCardSize);
      // 透传到 Repository.create
      expect(repo.createCalls.first['width'],
          defaultNodeSize(CanvasNodeType.image).width);
    });

    test('addNode 显式传 size → 覆盖类型默认', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final n = await ctrl.addNode(
        label: 'X',
        type: CanvasNodeType.image,
        size: const Size(111, 99),
      );
      expect(n.size, const Size(111, 99));
    });

    test('addNode 透传 typeConfig：乐观对象 + Repository.create 都带上', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted = await ctrl.addNode(
        label: 'S',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'wide shot'},
      );

      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.first['type_config'],
          <String, Object?>{'prompt': 'wide shot'});
      expect(inserted.typeConfig, <String, Object?>{'prompt': 'wide shot'});

      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.single.typeConfig,
          <String, Object?>{'prompt': 'wide shot'});
    });

    test('addNode 不传 typeConfig → 默认空 map，行为不变', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final inserted =
          await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      expect(repo.createCalls.first['type_config'], isEmpty);
      expect(inserted.typeConfig, isEmpty);
    });

    test('addNode 两次并发交错不丢更新（LB-04 串行化）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);

      // gate 挂起两次 create，使二者在任一写回 state 之前都读到同一空快照。
      final gate = Completer<void>();
      repo.createGate = gate;

      final fa = ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final fb = ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      gate.complete();
      await Future.wait([fa, fb]);

      final state = container.read(canvasNodesControllerProvider(canvasId));
      // 未串行化时后者用空快照覆盖前者 → 只剩 1 个（RED）。
      expect(state.valueOrNull, hasLength(2),
          reason: '两次并发 addNode 都应保留，交错快照不得覆盖');
      expect(
        state.valueOrNull!.map((n) => n.label),
        containsAll(<String>['A', 'B']),
      );
    });

    test('addNode DB 失败抛给调用方，内存不写入', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      repo.createError = 'boom';

      await expectLater(
        ctrl.addNode(label: 'X', type: CanvasNodeType.image),
        throwsA(isA<LocalIOError>()),
      );
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, isEmpty);
      expect(repo.rows, isEmpty,
          reason: '失败路径不该在 fake DB 里落下行');
    });

    test('result 节点必须带 sourceNodeId（assert）', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      expect(
        () => ctrl.addNode(
          label: 'R',
          type: CanvasNodeType.image,
          role: NodeRole.result,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('addImportShell 建出 role=result、sourceNodeId=null、type_config 含 origin / original_name、'
        '内存节点带 projectId', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final shell = await ctrl.addImportShell(
        label: '雾江.jpg',
        type: CanvasNodeType.image,
        projectId: 'p1',
        laneId: 'lane1',
        position: const Offset(40, 60),
        originalName: '雾江.jpg',
      );

      expect(shell.role, NodeRole.result);
      expect(shell.sourceNodeId, isNull);
      expect(shell.projectId, 'p1');
      expect(shell.canvasId, canvasId);
      expect(shell.laneId, 'lane1');
      expect(shell.position, const Offset(40, 60));
      expect(shell.size, kNodeCardSize);
      expect(shell.typeConfig, <String, Object?>{
        'origin': 'import',
        'original_name': '雾江.jpg',
      });

      final call = repo.createCalls.single;
      expect(call['node_role'], 'result');
      expect(call['source_node_id'], isNull);
      expect(call['type'], 'image');
      expect(call['label'], '雾江.jpg');
      expect(call['type_config'], <String, Object?>{
        'origin': 'import',
        'original_name': '雾江.jpg',
      });

      final inMemory =
          container.read(canvasNodesControllerProvider(canvasId)).requireValue;
      expect(inMemory.single.id, shell.id);
      expect(inMemory.single.projectId, 'p1');
    });

    test('addImportShell 视频壳 type=video', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      final shell = await ctrl.addImportShell(
        label: '船桨.mp4',
        type: CanvasNodeType.video,
        projectId: 'p1',
        originalName: '船桨.mp4',
      );

      expect(shell.type, CanvasNodeType.video);
      expect(repo.createCalls.single['type'], 'video');
      expect(shell.role, NodeRole.result);
    });

    test('discardImportShell 硬删无 url 的导入壳：移出内存、不软删、边控制器失效', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final shell = await ctrl.addImportShell(
        label: 'a.png',
        type: CanvasNodeType.image,
        projectId: 'p1',
        originalName: 'a.png',
      );

      // 锁定既有行为：复制期间从壳上拉过的线，硬删后 CASCADE 已不在库里，边控制器必须重读。
      // 拿掉 discardImportShell 里的 ref.invalidate(canvasEdgesControllerProvider) 会变红。
      edgeRepo.rows.add(<String, Object?>{
        'id': 'e-shell',
        'canvas_id': canvasId,
        'source_node_id': shell.id,
        'target_node_id': 'other',
        'edge_type': 'data',
        'role': 'reference',
        'sort_order': 0,
      });
      final subscription = container.listen(
        canvasEdgesControllerProvider(canvasId),
        (Object? previous, Object? next) {},
      );
      addTearDown(subscription.close);
      final List<CanvasEdge> before =
          await container.read(canvasEdgesControllerProvider(canvasId).future);
      expect(before.map((e) => e.id), contains('e-shell'));
      final int callsBefore = edgeRepo.listByCanvasCalls;

      // 硬删在 invalidate 之前完成 CASCADE。先从仓储拿掉这条边，重读才能看到它消失。
      // invalidate 只是把重读登记进微任务，要等边控制器的 future 落定，listByCanvas 才跑完。
      edgeRepo.rows.removeWhere((r) => r['id'] == 'e-shell');
      await ctrl.discardImportShell(shell.id);
      final List<CanvasEdge> after =
          await container.read(canvasEdgesControllerProvider(canvasId).future);

      expect(edgeRepo.listByCanvasCalls, callsBefore + 1);
      expect(after.map((e) => e.id), isNot(contains('e-shell')));

      expect(repo.hardDeleted, <String>[shell.id]);
      expect(repo.softDeleted, isEmpty, reason: '失败的壳不进回收站');
      expect(repo.rows, isEmpty);
      expect(
        container.read(canvasNodesControllerProvider(canvasId)).requireValue,
        isEmpty,
      );
    });

    test('discardImportShell 只限无 url 的导入节点：带 url 的导入节点 / 非导入节点调了不动',
        () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final done = await ctrl.addImportShell(
        label: 'a.png',
        type: CanvasNodeType.image,
        projectId: 'p1',
        originalName: 'a.png',
      );
      await ctrl.patchTypeConfigMany(<String, Map<String, Object?>>{
        done.id: <String, Object?>{'image_url': 'imports/x.png'},
      });
      final plain = await ctrl.addNode(label: 'cfg', type: CanvasNodeType.image);

      await ctrl.discardImportShell(done.id);
      await ctrl.discardImportShell(plain.id);

      expect(repo.hardDeleted, isEmpty);
      final ids = container
          .read(canvasNodesControllerProvider(canvasId))
          .requireValue
          .map((n) => n.id)
          .toList();
      expect(ids, <String>[done.id, plain.id]);
    });

    test('discardImportShell 对不在内存的 id 仍 hardDelete', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);

      await ctrl.discardImportShell('gone');

      expect(repo.hardDeleted, <String>['gone']);
    });

    test('discardImportShell DB 失败 ⇒ 内存回滚、抛 LocalIOError', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final shell = await ctrl.addImportShell(
        label: 'a.png',
        type: CanvasNodeType.image,
        projectId: 'p1',
      );
      repo.hardDeleteError = 'boom';

      await expectLater(
        ctrl.discardImportShell(shell.id),
        throwsA(isA<LocalIOError>()),
      );
      expect(
        container
            .read(canvasNodesControllerProvider(canvasId))
            .requireValue
            .map((n) => n.id),
        <String>[shell.id],
      );
    });

    test('removeNode 乐观删除 + DB softDelete', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      await ctrl.removeNode(n.id);

      expect(repo.softDeleted, contains(n.id));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, isEmpty);
    });

    test('removeNode DB 失败回滚内存', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      repo.softDeleteError = 'nope';

      await expectLater(ctrl.removeNode(n.id), throwsA(isA<LocalIOError>()));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull, hasLength(1));
      expect(state.valueOrNull!.first.id, n.id);
    });

    test('removeNode 级联软删相邻 edges（入+出）— 单事务', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);

      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: c.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: b.id,
        targetNodeId: a.id,
        edgeType: 'narrative',
      );

      await ctrl.removeNode(b.id);

      // b 的 2 条入边 + 1 条出边都应被 softDelete
      expect(edgeRepo.softDeleted, hasLength(3));
      expect(repo.softDeleted, contains(b.id));
    });

    test('removeNode 返回撤销令牌：节点 + 级联 edge id（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final e1 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );
      final e2 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: b.id,
        targetNodeId: a.id,
        edgeType: 'narrative',
      );

      final deletion = await ctrl.removeNode(a.id);

      expect(deletion, isNotNull);
      expect(deletion!.node.id, a.id);
      expect(deletion.edgeIds, containsAll(<String>[e1, e2]));
    });

    test('restore 复原节点 + 级联 edges，节点回到 state（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final e1 = await edgeRepo.create(
        canvasId: canvasId,
        sourceNodeId: a.id,
        targetNodeId: b.id,
        edgeType: 'data',
      );

      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);
      expect(
        container
            .read(canvasNodesControllerProvider(canvasId))
            .valueOrNull!
            .any((n) => n.id == a.id),
        isFalse,
      );

      await ctrl.restore(deletion!);

      expect(repo.restored, contains(a.id));
      expect(edgeRepo.restored, contains(e1));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.any((n) => n.id == a.id), isTrue);
    });

    test('restore DB 失败 → 乐观复原回滚（节点仍不在内存）（PL-4a）', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);
      repo.restoreError = 'nope';

      await expectLater(
          ctrl.restore(deletion!), throwsA(isA<LocalIOError>()));
      final state = container.read(canvasNodesControllerProvider(canvasId));
      expect(state.valueOrNull!.any((n) => n.id == a.id), isFalse);
    });

    test('restore 在 provider dispose 后 no-op，不抛 StateError（PL-4a 入口守卫）',
        () async {
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: repo, edges: edgeRepo),
          ),
        ),
      ]);
      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final deletion = await ctrl.removeNode(a.id);
      expect(deletion, isNotNull);

      c.dispose(); // 画布关闭 → notifier autoDispose，_alive=false

      // 窗口内点 Undo：入口 _alive 守卫先于 ref.read → no-op，绝不 StateError。
      await expectLater(ctrl.restore(deletion!), completes);
      expect(repo.restored, isEmpty, reason: 'dispose 后 restore 不落 DB');
    });

    test('removeNode 无关联 edges → 只软删节点', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'X', type: CanvasNodeType.image);
      await ctrl.removeNode(n.id);
      expect(repo.softDeleted, contains(n.id));
      expect(edgeRepo.softDeleted, isEmpty);
    });

    test('removeNode await 期间 provider dispose → 不抛 StateError（ME-27）',
        () async {
      final gate = Completer<void>();
      final gnode = _FakeNodeRepository()..softDeleteError = 'late failure';
      final gedge = _FakeEdgeRepo();
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => gnode),
        edgeRepositoryProvider.overrideWith((ref) async => gedge),
        unitOfWorkProvider.overrideWith(
          (ref) async => GatedFakeUnitOfWork(
            FakeRepositoryScope(nodes: gnode, edges: gedge),
            gate.future,
          ),
        ),
      ]);

      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      // 事务在 gate 上挂起；dispose 后 gate 放行 → node softDelete 失败。
      final pending = ctrl.removeNode(n.id);
      c.dispose(); // await 挂起期间整个容器销毁
      gate.complete();

      // dispose 后不得触 ref/state——只允许原始 InkError 冒泡，绝不 StateError。
      await expectLater(pending, throwsA(isA<LocalIOError>()));
    });

    test('moveNode 允许负坐标（全向），落点 clamp 到 ±kWorldReach', () async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl =
          container.read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'C',
        type: CanvasNodeType.image,
        position: const Offset(50, 80),
      );

      // 负方向拖拽合法（全向无限画布）。
      await ctrl.moveNode(n.id, const Offset(-500, -30), laneId: null);
      var moved = container
          .read(canvasNodesControllerProvider(canvasId))
          .valueOrNull!
          .single;
      expect(moved.position, const Offset(-450, 50));

      // 超出可漫游范围被夹到 ±kWorldReach。
      await ctrl.moveNode(
        n.id,
        const Offset(-kWorldReach * 3, kWorldReach * 3),
        laneId: null,
      );
      moved = container
          .read(canvasNodesControllerProvider(canvasId))
          .valueOrNull!
          .single;
      expect(moved.position, const Offset(-kWorldReach, kWorldReach));
    });

    test('moveNode 更新内存位置', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(10, 10),
      );

      await ctrl.moveNode(n.id, const Offset(5, -3), laneId: null);
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final moved = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(moved.position, const Offset(15, 7));
    });

    test('moveNode 持久化 position + lane_id 并更新 state', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(0, 0),
      );

      await ctrl.moveNode(n.id, const Offset(50, 60), laneId: 'lane-9');

      // repo.update 收到正确的持久化负载
      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['position_x'], 50.0);
      expect(repo.updateCalls.first['position_y'], 60.0);
      expect(repo.updateCalls.first['lane_id'], 'lane-9');

      // state 已乐观更新
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final moved = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(moved.position, const Offset(50, 60));
      expect(moved.laneId, 'lane-9');
    });

    test('moveNode DB 失败回滚内存位置', () async {
      await container
          .read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = container
          .read(canvasNodesControllerProvider(canvasId).notifier);
      final n = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        position: const Offset(10, 10),
      );

      repo.updateError = 'disk full';

      await expectLater(
        ctrl.moveNode(n.id, const Offset(50, 60), laneId: 'lane-9'),
        throwsA(isA<LocalIOError>()),
      );

      // 内存回滚到移动前的坐标
      final state = container.read(canvasNodesControllerProvider(canvasId));
      final rolled = state.valueOrNull!.firstWhere((x) => x.id == n.id);
      expect(rolled.position, const Offset(10, 10));
      expect(rolled.laneId, isNull);
    });
  });

  // 批量写：各一个事务、失败整批回滚内存。FakeUnitOfWork 不模拟库回滚——库里真回滚由
  // test/storage/transaction_integration_test.dart 的「节点批量删除」两条真 PG 用例钉。
  // 「一个事务」本身由 _CountingUnitOfWork 钉：成功用例断言 uowRuns == 1（调用前先清零，
  // 准备步骤里的 addNode / removeNodes 不算），不碰库的用例断言 uowRuns == 0。
  //
  // 变异对照：
  //   - moveNodes / patchTypeConfigMany / restoreAll / removeNodes 改成每行各开一个 uow.run，
  //     或绕过事务直接走 _repo ⇒ 各自的成功用例「uowRuns == 1」红
  //   - moveNodes 去掉 `if (targets.isEmpty) return;` ⇒「不在内存的 id 跳过、空 map 不碰库」红（uowRuns ≠ 0）
  //   - removeNodes catch 里删掉 `state = AsyncData(previous)` ⇒「第 3 张 softDelete 失败 ⇒ 内存三张都回来」红
  //   - 去掉 removeNodes 的边去重集合 ⇒「两张互连：共享边只软删一次」红
  //   - 删掉 restoreAll「已在内存不重复插入」⇒「restoreAll 一次复原全部…每张只出现一次」红
  //   - restoreAll 返回 deletions.length ⇒「restoreAll 返回受影响行数：行已硬删 ⇒ 0」红
  //   - 删掉 moveNodes 的 clamp ⇒「moveNodes 越界落点 clamp」红
  //   - 删掉 patchTypeConfigMany catch 里的回滚 ⇒「patchTypeConfigMany 失败整批回滚」红
  //   - replaceTypeConfig 改调 patchTypeConfig ⇒「replaceTypeConfig 整列覆盖」红（update 未被调）
  group('批量写', () {
    Future<CanvasNodesController> ready() async {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      return container.read(canvasNodesControllerProvider(canvasId).notifier);
    }

    List<CanvasNode> nodesNow() =>
        container.read(canvasNodesControllerProvider(canvasId)).valueOrNull!;

    CanvasNode nodeNow(String id) => nodesNow().firstWhere((n) => n.id == id);

    Future<String> edge(String from, String to) => edgeRepo.create(
          canvasId: canvasId,
          sourceNodeId: from,
          targetNodeId: to,
          edgeType: 'data',
        );

    test('moveNodes 一个事务写全部位置 + lane_id，内存同步', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
          label: 'A', type: CanvasNodeType.image, position: const Offset(0, 0));
      final b = await ctrl.addNode(
        label: 'B',
        type: CanvasNodeType.image,
        laneId: 'lane-0',
        position: const Offset(100, 100),
      );

      uowRuns = 0;
      await ctrl.moveNodes(<String, NodeMove>{
        a.id: (delta: const Offset(10, 20), laneId: 'lane-1'),
        b.id: (delta: const Offset(-5, 5), laneId: null),
      });

      expect(uowRuns, 1, reason: '整组一个事务：不是每行一个 uow.run，也不绕过事务');
      expect(repo.updateCalls, hasLength(2));
      final byId = <Object?, Map<String, Object?>>{
        for (final c in repo.updateCalls) c['id']: c,
      };
      expect(byId[a.id]!['position_x'], 10.0);
      expect(byId[a.id]!['position_y'], 20.0);
      expect(byId[a.id]!['lane_id'], 'lane-1');
      expect(byId[b.id]!['position_x'], 95.0);
      expect(byId[b.id]!['position_y'], 105.0);
      expect(byId[b.id]!.containsKey('lane_id'), isTrue);
      expect(byId[b.id]!['lane_id'], isNull, reason: 'laneId null = 移出泳道，要写进库');

      expect(nodeNow(a.id).position, const Offset(10, 20));
      expect(nodeNow(a.id).laneId, 'lane-1');
      expect(nodeNow(b.id).position, const Offset(95, 105));
      expect(nodeNow(b.id).laneId, isNull);
    });

    test('moveNodes 越界落点 clamp 到 ±kWorldReach', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
          label: 'A', type: CanvasNodeType.image, position: const Offset(50, 80));

      await ctrl.moveNodes(<String, NodeMove>{
        a.id: (delta: const Offset(-kWorldReach * 3, kWorldReach * 3), laneId: null),
      });

      expect(nodeNow(a.id).position, const Offset(-kWorldReach, kWorldReach));
      expect(repo.updateCalls.single['position_x'], -kWorldReach);
      expect(repo.updateCalls.single['position_y'], kWorldReach);
    });

    test('moveNodes 第 2 行 update 失败 ⇒ 内存两张都回原位、抛 LocalIOError', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
          label: 'A', type: CanvasNodeType.image, position: const Offset(10, 10));
      final b = await ctrl.addNode(
        label: 'B',
        type: CanvasNodeType.image,
        laneId: 'lane-0',
        position: const Offset(200, 10),
      );
      repo.failUpdateAt = 2;

      await expectLater(
        ctrl.moveNodes(<String, NodeMove>{
          a.id: (delta: const Offset(30, 30), laneId: 'lane-1'),
          b.id: (delta: const Offset(30, 30), laneId: null),
        }),
        throwsA(isA<LocalIOError>()),
      );

      expect(nodeNow(a.id).position, const Offset(10, 10));
      expect(nodeNow(a.id).laneId, isNull);
      expect(nodeNow(b.id).position, const Offset(200, 10));
      expect(nodeNow(b.id).laneId, 'lane-0');
    });

    test('moveNodes 不在内存的 id 跳过、空 map 不碰库', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
          label: 'A', type: CanvasNodeType.image, position: const Offset(0, 0));

      uowRuns = 0;
      await ctrl.moveNodes(const <String, NodeMove>{});
      await ctrl.moveNodes(<String, NodeMove>{
        'ghost': (delta: const Offset(1, 1), laneId: null),
      });
      expect(repo.updateCalls, isEmpty, reason: '空 map / 一个都不在 ⇒ 不碰库');
      expect(uowRuns, 0, reason: '空 map / 一个都不在 ⇒ 连事务都不开');

      await ctrl.moveNodes(<String, NodeMove>{
        'ghost': (delta: const Offset(1, 1), laneId: null),
        a.id: (delta: const Offset(4, 4), laneId: null),
      });
      expect(repo.updateCalls.map((c) => c['id']), <Object?>[a.id]);
      expect(nodesNow().map((n) => n.id), <String>[a.id]);
      expect(nodeNow(a.id).position, const Offset(4, 4));
    });

    test('removeNodes 一次删三张 + 级联边，返回三个令牌', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);
      final d = await ctrl.addNode(label: 'D', type: CanvasNodeType.image);
      final e1 = await edge(a.id, d.id);
      final e2 = await edge(d.id, b.id);
      final e3 = await edge(c.id, d.id);

      uowRuns = 0;
      final deletions = await ctrl.removeNodes(<String>{c.id, a.id, b.id});

      expect(uowRuns, 1, reason: '三张连同级联边一个事务');
      expect(deletions.map((t) => t.node.id), <String>[c.id, a.id, b.id],
          reason: '令牌顺序 = 入参迭代顺序');
      expect(deletions[0].edgeIds, <String>[e3]);
      expect(deletions[1].edgeIds, <String>[e1]);
      expect(deletions[2].edgeIds, <String>[e2]);
      expect(repo.softDeleted.toSet(), <String>{a.id, b.id, c.id});
      expect(edgeRepo.softDeleted.toSet(), <String>{e1, e2, e3});
      expect(nodesNow().map((n) => n.id), <String>[d.id]);
    });

    test('removeNodes 两张互连：共享边只软删一次、只记进一个令牌', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final e1 = await edge(a.id, b.id);
      final e2 = await edge(b.id, a.id);

      final deletions = await ctrl.removeNodes(<String>{a.id, b.id});

      expect(edgeRepo.softDeleted, hasLength(2), reason: '每条边只软删一次');
      expect(edgeRepo.softDeleted.toSet(), <String>{e1, e2});
      expect(deletions.map((t) => t.node.id), <String>[a.id, b.id]);
      expect(deletions[0].edgeIds.toSet(), <String>{e1, e2},
          reason: '边归第一个列到它的节点');
      expect(deletions[1].edgeIds, isEmpty, reason: '同一条边不进第二个令牌');
    });

    test('removeNodes 不在内存的 id 仍软删、不产令牌；空集合不碰库', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);

      expect(await ctrl.removeNodes(const <String>{}), isEmpty);
      expect(repo.softDeleted, isEmpty);

      final deletions = await ctrl.removeNodes(<String>{'ghost', a.id});
      expect(repo.softDeleted, <String>['ghost', a.id]);
      expect(deletions.map((t) => t.node.id), <String>[a.id]);
    });

    test('removeNodes 第 3 张 softDelete 失败 ⇒ 内存三张都回来、抛 InkError', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);
      repo.failSoftDeleteAt = 3;

      await expectLater(
        ctrl.removeNodes(<String>{a.id, b.id, c.id}),
        throwsA(isA<InkError>()),
      );

      expect(nodesNow().map((n) => n.id), <String>[a.id, b.id, c.id]);
    });

    test('restoreAll 一次复原全部节点和边，state 里每张只出现一次', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);
      final e1 = await edge(a.id, b.id);
      final e2 = await edge(b.id, c.id);
      final deletions = await ctrl.removeNodes(<String>{a.id, b.id});
      expect(nodesNow().map((n) => n.id), <String>[c.id]);

      // 再塞一张「节点此刻就在内存里」的令牌（c），边 id 与 b 的令牌重复。
      final stale = (node: c, edgeIds: <String>[e2]);
      uowRuns = 0; // 上面 removeNodes 那一次不算
      final affected = await ctrl.restoreAll(<NodeDeletion>[...deletions, stale]);

      expect(uowRuns, 1, reason: '全部节点和边一个事务复原');
      final ids = nodesNow().map((n) => n.id).toList();
      expect(ids, hasLength(3), reason: '已在内存的 c 不重复插入');
      expect(ids.toSet(), <String>{a.id, b.id, c.id});
      expect(repo.restored.toSet(), <String>{a.id, b.id, c.id});
      expect(repo.restored, hasLength(3), reason: '节点 id 去重');
      expect(edgeRepo.restored, hasLength(2), reason: '边 id 去重');
      expect(edgeRepo.restored.toSet(), <String>{e1, e2});
      expect(affected, 3);
    });

    test('restoreAll 失败 ⇒ 内存回到调用前', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final c = await ctrl.addNode(label: 'C', type: CanvasNodeType.image);
      final deletions = await ctrl.removeNodes(<String>{a.id, b.id});
      repo.restoreError = 'nope';

      await expectLater(ctrl.restoreAll(deletions), throwsA(isA<LocalIOError>()));

      expect(nodesNow().map((n) => n.id), <String>[c.id]);
    });

    test('restoreAll 在 dispose 后返回 0、不抛', () async {
      final c = ProviderContainer(overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: repo, edges: edgeRepo),
          ),
        ),
      ]);
      await c.read(canvasNodesControllerProvider(canvasId).future);
      final ctrl = c.read(canvasNodesControllerProvider(canvasId).notifier);
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final b = await ctrl.addNode(label: 'B', type: CanvasNodeType.image);
      final deletions = await ctrl.removeNodes(<String>{a.id, b.id});
      expect(deletions, hasLength(2));

      c.dispose(); // 画布关闭 → notifier autoDispose，_alive=false

      await expectLater(ctrl.restoreAll(deletions), completion(0));
      expect(repo.restored, isEmpty, reason: 'dispose 后 restoreAll 不落 DB');
    });

    test('restoreAll 返回受影响行数：行已硬删 ⇒ 0', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(label: 'A', type: CanvasNodeType.image);
      final deletions = await ctrl.removeNodes(<String>{a.id});
      repo.restoreAffected = 0;

      final affected = await ctrl.restoreAll(deletions);

      expect(affected, 0, reason: '全部为 0 ⇒ 调用方判「对象已不在」');
      expect(nodesNow().any((n) => n.id == a.id), isFalse,
          reason: '库里没有的行不留在内存里');
    });

    test('patchTypeConfigMany 合并进内存 + 逐个 patchTypeConfig', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'x', 'seed': 1},
      );
      final b = await ctrl.addNode(
        label: 'B',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'y'},
      );

      uowRuns = 0;
      await ctrl.patchTypeConfigMany(<String, Map<String, Object?>>{
        a.id: <String, Object?>{'seed': 2, 'negative': null},
        'ghost': <String, Object?>{'prompt': 'nobody'},
        b.id: <String, Object?>{'prompt': 'z'},
      });

      expect(uowRuns, 1, reason: '多张卡的 patch 一个事务');
      expect(repo.patchCalls.map((c) => c['id']), <Object?>[a.id, b.id],
          reason: '不在内存的 id 跳过');
      expect(repo.patchCalls.first['patch'],
          <String, Object?>{'seed': 2, 'negative': null});
      expect(nodeNow(a.id).typeConfig,
          <String, Object?>{'prompt': 'x', 'seed': 2, 'negative': null},
          reason: 'null 写成 JSON null、不删键（与 jsonb || 一致）');
      expect(nodeNow(b.id).typeConfig, <String, Object?>{'prompt': 'z'});
    });

    test('patchTypeConfigMany 第 2 行失败 ⇒ 内存整批回滚、抛 LocalIOError', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'x'},
      );
      final b = await ctrl.addNode(
        label: 'B',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'y'},
      );
      repo.failPatchAt = 2;

      await expectLater(
        ctrl.patchTypeConfigMany(<String, Map<String, Object?>>{
          a.id: <String, Object?>{'prompt': 'x2'},
          b.id: <String, Object?>{'prompt': 'y2'},
        }),
        throwsA(isA<LocalIOError>()),
      );

      expect(nodeNow(a.id).typeConfig, <String, Object?>{'prompt': 'x'});
      expect(nodeNow(b.id).typeConfig, <String, Object?>{'prompt': 'y'});
    });

    test('replaceTypeConfig 整列覆盖：update 收到的 type_config 不含被删的键', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'x', 'seed': 7},
      );

      await ctrl.replaceTypeConfig(a.id, <String, Object?>{'prompt': 'x'});

      expect(repo.patchCalls, isEmpty, reason: 'patch 删不掉键，必须走 update 整列覆盖');
      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.single['id'], a.id);
      expect(repo.updateCalls.single['type_config'], <String, Object?>{'prompt': 'x'});
      expect(nodeNow(a.id).typeConfig, <String, Object?>{'prompt': 'x'});

      // 节点不在内存 ⇒ 什么也不做。
      await ctrl.replaceTypeConfig('ghost', <String, Object?>{'prompt': 'y'});
      expect(repo.updateCalls, hasLength(1));
    });

    test('replaceTypeConfig 失败 ⇒ 回滚该节点的 type_config', () async {
      final ctrl = await ready();
      final a = await ctrl.addNode(
        label: 'A',
        type: CanvasNodeType.image,
        typeConfig: <String, Object?>{'prompt': 'x', 'seed': 7},
      );
      repo.updateError = 'disk full';

      await expectLater(
        ctrl.replaceTypeConfig(a.id, <String, Object?>{'prompt': 'x'}),
        throwsA(isA<LocalIOError>()),
      );

      expect(nodeNow(a.id).typeConfig, <String, Object?>{'prompt': 'x', 'seed': 7});
    });
  });
}
