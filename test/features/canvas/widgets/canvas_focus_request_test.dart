// 挂起的定位请求在画布上落地（canvas_focus_request.dart + stage/stage_overlays.dart 的 PendingFocusApplier）。
//
// 跨画布定位时目标画布是切过去才挂上来的，在切换那一刻直接写它的选中会被 autoDispose 回收——
// 请求挂起，画布节点载入、视口上报尺寸之后帧后落地：单选 + 移到视口中心，并消费掉请求。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_focus_request.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/test_app.dart';

/// 一张近处卡片 + 一张远在视口之外的卡片（落地前它离视口中心很远）。
final List<CanvasNode> _nodes = <CanvasNode>[
  textNode('near', 'Near', 40),
  const CanvasNode(
    id: 'far',
    label: 'Far',
    type: CanvasNodeType.text,
    canvasId: 'c1',
    position: Offset(2400, 1600),
    size: Size(180, 120),
  ),
];

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasView()),
    overrides: <Override>[
      shellControllerProvider
          .overrideWith(() => ShellNavigator(initial: const ShellState(canvasId: 'c1'))),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
    surfaceSize: const Size(1000, 700),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

void main() {
  test('请求 / 消费：新请求覆盖旧的；消费只清自己那一条', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    final CanvasFocusRequestController ctrl = c.read(canvasFocusRequestProvider.notifier);
    const CanvasFocusRequest first = CanvasFocusRequest(canvasId: 'c1', nodeId: 'a');
    const CanvasFocusRequest second = CanvasFocusRequest(canvasId: 'c2', nodeId: 'b');

    ctrl.request(canvasId: 'c1', nodeId: 'a');
    expect(c.read(canvasFocusRequestProvider), first);

    ctrl.request(canvasId: 'c2', nodeId: 'b');
    // 帧后才落地的旧请求，不得把期间新挂的那条清掉。
    ctrl.consume(first);
    expect(c.read(canvasFocusRequestProvider), second);

    ctrl.consume(second);
    expect(c.read(canvasFocusRequestProvider), isNull);
  });

  testWidgets('本画布的请求：帧后单选 + 移到视口中心，并消费掉', (tester) async {
    final ProviderContainer c = await _pump(tester);
    final Finder card = find.byKey(const ValueKey<String>('node-card-far'));
    final Offset stage = tester.getCenter(find.byType(CanvasView));
    expect((tester.getCenter(card) - stage).distance, greaterThan(500),
        reason: '前置：远处那张一开始离视口中心很远');

    c.read(canvasFocusRequestProvider.notifier).request(canvasId: 'c1', nodeId: 'far');
    await tester.pump();
    await tester.pump();

    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'far'});
    expect(c.read(canvasFocusRequestProvider), isNull, reason: '落地后请求被消费');
    final Offset center = tester.getCenter(card);
    expect(center.dx, closeTo(stage.dx, 1));
    expect(center.dy, closeTo(stage.dy, 1));
  });

  testWidgets('center: false：只单选，不挪相机（新建菜单建出来的节点就在用户刚点的地方）', (tester) async {
    final ProviderContainer c = await _pump(tester);
    final InteractiveViewer viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final Matrix4 before = viewer.transformationController!.value.clone();

    c.read(canvasFocusRequestProvider.notifier).request(canvasId: 'c1', nodeId: 'far', center: false);
    await tester.pump();
    await tester.pump();

    expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'far'});
    expect(c.read(canvasFocusRequestProvider), isNull);
    expect(viewer.transformationController!.value, before, reason: '相机原地不动');
  });

  testWidgets('别的画布的请求：本画布不动它，留给那张画布挂上来后落地', (tester) async {
    final ProviderContainer c = await _pump(tester);
    c.read(canvasFocusRequestProvider.notifier).request(canvasId: 'c2', nodeId: 'x');
    await tester.pump();
    await tester.pump();

    expect(c.read(canvasFocusRequestProvider),
        const CanvasFocusRequest(canvasId: 'c2', nodeId: 'x'));
    expect(c.read(canvasSelectionControllerProvider('c1')), isEmpty);
  });

  testWidgets('请求的节点不在本画布（已删）：只消费、不选中', (tester) async {
    final ProviderContainer c = await _pump(tester);
    c.read(canvasFocusRequestProvider.notifier).request(canvasId: 'c1', nodeId: 'gone');
    await tester.pump();
    await tester.pump();

    expect(c.read(canvasFocusRequestProvider), isNull);
    expect(c.read(canvasSelectionControllerProvider('c1')), isEmpty);
  });
}
