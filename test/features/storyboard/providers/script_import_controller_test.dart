// SB-2 批量建链：一串 ShotDraft → N 个 shot 节点 + N-1 条 narrative 边，**单事务**。
//
// 「失败无残留」是本卡验收的核心：中途任一步抛错，画布上不该留下半条链
// （3 个孤零零的 shot 比一个错误提示更难收拾）。这里的 fake UoW 会真回滚
// ——写入先落 staging，闭包整体成功才 commit；真事务的回滚语义由
// test/storage/transaction_integration_test.dart（真 PG）兜底。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/storyboard/providers/script_import_controller.dart';
import 'package:inkframe/features/storyboard/util/script_splitter.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';

typedef _NodeCreate = ({
  String canvasId,
  String type,
  String role,
  String label,
  double x,
  double y,
  Map<String, Object?> typeConfig,
});

typedef _EdgeCreate = ({
  String canvasId,
  String source,
  String target,
  String type,
  int sortOrder,
});

/// 只实现 create 的仓储；写入先进 staging，由 [_TxUnitOfWork] 决定 commit/回滚。
class _TxNodeRepo implements NodeRepository {
  _TxNodeRepo({this.failAt});

  /// 第几次 create 抛错（0-based）；null = 永不失败。
  final int? failAt;

  final List<_NodeCreate> committed = <_NodeCreate>[];
  final List<_NodeCreate> _pending = <_NodeCreate>[];
  int _seq = 0;

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
    final int index = _seq++;
    if (index == failAt) throw const LocalIOError();
    _pending.add((
      canvasId: canvasId,
      type: type,
      role: nodeRole,
      label: label,
      x: positionX,
      y: positionY,
      typeConfig: typeConfig,
    ));
    return 'n$index';
  }

  void commit() {
    committed.addAll(_pending);
    _pending.clear();
  }

  void rollback() => _pending.clear();

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _TxEdgeRepo implements EdgeRepository {
  _TxEdgeRepo({this.failAt});

  final int? failAt;

  final List<_EdgeCreate> committed = <_EdgeCreate>[];
  final List<_EdgeCreate> _pending = <_EdgeCreate>[];
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
    final int index = _seq++;
    if (index == failAt) throw const LocalIOError();
    _pending.add((
      canvasId: canvasId,
      source: sourceNodeId,
      target: targetNodeId,
      type: edgeType,
      sortOrder: sortOrder,
    ));
    return 'e$index';
  }

  void commit() {
    committed.addAll(_pending);
    _pending.clear();
  }

  void rollback() => _pending.clear();

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// 会真回滚的 fake：闭包整体成功才 commit，抛 InkError 则清空 staging。
class _TxUnitOfWork implements UnitOfWork {
  _TxUnitOfWork(this.nodes, this.edges);

  final _TxNodeRepo nodes;
  final _TxEdgeRepo edges;
  int runs = 0;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async {
    runs++;
    try {
      final T result =
          await action(FakeRepositoryScope(nodes: nodes, edges: edges));
      nodes.commit();
      edges.commit();
      return result;
    } on InkError {
      nodes.rollback();
      edges.rollback();
      rethrow;
    }
  }
}

/// listByCanvas 计数——用来断言导入成功后确实 invalidate 了控制器。
class _CountingNodeRepo extends InMemoryNodeRepository {
  int listCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    listCalls++;
    return super.listByCanvas(canvasId);
  }
}

class _CountingEdgeRepo extends InMemoryEdgeRepository {
  int listCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    listCalls++;
    return super.listByCanvas(canvasId);
  }
}

void main() {
  const String canvasId = 'cv1';

  const List<ShotDraft> threeDrafts = <ShotDraft>[
    ShotDraft(label: '山径破晓', notes: '山径破晓\n晨光初现'),
    ShotDraft(label: '渡索桥', notes: '渡索桥'),
    ShotDraft(label: '茶棚避雨', notes: '茶棚避雨'),
  ];

  late _TxNodeRepo nodes;
  late _TxEdgeRepo edges;
  late _TxUnitOfWork uow;
  late ProviderContainer container;

  void build({int? nodeFailAt, int? edgeFailAt}) {
    nodes = _TxNodeRepo(failAt: nodeFailAt);
    edges = _TxEdgeRepo(failAt: edgeFailAt);
    uow = _TxUnitOfWork(nodes, edges);
    container = ProviderContainer(
      overrides: <Override>[
        unitOfWorkProvider.overrideWith((ref) async => uow),
      ],
    );
    addTearDown(container.dispose);
  }

  ScriptImportController controllerOf(ProviderContainer c) =>
      c.read(scriptImportControllerProvider(canvasId));

  group('importDrafts · 成功路径', () {
    setUp(() => build());

    test('N 段 → N 个 shot config 节点，label/备注原样落地', () async {
      final int created =
          await controllerOf(container).importDrafts(threeDrafts);

      expect(created, 3);
      expect(nodes.committed, hasLength(3));
      expect(nodes.committed.map((n) => n.type), everyElement('shot'));
      expect(nodes.committed.map((n) => n.role), everyElement('config'));
      expect(nodes.committed.map((n) => n.canvasId), everyElement(canvasId));
      expect(nodes.committed.map((n) => n.label),
          <String>['山径破晓', '渡索桥', '茶棚避雨']);
      expect(nodes.committed.first.typeConfig['shot_notes'], '山径破晓\n晨光初现');
    });

    test('相邻两镜串一条 narrative 边：N 段 → N-1 条', () async {
      await controllerOf(container).importDrafts(threeDrafts);

      expect(edges.committed, hasLength(2));
      expect(edges.committed.map((e) => e.type), everyElement('narrative'));
      expect(edges.committed[0].source, 'n0');
      expect(edges.committed[0].target, 'n1');
      expect(edges.committed[1].source, 'n1');
      expect(edges.committed[1].target, 'n2');
      expect(edges.committed.map((e) => e.sortOrder), <int>[0, 1]);
    });

    test('横向排布，每镜一格；origin 缺省为世界原点', () async {
      await controllerOf(container).importDrafts(threeDrafts);

      expect(nodes.committed.map((n) => n.x),
          <double>[0, kShotChainSpacingX, kShotChainSpacingX * 2]);
      expect(nodes.committed.map((n) => n.y), everyElement(0.0));
    });

    test('origin 平移整条链（落在视口中心而不是世界原点）', () async {
      await controllerOf(container)
          .importDrafts(threeDrafts, origin: const Offset(1000, -500));

      expect(nodes.committed.first.x, 1000);
      expect(nodes.committed.first.y, -500);
      expect(nodes.committed.last.x, 1000 + kShotChainSpacingX * 2);
      expect(nodes.committed.map((n) => n.y), everyElement(-500.0));
    });

    test('单镜 → 1 个节点 0 条边（不自连）', () async {
      final int created = await controllerOf(container).importDrafts(
        const <ShotDraft>[ShotDraft(label: 'A', notes: 'A')],
      );

      expect(created, 1);
      expect(nodes.committed, hasLength(1));
      expect(edges.committed, isEmpty);
    });

    test('整批只开一个事务', () async {
      await controllerOf(container).importDrafts(threeDrafts);
      expect(uow.runs, 1);
    });
  });

  group('importDrafts · 退化输入', () {
    setUp(() => build());

    test('空清单 → 返回 0 且不开事务', () async {
      final int created =
          await controllerOf(container).importDrafts(const <ShotDraft>[]);

      expect(created, 0);
      expect(uow.runs, 0);
      expect(nodes.committed, isEmpty);
    });
  });

  group('importDrafts · 失败无残留', () {
    test('第 3 个节点建失败 → InkError 冒泡，前两个也不落地', () async {
      build(nodeFailAt: 2);

      await expectLater(
        controllerOf(container).importDrafts(threeDrafts),
        throwsA(isA<InkError>()),
      );
      expect(nodes.committed, isEmpty);
      expect(edges.committed, isEmpty);
    });

    test('建边失败 → 节点同样整体回滚（不留下没串起来的散镜）', () async {
      build(edgeFailAt: 1);

      await expectLater(
        controllerOf(container).importDrafts(threeDrafts),
        throwsA(isA<InkError>()),
      );
      expect(nodes.committed, isEmpty);
      expect(edges.committed, isEmpty);
    });
  });

  group('importDrafts · 落地后刷新画布', () {
    test('成功后节点与边控制器双双 invalidate', () async {
      final _CountingNodeRepo nodeRepo = _CountingNodeRepo();
      final _CountingEdgeRepo edgeRepo = _CountingEdgeRepo();
      nodes = _TxNodeRepo();
      edges = _TxEdgeRepo();
      uow = _TxUnitOfWork(nodes, edges);
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          unitOfWorkProvider.overrideWith((ref) async => uow),
          nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
          edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        ],
      );
      addTearDown(c.dispose);

      // 订阅让 autoDispose family 在整段用例里保持存活。
      c.listen(canvasNodesControllerProvider(canvasId), (_, _) {});
      c.listen(canvasEdgesControllerProvider(canvasId), (_, _) {});
      await c.read(canvasNodesControllerProvider(canvasId).future);
      await c.read(canvasEdgesControllerProvider(canvasId).future);
      expect(nodeRepo.listCalls, 1);
      expect(edgeRepo.listCalls, 1);

      await controllerOf(c).importDrafts(threeDrafts);
      await c.read(canvasNodesControllerProvider(canvasId).future);
      await c.read(canvasEdgesControllerProvider(canvasId).future);

      expect(nodeRepo.listCalls, 2, reason: '节点控制器未 invalidate');
      expect(edgeRepo.listCalls, 2, reason: '边控制器未 invalidate');
    });
  });
}
