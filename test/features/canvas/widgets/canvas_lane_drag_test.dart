// 拖卡片换泳道（演示 O2）：canvas_view 的卡片插槽松手 → util/drop_placement.dart 的 resolveCardDrop → moveNode。
//
//   - 误拖：鼠标按下挪几个像素（过了平移阈值、拖动成立），位置照落，归属泳道不变——不在道里但压在道上的卡
//     不会被顺手收进去，道里的卡也不会被换走；不弹提示。
//   - 真拖进另一条道：拖动途中目标道高亮（泳道背景层的 dropTargetLaneId），松手后 moveNode 换道，弹一张撤销卡
//     「Moved into lane “Dusk”」；点「Undo」把卡片挪回原位置、原泳道。
//
// 变异对照：canvas_view 改回直接调 resolveLaneDrop（不过 resolveCardDrop 的闸）⇒「误拖」两条红；
// 拿掉撤销卡 ⇒「真拖」红；拿掉背景层的 dropTargetLaneId 接线 ⇒「真拖」的高亮断言红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

// ===== 夹具 =====

/// 两条横向泳道，各 400 厚：Rain 在上（泳道栈 y 0..400），Dusk 在下（400..800）。初始相机缩放 1。
const List<StyleLane> _lanes = <StyleLane>[
  StyleLane(id: 'lane-1', canvasId: 'c1', label: 'Rain', size: 400),
  StyleLane(id: 'lane-2', canvasId: 'c1', label: 'Dusk', size: 400, sortOrder: 1),
];

/// 不在任何道里、但卡片中心（y 40 + 95.5）压在 Rain 带上的卡——误拖一下最容易被顺手收进 Rain 的那种。
const CanvasNode _free = CanvasNode(
  id: 'free',
  label: 'Loose',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  position: Offset(40, 40),
);

/// Rain 道里的卡，位置同上。
const CanvasNode _laned = CanvasNode(
  id: 'laned',
  label: 'In rain',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  laneId: 'lane-1',
  position: Offset(40, 40),
);

// ===== 假控制器 =====

typedef _Moved = ({String id, Offset delta, String? laneId});

/// 节点：moveNode 落进内存态，并记下收到了什么。
class _Nodes extends CanvasNodesController {
  _Nodes(this._seed);
  final List<CanvasNode> _seed;
  final List<_Moved> moved = <_Moved>[];

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    moved.add((id: id, delta: delta, laneId: laneId));
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in state.valueOrNull ?? const <CanvasNode>[])
        if (n.id == id)
          n.copyWith(position: n.position + delta, laneId: laneId, clearLaneId: laneId == null)
        else
          n,
    ]);
  }
}

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

class _Lanes extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => _lanes;
}

// ===== 装配 =====

Future<ProviderContainer> _pump(WidgetTester tester, CanvasNode node) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(isActive: true, child: CanvasView())),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1'),
        ),
      ),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(<CanvasNode>[node])),
      canvasEdgesControllerProvider.overrideWith(_Edges.new),
      canvasLanesControllerProvider.overrideWith(_Lanes.new),
      canvasLaneDirectionProvider('c1').overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 900),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

_Nodes _nodesOf(ProviderContainer c) =>
    c.read(canvasNodesControllerProvider('c1').notifier) as _Nodes;

RecordingToastService _toastOf(ProviderContainer c) =>
    c.read(toastServiceProvider) as RecordingToastService;

Finder _card(String id) => find.byKey(ValueKey<String>('node-card-$id'));

String? _highlighted(WidgetTester tester) =>
    tester.widget<LaneBackground>(find.byType(LaneBackground)).dropTargetLaneId;

/// 鼠标在 [id] 那张卡的中心按下：先挪 [slop] 过平移阈值（这一截不计入卡片位移），再挪 [delta]。不抬起。
Future<TestGesture> _dragCard(
  WidgetTester tester,
  String id, {
  required Offset slop,
  required Offset delta,
}) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(_card(id)),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(slop);
  await gesture.moveBy(delta);
  await tester.pump();
  return gesture;
}

void _expectMoved(_Moved actual, {required String id, required Offset delta, required String? laneId}) {
  expect(actual.id, id);
  expect(actual.laneId, laneId);
  expect(actual.delta.dx, closeTo(delta.dx, 1e-6));
  expect(actual.delta.dy, closeTo(delta.dy, 1e-6));
}

void main() {
  group('误拖几个像素：位置照落，归属泳道不变', () {
    testWidgets('不在道里但压在 Rain 带上的卡：不会被顺手收进 Rain，不弹提示', (WidgetTester tester) async {
      final ProviderContainer c = await _pump(tester, _free);

      final TestGesture gesture =
          await _dragCard(tester, 'free', slop: const Offset(0, 5), delta: const Offset(1, 3));
      expect(_highlighted(tester), isNull, reason: '不换道，就没有要高亮的目标道');
      await gesture.up();
      await tester.pumpAndSettle();

      final List<_Moved> moved = _nodesOf(c).moved;
      expect(moved, hasLength(1), reason: '拖动成立：位置照落');
      _expectMoved(moved.single, id: 'free', delta: const Offset(1, 3), laneId: null);
      expect(_toastOf(c).shown, isEmpty);
    });

    testWidgets('Rain 道里的卡：轻推还在 Rain，不弹提示', (WidgetTester tester) async {
      final ProviderContainer c = await _pump(tester, _laned);

      final TestGesture gesture =
          await _dragCard(tester, 'laned', slop: const Offset(0, 5), delta: const Offset(0, 3));
      await gesture.up();
      await tester.pumpAndSettle();

      final List<_Moved> moved = _nodesOf(c).moved;
      expect(moved, hasLength(1));
      _expectMoved(moved.single, id: 'laned', delta: const Offset(0, 3), laneId: 'lane-1');
      expect(_toastOf(c).shown, isEmpty);
    });
  });

  testWidgets('真拖进 Dusk：途中 Dusk 高亮，松手换道并弹撤销卡；Undo 挪回原位置、原泳道', (WidgetTester tester) async {
    final ProviderContainer c = await _pump(tester, _laned);

    // 中心 135.5 → 535.5：进了 Dusk（400..800）135 多像素。
    final TestGesture gesture =
        await _dragCard(tester, 'laned', slop: const Offset(0, 10), delta: const Offset(0, 400));
    expect(_highlighted(tester), 'lane-2', reason: '拖动途中松手会换进的那条道亮着');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_highlighted(tester), isNull, reason: '松手后高亮收起');

    final List<_Moved> moved = _nodesOf(c).moved;
    expect(moved, hasLength(1));
    _expectMoved(moved.single, id: 'laned', delta: const Offset(0, 400), laneId: 'lane-2');

    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Moved into lane “Dusk”']);
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
    final ToastAction? undo = toast.shown.single.primary;
    expect(undo?.label, 'Undo');

    undo!.onPressed();
    await tester.pumpAndSettle();

    expect(moved, hasLength(2));
    _expectMoved(moved[1], id: 'laned', delta: const Offset(0, -400), laneId: 'lane-1');
    final CanvasNode back = c
        .read(canvasNodesControllerProvider('c1'))
        .requireValue
        .singleWhere((CanvasNode n) => n.id == 'laned');
    expect(back.position, const Offset(40, 40));
    expect(back.laneId, 'lane-1');
  });
}
