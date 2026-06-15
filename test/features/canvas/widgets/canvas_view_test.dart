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
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/test_app.dart';

class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this._seed);
  final List<CanvasNode> _seed;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<void> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData(
      previous.where((n) => n.id != id).toList(growable: false),
    );
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

class _StubResolver implements FileResolverService {
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
}
