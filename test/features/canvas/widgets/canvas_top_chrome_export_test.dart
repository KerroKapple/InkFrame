// CanvasTopChrome —— 「导出视频」入口：按钮存在性 + 无 video result 时禁用。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
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

CanvasNode _videoResult(String id, {String? canvasId = 'c1'}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: canvasId,
      sourceNodeId: 'cfg-$id',
      typeConfig: const <String, Object?>{'video_url': 'videos/a.mp4'},
    );

Future<void> _pump(WidgetTester tester, List<CanvasNode> nodes) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      canvasNodesControllerProvider.overrideWith(
        () => _FakeNodesController(nodes),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

IconButton _exportButton(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.movie_outlined),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  testWidgets('有 video result 节点 → 导出按钮可用', (tester) async {
    await _pump(tester, <CanvasNode>[_videoResult('n1')]);

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(_exportButton(tester).onPressed, isNotNull);
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byIcon(Icons.movie_outlined),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'Export video',
    );
  });

  testWidgets('无 video result（仅 config / 无 videoUrl）→ 按钮禁用 + 说明 tooltip',
      (tester) async {
    await _pump(tester, <CanvasNode>[
      const CanvasNode(
        id: 'cfg1',
        label: 'cfg1',
        type: CanvasNodeType.video,
        canvasId: 'c1',
      ),
      const CanvasNode(
        id: 'r-nourl',
        label: 'r-nourl',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        canvasId: 'c1',
        sourceNodeId: 'cfg1',
      ),
    ]);

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(_exportButton(tester).onPressed, isNull);
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byIcon(Icons.movie_outlined),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'No video results on this canvas yet',
    );
  });

  testWidgets('按压时过滤：缺 canvasId 的节点不进对话框（与 controller 过滤一致）', (tester) async {
    await _pump(tester, <CanvasNode>[
      _videoResult('kept-node'),
      _videoResult('dropped-node', canvasId: null),
    ]);

    expect(_exportButton(tester).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.movie_outlined));
    // DragToMoveArea 的 onDoubleTap 把单击识别延迟 kDoubleTapTimeout(300ms)。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Export video'), findsOneWidget);
    expect(find.text('kept-node'), findsOneWidget);
    expect(find.text('dropped-node'), findsNothing);
  });

  testWidgets('canvasId 为 null → 不渲染导出按钮', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.movie_outlined), findsNothing);
  });
}
