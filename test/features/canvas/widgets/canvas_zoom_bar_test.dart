// CanvasZoomBar（左下缩放条）：缩小 / 放大画图标集 v1 的 zoomOut / zoomIn（16px），
// 不再是「−」「+」两个字符；图标格有名字（读屏 + tooltip）；点了改缩放。
// 「适应」= 适应全部（PR-8b）：把画布上所有卡片框进视口；画布上没有卡片时回到初始相机。原来它只是复位相机——
// 复位留给 ⌘0。
//
// 变异对照：把「适应」格改回 initialCanvasTransform ⇒「适应 = 适应全部」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_tool_actions.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/viewport_fit.dart';
import 'package:inkframe/features/canvas/widgets/canvas_zoom_bar.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/test_app.dart';

const String _canvasId = 'c1';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = const <CanvasNode>[],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: Center(child: CanvasZoomBar(canvasId: _canvasId))),
    overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
    ],
  );
  await tester.pump();
  final ProviderContainer container =
      ProviderScope.containerOf(tester.element(find.byType(CanvasZoomBar)));
  // 节点与视口尺寸都是 autoDispose、只在回调里读：这里没有画布替它们订着，测试自己订住。
  final ProviderSubscription<AsyncValue<List<CanvasNode>>> nodesSub =
      container.listen(canvasNodesControllerProvider(_canvasId), (_, _) {});
  final ProviderSubscription<Size> viewportSub =
      container.listen(canvasViewportSizeProvider(_canvasId), (_, _) {});
  addTearDown(nodesSub.close);
  addTearDown(viewportSub.close);
  await tester.pump();
  return container;
}

Finder _glyph(InkGlyph glyph) => find.descendant(
      of: find.byType(CanvasZoomBar),
      matching: find.byWidgetPredicate(
        (Widget w) => w is InkIcon && w.glyph == glyph,
      ),
    );

void main() {
  testWidgets('缩小 / 放大是 zoomOut / zoomIn 图标（16px），不再是字符；图标格有 tooltip',
      (tester) async {
    await _pump(tester);

    expect(_glyph(InkGlyph.zoomOut), findsOneWidget);
    expect(_glyph(InkGlyph.zoomIn), findsOneWidget);
    expect(tester.widget<InkIcon>(_glyph(InkGlyph.zoomOut)).size, InkIconSize.sm);
    expect(tester.widget<InkIcon>(_glyph(InkGlyph.zoomIn)).size, InkIconSize.sm);
    expect(find.text('−'), findsNothing);
    expect(find.text('+'), findsNothing);
    expect(find.text('Fit'), findsOneWidget, reason: '「适应」与百分比读数保留');
    expect(find.text('100%'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
  });

  testWidgets('点放大 → 变大；点缩小 → 变小；画布上没有卡片时点适应 → 回初始相机', (tester) async {
    final ProviderContainer container = await _pump(tester);
    Matrix4 current() =>
        container.read(canvasTransformControllerProvider(_canvasId)).value;

    await tester.tap(_glyph(InkGlyph.zoomIn));
    await tester.pump();
    final double zoomedIn = scaleOf(current());
    expect(zoomedIn, greaterThan(1.0));

    await tester.tap(_glyph(InkGlyph.zoomOut));
    await tester.pump();
    expect(scaleOf(current()), lessThan(zoomedIn));

    await tester.tap(find.text('Fit'));
    await tester.pump();
    expect(current(), initialCanvasTransform());
  });

  testWidgets('适应 = 适应全部：把所有卡片框进视口扣掉留白的那一块（不是复位相机）', (tester) async {
    final List<CanvasNode> nodes = <CanvasNode>[
      textNode('a', 'A', 40),
      const CanvasNode(
        id: 'far',
        label: 'Far',
        type: CanvasNodeType.text,
        canvasId: _canvasId,
        position: Offset(2600, 1700),
      ),
    ];
    final ProviderContainer container = await _pump(tester, nodes: nodes);
    const Size viewport = Size(1000, 700);
    container.read(canvasViewportSizeProvider(_canvasId).notifier).setSize(viewport);
    await tester.pump();

    await tester.tap(find.text('Fit'));
    await tester.pump();

    final Matrix4 fitted =
        container.read(canvasTransformControllerProvider(_canvasId)).value;
    expect(fitted, isNot(initialCanvasTransform()));
    expect(
      fitted,
      transformFittingNodes(
        nodes: nodes,
        lanes: const <({String id, double size})>[],
        direction: LaneDirection.horizontal,
        viewportSize: viewport,
        insets: kCanvasFitInsets,
      ),
    );
    expect(scaleOf(fitted), lessThan(1.0));
  });
}
