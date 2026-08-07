// CanvasTopChrome —— 「序列预览」入口（SB-6）：存在性 + 无 narrative 边时禁用。
//
// 门控故意只看**边**不看节点：没有叙事链就没有"序列"可言，而画布上有一堆
// 互不相连的节点是常态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_top_chrome.dart';

import '../../../_harness/test_app.dart';

class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this.nodes);
  final List<CanvasNode> nodes;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

class _FakeEdgesController extends CanvasEdgesController {
  _FakeEdgesController(this.edges);
  final List<CanvasEdge> edges;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => edges;
}

CanvasEdge _edge(String id, EdgeType type) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: 'a',
      targetNodeId: 'b',
      edgeType: type,
    );

const _shot = CanvasNode(
  id: 'a',
  label: 'a',
  type: CanvasNodeType.shot,
  projectId: 'p1',
  canvasId: 'c1',
  typeConfig: <String, Object?>{'shot_notes': 'x'},
);

Future<void> _pump(
  WidgetTester tester, {
  required List<CanvasEdge> edges,
  List<CanvasNode> nodes = const <CanvasNode>[_shot],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      canvasNodesControllerProvider.overrideWith(
        () => _FakeNodesController(nodes),
      ),
      canvasEdgesControllerProvider.overrideWith(
        () => _FakeEdgesController(edges),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

IconButton _button(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.play_circle_outline),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  testWidgets('有 narrative 边 → 序列预览按钮可用', (tester) async {
    await _pump(tester, edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)]);

    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('无边 → 禁用', (tester) async {
    await _pump(tester, edges: const <CanvasEdge>[]);

    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('只有 data / generation_source 边 → 仍禁用（不是叙事链）',
      (tester) async {
    await _pump(tester, edges: <CanvasEdge>[
      _edge('e1', EdgeType.data),
      _edge('e2', EdgeType.generationSource),
    ]);

    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('点击打开序列预览对话框', (tester) async {
    await _pump(tester, edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)]);

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump(); // 起 route 过渡
    await tester.pump(const Duration(milliseconds: 400)); // 过渡走完 + 首帧回调

    // 单个无产物的 shot → 占位文案在场即证明清单构建与对话框都通了。
    expect(find.text('Not generated yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });
}
