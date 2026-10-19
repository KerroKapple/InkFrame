// CanvasZoomBar（左下缩放条）：缩小 / 放大画图标集 v1 的 zoomOut / zoomIn（16px），
// 不再是「−」「+」两个字符；图标格有名字（读屏 + tooltip）；点了改缩放。
// 「适应」= 适应全部（PR-8b）：把画布上所有卡片框进视口；画布上没有卡片时回到初始相机。原来它只是复位相机——
// 复位留给 ⌘0。
//
// 变异对照：把「适应」格改回 initialCanvasTransform ⇒「适应 = 适应全部」红；
// 百分比格改回按文字宽（Padding s10 撑开）⇒「缩放条固定宽」红（放大 / 适应两格随比例左右挪）；
// InkToolbarSize.zoomBarPercentCell 改小（如 46 → 20）或百分比字号加大 ⇒ 同一条用例「300% 装得进百分比格」红
// （量的是 RenderParagraph 的自然宽度——Text 默认 clip，溢出不抛异常，takeException 测不出）；
// 条上 + / − 改调 zoomCanvasBy ⇒「缩放条 + / − 不出轻提示胶囊」红。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
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

  testWidgets('缩放条固定宽 kCanvasZoomBarWidth：10% 与 300% 时同宽，后面几格不跟着挪', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final TransformationController transform =
        container.read(canvasTransformControllerProvider(_canvasId));
    expect(kCanvasZoomBarWidth, InkToolbarSize.zoomBarWidth);

    transform.value = Matrix4.diagonal3Values(kCanvasMinScale, kCanvasMinScale, 1);
    await tester.pump();
    expect(find.text('10%'), findsOneWidget);
    final Rect barAt10 = tester.getRect(find.byType(CanvasZoomBar));
    final Rect fitAt10 = tester.getRect(find.text('Fit'));
    final Rect inAt10 = tester.getRect(_glyph(InkGlyph.zoomIn));

    transform.value = Matrix4.diagonal3Values(kCanvasMaxScale, kCanvasMaxScale, 1);
    await tester.pump();
    expect(find.text('300%'), findsOneWidget);
    // 百分比格里的 Text 是 softWrap: false + 默认 clip：字宽超出只会被悄悄裁掉、不抛异常，takeException 看不出来。
    // 直接量字的自然宽度（不受格宽约束），与格宽比。
    final RenderParagraph percent300 = tester.renderObject<RenderParagraph>(find.text('300%'));
    expect(
      percent300.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(InkToolbarSize.zoomBarPercentCell),
      reason: '「300%」装得进百分比格',
    );
    final Rect barAt300 = tester.getRect(find.byType(CanvasZoomBar));

    expect(barAt10.width, kCanvasZoomBarWidth);
    expect(barAt300.width, kCanvasZoomBarWidth);
    // 外面一层定宽框住了整条，还得看里面：百分比格按字宽撑开的话，放大 / 适应两格会跟着左右挪。
    expect(tester.getRect(_glyph(InkGlyph.zoomIn)).left, closeTo(inAt10.left, 0.01));
    expect(tester.getRect(find.text('Fit')).center.dx, closeTo(fitAt10.center.dx, 0.01));
  });

  testWidgets('缩放条 + / − 不出轻提示胶囊（比例就显示在条上）', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final ProviderSubscription<CanvasCapsuleMessage?> capsule =
        container.listen(canvasCapsuleProvider(_canvasId), (_, _) {});
    addTearDown(capsule.close);

    await tester.tap(_glyph(InkGlyph.zoomIn));
    await tester.pump();
    await tester.tap(_glyph(InkGlyph.zoomOut));
    await tester.pump();

    expect(scaleOf(container.read(canvasTransformControllerProvider(_canvasId)).value),
        closeTo(1.0, 1e-9), reason: '前提：真的缩放过（放大一档再缩小一档回到 100%）');
    expect(capsule.read(), isNull);
  });
}
