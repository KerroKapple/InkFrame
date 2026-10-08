// 序列视图（P2）：链表行 → 播放头；轨道点 / 拖 → seekGlobal；Ctrl + 滚轮缩放；超长中文不溢出。
// 监视器本身的行为在 sequence_monitor_test.dart；这里只钉视图与播放头 / 缩放态的接线。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/export/delivery_keys.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';
import 'package:inkframe/features/sequence/providers/sequence_zoom.dart';
import 'package:inkframe/features/sequence/widgets/sequence_monitor.dart';
import 'package:inkframe/features/sequence/widgets/sequence_screen.dart';

import '../../../_harness/test_app.dart';

const String _long = '晨雾中的山径光线从左上穿过松林形成丁达尔光束人物背影逐渐清晰镜头缓慢推进直到山脊线被第一缕光切开为止再回望空镜收尾';

class _Nodes extends CanvasNodesController {
  _Nodes(this.nodes);
  final List<CanvasNode> nodes;
  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

class _Edges extends CanvasEdgesController {
  _Edges(this.edges);
  final List<CanvasEdge> edges;
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => edges;
}

CanvasNode _shot(String id, {String? label, int ms = 3000}) => CanvasNode(
      id: id,
      label: label ?? 'shot-$id',
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'shot_notes': 'notes $id', 'duration_ms': ms},
    );

CanvasEdge _narrative(String id, String from, String to) =>
    CanvasEdge(id: id, canvasId: 'c1', sourceNodeId: from, targetNodeId: to, edgeType: EdgeType.narrative);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  bool isVisible = true,
  Size surface = const Size(1280, 800),
}) async {
  await pumpInkApp(
    tester,
    Scaffold(body: SequenceScreen(canvasId: 'c1', projectId: 'p1', isVisible: isVisible)),
    surfaceSize: surface,
    overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges)),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SequenceScreen)));
}

void main() {
  final List<CanvasNode> three = <CanvasNode>[_shot('a', ms: 2000), _shot('b', ms: 1000), _shot('c', ms: 3000)];
  final List<CanvasEdge> chain = <CanvasEdge>[_narrative('e1', 'a', 'b'), _narrative('e2', 'b', 'c')];

  testWidgets('三栏在树：链表三行 + 监视器 + 交付占位；序列区头部计数', (tester) async {
    await _pump(tester, nodes: three, edges: chain);

    for (int i = 0; i < 3; i++) {
      expect(find.byKey(SequenceScreen.chainRowKey(i)), findsOneWidget);
      expect(find.byKey(SequenceScreen.clipKey(i)), findsOneWidget);
    }
    expect(find.byType(SequenceMonitor), findsOneWidget);
    // P6：右栏是真交付面板。本用例没播种项目上下文（ShellState.project == null），
    // 所以面板只剩空态——「不 watch 仓储」那条门控的直接体现。
    expect(find.byKey(DeliveryKeys.panel), findsOneWidget);
    expect(find.byKey(DeliveryKeys.emptyState), findsOneWidget);
    expect(find.text('3 shots · 3 placeholder'), findsOneWidget);
    expect(find.text('Video · 3'), findsOneWidget);
    expect(find.text('00:00:06:00'), findsWidgets, reason: '总长 6s 出现在序列区头 / 监视器');
    expect(tester.takeException(), isNull);
  });

  testWidgets('点链表行 → 播放头 selectShot（token +1），监视器切到该镜', (tester) async {
    final ProviderContainer c = await _pump(tester, nodes: three, edges: chain);

    await tester.tap(find.byKey(SequenceScreen.chainRowKey(2)));
    await tester.pump();
    await tester.pump();

    expect(c.read(sequencePlayheadProvider('c1')), const SequencePlayhead(index: 2, offsetMs: 0, seekToken: 1));
    expect(find.text('notes c'), findsOneWidget);
  });

  testWidgets('点轨道 → 按 34px/s 折算 seekGlobal；只改播放头，不写库（没有仓储可写）', (tester) async {
    final ProviderContainer c = await _pump(tester, nodes: three, edges: chain);

    final Offset origin = tester.getTopLeft(find.byKey(SequenceScreen.tracksKey));
    // x = 85px ⇒ 2.5s ⇒ 第二镜（a 占 0–2s）内偏移 0.5s。
    await tester.tapAt(origin + const Offset(85, 60));
    await tester.pump();

    final SequencePlayhead head = c.read(sequencePlayheadProvider('c1'));
    expect(head.index, 1);
    expect(head.offsetMs, 500);
    expect(head.seekToken, 1, reason: '按下一次 = 一次 seek（抬起不再算一次）');
  });

  testWidgets('拖播放头：横向拖动持续 seek', (tester) async {
    final ProviderContainer c = await _pump(tester, nodes: three, edges: chain);
    final Offset origin = tester.getTopLeft(find.byKey(SequenceScreen.tracksKey));

    final TestGesture g = await tester.startGesture(origin + const Offset(10, 60));
    await g.moveBy(const Offset(60, 0));
    await tester.pump();
    await g.moveBy(const Offset(66, 0));
    await tester.pump();
    await g.up();
    await tester.pump();

    final SequencePlayhead head = c.read(sequencePlayheadProvider('c1'));
    expect(head.index, 2, reason: 'x=136 ⇒ 4.0s ⇒ 第三镜');
    expect(head.seekToken, greaterThanOrEqualTo(2), reason: '每次拖动更新都是一次 seek');
  });

  testWidgets('Ctrl + 滚轮缩放：向上放大、向下缩小、夹在上下限；无 Ctrl 不缩放', (tester) async {
    final ProviderContainer c = await _pump(tester, nodes: three, edges: chain);
    final Offset at = tester.getCenter(find.byKey(SequenceScreen.tracksKey));
    Future<void> scroll(double dy) async {
      final TestPointer p = TestPointer(1, PointerDeviceKind.mouse);
      p.hover(at);
      await tester.sendEventToBinding(p.scroll(Offset(0, dy)));
      await tester.pump();
    }

    await scroll(-120);
    expect(c.read(sequenceZoomProvider('c1')), kSequenceDefaultPxPerSec, reason: '没按 Ctrl 不缩放');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await scroll(-120);
    expect(c.read(sequenceZoomProvider('c1')), closeTo(kSequenceDefaultPxPerSec * kSequenceZoomStep, 0.001));
    await scroll(120);
    expect(c.read(sequenceZoomProvider('c1')), closeTo(kSequenceDefaultPxPerSec, 0.001));
    for (int i = 0; i < 40; i++) {
      await scroll(120);
    }
    expect(c.read(sequenceZoomProvider('c1')), kSequenceMinPxPerSec);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });

  testWidgets('isVisible=false → 监视器 paused', (tester) async {
    await _pump(tester, nodes: three, edges: chain, isVisible: false);
    expect(tester.widget<SequenceMonitor>(find.byType(SequenceMonitor)).paused, isTrue);
  });

  testWidgets('超长中文镜名：链表行 / 片段 / 监视器头 / 标记轨全部单行省略，1280×800 无溢出', (tester) async {
    await _pump(
      tester,
      nodes: <CanvasNode>[_shot('a', label: _long, ms: 6000), _shot('b', label: _long, ms: 1000)],
      edges: <CanvasEdge>[_narrative('e1', 'a', 'b')],
    );
    expect(tester.takeException(), isNull);

    final Finder longTexts = find.byWidgetPredicate((Widget w) => w is Text && (w.data?.contains(_long) ?? false));
    // 链表行 ×2 + 片段 ×1（1s 片段 34 宽只出序号）+ 监视器头 ×1 + 标记 ×2。
    expect(longTexts.evaluate().length, greaterThanOrEqualTo(5));
    final List<String> problems = <String>[];
    for (final Element e in longTexts.evaluate()) {
      final Text t = e.widget as Text;
      if (t.maxLines != 1 || t.overflow != TextOverflow.ellipsis) {
        problems.add('${e.widget.runtimeType}@${e.renderObject?.paintBounds}: maxLines=${t.maxLines} overflow=${t.overflow}');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('960×600（最小窗口）下无溢出', (tester) async {
    await _pump(tester, nodes: three, edges: chain, surface: const Size(960, 600));
    expect(tester.takeException(), isNull);
  });
}
