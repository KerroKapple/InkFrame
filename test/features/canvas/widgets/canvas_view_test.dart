// CanvasView widget 测试（ME-37 / FIX-009）：
// 连线成功 / 自连 / 重复(23505) / 其他失败 的 snackbar 分流 + 单选 / 多选交互。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/theme/components/ink_error_banner.dart';

import '../../../_harness/test_app.dart';

class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this._seed);
  final List<CanvasNode> _seed;
  final List<NodeDeletion> restoreCalls = <NodeDeletion>[];

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? removed;
    for (final n in previous) {
      if (n.id == id) removed = n;
    }
    state = AsyncData(
      previous.where((n) => n.id != id).toList(growable: false),
    );
    if (removed == null) return null;
    return (node: removed, edgeIds: const <String>[]);
  }

  @override
  Future<void> restore(NodeDeletion deletion) async {
    restoreCalls.add(deletion);
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData([...previous, deletion.node]);
  }
}

/// 边 undo 测试用：seed 一条边，捕获 removeEdge/restore 调用。
class _SeededEdgesController extends CanvasEdgesController {
  _SeededEdgesController(this._seed);
  final List<CanvasEdge> _seed;
  final List<CanvasEdge> restoreCalls = <CanvasEdge>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => _seed;

  @override
  Future<CanvasEdge?> removeEdge(String id) async {
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    CanvasEdge? removed;
    for (final e in previous) {
      if (e.id == id) removed = e;
    }
    state = AsyncData(previous.where((e) => e.id != id).toList(growable: false));
    return removed;
  }

  @override
  Future<void> restore(CanvasEdge edge) async {
    restoreCalls.add(edge);
    final previous = state.valueOrNull ?? const <CanvasEdge>[];
    state = AsyncData([...previous, edge]);
  }
}

/// 级联 undo 测试用：删节点时连带软删其关联边（token 记 edge id），restore 时
/// 连带复原——复刻真控制器 removeNode 级联 + restore + invalidate 的净效果。
class _CascadeNodesController extends CanvasNodesController {
  _CascadeNodesController(this._seed, this._edges);
  final List<CanvasNode> _seed;
  final _SeededEdgesController _edges;
  final Map<String, CanvasEdge> _removedEdges = <String, CanvasEdge>{};

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? removed;
    for (final n in previous) {
      if (n.id == id) removed = n;
    }
    state = AsyncData(previous.where((n) => n.id != id).toList(growable: false));
    // 级联软删该节点的关联边，边 id 记入撤销令牌。
    final edgeIds = <String>[];
    final edges = _edges.state.valueOrNull ?? const <CanvasEdge>[];
    for (final e in List<CanvasEdge>.of(edges)) {
      if (e.sourceNodeId == id || e.targetNodeId == id) {
        final r = await _edges.removeEdge(e.id);
        if (r != null) {
          edgeIds.add(r.id);
          _removedEdges[r.id] = r;
        }
      }
    }
    if (removed == null) return null;
    return (node: removed, edgeIds: edgeIds);
  }

  @override
  Future<void> restore(NodeDeletion deletion) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData([...previous, deletion.node]);
    for (final eid in deletion.edgeIds) {
      final edge = _removedEdges[eid];
      if (edge != null) await _edges.restore(edge);
    }
  }
}

/// restore 抛 InkError → 触发 canvas_view 的 undoFailed 兜底提示。
class _RestoreFailNodesController extends _FakeNodesController {
  _RestoreFailNodesController(super.seed);

  @override
  Future<void> restore(NodeDeletion deletion) async {
    throw const LocalIOError();
  }
}

class _MoveFailNodesController extends _FakeNodesController {
  _MoveFailNodesController(super.seed);

  @override
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    throw const LocalIOError();
  }
}

class _FakeEdgesController extends CanvasEdgesController {
  _FakeEdgesController({this.error});
  final InkError? error;
  final List<(String, String)> calls = <(String, String)>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];

  @override
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    int sortOrder = 0,
  }) async {
    calls.add((sourceNodeId, targetNodeId));
    final e = error;
    if (e != null) throw e;
    return CanvasEdge(
      id: 'e1',
      canvasId: arg,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      edgeType: edgeType,
      role: role,
      sortOrder: sortOrder,
    );
  }
}

/// build 抛 InkError → edgesController 落 AsyncError（模拟连线加载失败）。
class _ErrorEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async {
    throw const LocalIOError();
  }
}

/// 节点加载失败 → 画布整屏 _LoadError（GAP-3:文案须走 l10n）。
class _ErrorNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async {
    throw const LocalIOError();
  }
}

/// 泳道恒空且不触 PG，隔离测试只让边失败。
class _EmptyLanesController extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => const <StyleLane>[];
}

class _StubResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('${Directory.systemTemp.path}'
          '${Platform.pathSeparator}__inkframe_missing__'
          '${Platform.pathSeparator}$relativePath');

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot(
          {required String projectId, required String canvasId}) =>
      Directory('${Directory.systemTemp.path}'
          '${Platform.pathSeparator}__inkframe_missing__');
}

CanvasNode _textNode(String id, String label, double x) => CanvasNode(
      id: id,
      label: label,
      type: CanvasNodeType.text,
      canvasId: 'c1',
      position: Offset(x, 40),
      size: const Size(180, 120),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
  InkError? edgeError,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasView()),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      canvasNodesControllerProvider
          .overrideWith(() => _FakeNodesController(nodes)),
      canvasEdgesControllerProvider
          .overrideWith(() => _FakeEdgesController(error: edgeError)),
      fileResolverServiceProvider.overrideWithValue(_StubResolver()),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(CanvasView)),
  );
}

void main() {
  final twoNodes = <CanvasNode>[
    _textNode('a', 'Node A', 40),
    _textNode('b', 'Node B', 320),
  ];

  testWidgets('点击节点 → 单选；再点另一节点 → 替换选择', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await tester.tap(find.text('Node A'));
    await tester.pump();
    expect(container.read(canvasSelectionControllerProvider), {'a'});

    await tester.tap(find.text('Node B'));
    await tester.pump();
    expect(container.read(canvasSelectionControllerProvider), {'b'});
  });

  testWidgets('Shift 多选 → 两个节点都选中 + 计数 chip 显示', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await tester.tap(find.text('Node A'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Node B'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(container.read(canvasSelectionControllerProvider), {'a', 'b'});
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('link 模式点击目标节点 → 创建连线 + Link created', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(linkModeControllerProvider.notifier).start('a');
    await tester.pump();
    // link 模式 banner 出现。
    expect(
      find.text('Tap a target node to link, or tap empty space to cancel'),
      findsOneWidget,
    );

    await tester.tap(find.text('Node B'));
    await tester.pumpAndSettle();

    expect(find.text('Link created'), findsOneWidget);
    expect(container.read(linkModeControllerProvider), isNull);
  });

  testWidgets('link 模式点击源节点自身 → Cannot link a node to itself',
      (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(linkModeControllerProvider.notifier).start('a');
    await tester.pump();

    await tester.tap(find.text('Node A'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot link a node to itself'), findsOneWidget);
    expect(container.read(linkModeControllerProvider), isNull);
  });

  testWidgets('db_code 23505 → Link already exists', (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      edgeError: const LocalIOError(extra: {'db_code': '23505'}),
    );
    container.read(linkModeControllerProvider.notifier).start('a');
    await tester.pump();

    await tester.tap(find.text('Node B'));
    await tester.pumpAndSettle();

    expect(find.text('Link already exists'), findsOneWidget);
  });

  testWidgets('其他 InkError → Failed to create link（不再误报已存在，ME-08）',
      (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      edgeError: const LocalIOError(extra: {'db_code': '23503'}),
    );
    container.read(linkModeControllerProvider.notifier).start('a');
    await tester.pump();

    await tester.tap(find.text('Node B'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create link'), findsOneWidget);
    expect(find.text('Link already exists'), findsNothing);
  });

  testWidgets('拖拽落点 moveNode 失败 → SnackBar 提示（不再静默吞错）', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasView()),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        canvasNodesControllerProvider
            .overrideWith(() => _MoveFailNodesController(twoNodes)),
        canvasEdgesControllerProvider
            .overrideWith(() => _FakeEdgesController()),
        fileResolverServiceProvider.overrideWithValue(_StubResolver()),
      ],
    );
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Node A')));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Failed to move node'), findsOneWidget);
  });

  testWidgets('泳道方向加载失败 → 非阻塞错误横幅（GAP-3 余量:此前静默回落 horizontal）',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasView()),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        canvasNodesControllerProvider
            .overrideWith(() => _FakeNodesController(twoNodes)),
        canvasEdgesControllerProvider
            .overrideWith(() => _FakeEdgesController()),
        canvasLanesControllerProvider.overrideWith(() => _EmptyLanesController()),
        canvasLaneDirectionProvider('c1').overrideWith(
          (_) async => throw const LocalIOError(),
        ),
        fileResolverServiceProvider.overrideWithValue(_StubResolver()),
      ],
    );
    await tester.pumpAndSettle();

    // 非阻塞：节点照常渲染；方向失败有横幅提示。
    expect(find.byType(NodeCard), findsNWidgets(2));
    expect(find.byType(InkErrorBanner), findsOneWidget);
    expect(
      find.text('Local disk I/O error. Check space and permissions.'),
      findsOneWidget,
    );
  });

  testWidgets('节点加载失败 → _LoadError 走 l10n 文案而非 raw toString（GAP-3）',
      (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasView()),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        canvasNodesControllerProvider
            .overrideWith(() => _ErrorNodesController()),
        fileResolverServiceProvider.overrideWithValue(_StubResolver()),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Local disk I/O error. Check space and permissions.'),
      findsOneWidget,
    );
    // raw toString 绝不上屏——InkError.toString() = 'InkError(local_io_error, …)'
    expect(find.textContaining('InkError('), findsNothing);
    expect(find.textContaining('local_io_error'), findsNothing);
  });

  testWidgets('边加载失败 → 非阻塞错误横幅，节点照常渲染；可关闭', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasView()),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
        canvasNodesControllerProvider
            .overrideWith(() => _FakeNodesController(twoNodes)),
        canvasEdgesControllerProvider.overrideWith(() => _ErrorEdgesController()),
        canvasLanesControllerProvider.overrideWith(() => _EmptyLanesController()),
        fileResolverServiceProvider.overrideWithValue(_StubResolver()),
      ],
    );
    await tester.pumpAndSettle();

    // 非阻塞：两个节点仍渲染。
    expect(find.byType(NodeCard), findsNWidgets(2));
    expect(find.text('Node A'), findsOneWidget);
    // 边失败横幅出现（走 l10nError 文案）。
    expect(find.byType(InkErrorBanner), findsOneWidget);
    expect(
      find.text('Local disk I/O error. Check space and permissions.'),
      findsOneWidget,
    );

    // 关闭横幅 → 消失，节点仍在。
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InkErrorBanner), findsNothing);
    expect(find.byType(NodeCard), findsNWidgets(2));
  });

  testWidgets('video result 节点文件缺失 → 不开 lightbox，走常规选中', (tester) async {
    const video = CanvasNode(
      id: 'v',
      label: 'Video R',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: 'c1',
      sourceNodeId: 'a',
      typeConfig: {'video_url': 'videos/missing.mp4'},
      position: Offset(40, 40),
      size: Size(180, 120),
    );
    final container = await _pump(tester, nodes: [video]);

    await tester.tap(find.byType(NodeCard));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(container.read(canvasSelectionControllerProvider), {'v'});
  });

  group('PL-4a 删除防误伤（Deleted · Undo）', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      required CanvasNodesController nodes,
      required CanvasEdgesController edges,
    }) async {
      await pumpInkApp(
        tester,
        const Scaffold(body: CanvasView()),
        overrides: <Override>[
          currentCanvasIdProvider.overrideWith((ref) => 'c1'),
          canvasNodesControllerProvider.overrideWith(() => nodes),
          canvasEdgesControllerProvider.overrideWith(() => edges),
          // 泳道恒空且不触 PG，避免加载失败横幅混入额外 close 图标。
          canvasLanesControllerProvider.overrideWith(() => _EmptyLanesController()),
          // 方向同理密封（GAP-3 后 _EdgeLaneErrorSlot 也 watch 它）。
          canvasLaneDirectionProvider('c1').overrideWith(
            (_) async => LaneDirection.horizontal,
          ),
          fileResolverServiceProvider.overrideWithValue(_StubResolver()),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('删除节点 → 弹出 Deleted · Undo snackbar', (tester) async {
      final fakeNodes = _FakeNodesController(twoNodes);
      await pumpWith(tester,
          nodes: fakeNodes, edges: _FakeEdgesController());

      await tester.tap(find.text('Node A'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete node'));
      await tester.pumpAndSettle();

      expect(find.text('Node deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('点 Undo → 调用 controller.restore，节点回到 state', (tester) async {
      final fakeNodes = _FakeNodesController(twoNodes);
      await pumpWith(tester,
          nodes: fakeNodes, edges: _FakeEdgesController());

      await tester.tap(find.text('Node A'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete node'));
      await tester.pumpAndSettle();
      expect(find.byType(NodeCard), findsOneWidget); // 仅剩 B

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(fakeNodes.restoreCalls, hasLength(1));
      expect(fakeNodes.restoreCalls.first.node.id, 'a');
      expect(find.byType(NodeCard), findsNWidgets(2)); // A 复原
    });

    testWidgets('不点 Undo → 不 restore，软删生效', (tester) async {
      final fakeNodes = _FakeNodesController(twoNodes);
      await pumpWith(tester,
          nodes: fakeNodes, edges: _FakeEdgesController());

      await tester.tap(find.text('Node A'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete node'));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);

      // 不点 Undo：restore 永不触发，软删生效（节点保持删除）。
      expect(fakeNodes.restoreCalls, isEmpty);
      expect(find.byType(NodeCard), findsOneWidget); // 仅剩 B，A 保持删除
    });

    testWidgets('删除连线 → Deleted · Undo；点 Undo → 调用 restore', (tester) async {
      const edge = CanvasEdge(
        id: 'e1',
        canvasId: 'c1',
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: EdgeType.data,
      );
      final fakeEdges = _SeededEdgesController(const <CanvasEdge>[edge]);
      await pumpWith(tester,
          nodes: _FakeNodesController(twoNodes), edges: fakeEdges);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CanvasView)),
      );

      // 选中连线 → 中点浮出删除按钮。
      container.read(selectedEdgeControllerProvider.notifier).select('e1');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Link deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(fakeEdges.restoreCalls, hasLength(1));
      expect(fakeEdges.restoreCalls.first.id, 'e1');
    });

    testWidgets('删除有边节点 → Undo 同时复原节点与其级联边', (tester) async {
      const edge = CanvasEdge(
        id: 'e1',
        canvasId: 'c1',
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: EdgeType.data,
      );
      final fakeEdges = _SeededEdgesController(const <CanvasEdge>[edge]);
      final fakeNodes = _CascadeNodesController(twoNodes, fakeEdges);
      await pumpWith(tester, nodes: fakeNodes, edges: fakeEdges);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CanvasView)),
      );

      await tester.tap(find.text('Node A'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete node'));
      await tester.pumpAndSettle();

      // 删后：节点 A 与级联边 e1 都不在。
      expect(find.byType(NodeCard), findsOneWidget);
      expect(container.read(canvasEdgesControllerProvider('c1')).valueOrNull,
          isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Undo 后：节点 A 与级联边 e1 都复原。
      expect(find.byType(NodeCard), findsNWidgets(2));
      final edges =
          container.read(canvasEdgesControllerProvider('c1')).valueOrNull;
      expect(edges, hasLength(1));
      expect(edges!.first.id, 'e1');
    });

    testWidgets('restore 抛 InkError → 显示 undoFailed 提示', (tester) async {
      final fakeNodes = _RestoreFailNodesController(twoNodes);
      await pumpWith(tester,
          nodes: fakeNodes, edges: _FakeEdgesController());

      await tester.tap(find.text('Node A'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete node'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't undo"), findsOneWidget);
    });
  });
}
