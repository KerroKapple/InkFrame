// 框选（Selection 稿「框选与加减选 · 选择工具下在空白处拖」）接到画布上：
//
//   - 鼠标左键拖空白 = 框选（碰到就算），相机不动；拖到一半出框与「已选 N」，松手框收起、选中保留。
//   - Shift 拖 = 加选；Ctrl（mac 用 ⌘）拖 = 反选；拖到一半按修饰键立即生效。
//   - Esc：收框并恢复按下前的选中，再按一次才清空；收框后继续拖 / 松手什么都不变。指针被取消同 Esc。
//   - 挪动不到 4px 松手 = 点空白（清空选中 / 点中连线）；抬起时才报出挪动（move 被合并）按一次完整框选算。
//   - 连线模式、平移工具 / 按住空格、右键拖、中键拖、触摸拖：都不起框，拖的是画布；右键单击照常开菜单。
//   - 折叠道里的卡框不中；泳道底色上起拖也是框选，标题栏上起拖不是。
//   - 贴边自动平移：指针停在视口右缘内，相机一帧帧往右看，视口外的卡被框进来。
//   - 双击空白仍开新建菜单。
//
// 变异对照（派工单「变异点」）：
//   1 识别器阈值 kMarqueeClickSlop 改 0 ⇒「移动 3px 松手」红（松手前无框那句）
//   2 识别器不在按下时 resolve(accepted) ⇒「框住 a、b」红（先挪 3px，InteractiveViewer 过了它的 2px 平移阈值先抢走）
//   3 去掉 kind == mouse ⇒「触摸单指拖空白」红
//   4 去掉 buttons == kPrimaryButton ⇒「右键拖空白」红
//   5 StageMarqueeDetector.enabled 恒 true ⇒「连线模式下拖空白」红
//   6 点的回调直接调 onEmptyTap ⇒「点在连线上」红
//   7 marqueeModeFor 在 mac 上把 control 当反选 / 删掉 meta 判断 ⇒「mac：⌘ 拖框」红
//   8 MarqueeLayer 不监听键盘 ⇒「拖到一半按下 Shift」红
//   9 cancel 不恢复 before ⇒「Esc」红（另有 providers/canvas_marquee_test）
//  10 Esc 档登记成 selection / 不登记 ⇒「Esc」红（再按 Esc 才清空那句）
//  11 收框后 update 又起框 ⇒「Esc」红（继续移动 / 松手那句）
//  12 marqueeHits 不传 collapsedLaneIds ⇒「折叠道里的卡框不中」红
//  13 自动平移 Ticker 不启动 ⇒「贴边自动平移」红
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/edge_hit_test.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/viewport_focus.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/features/canvas/widgets/marquee_layer.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

// 卡片（命中矩形一律是 kNodeCardSize 224×191）。初始相机把世界原点放在视口 (0, 64)：
// 都往右下偏 100，左上外 20px 起拖还在视口里。
const CanvasNode _a = CanvasNode(
  id: 'a',
  label: 'Node A',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(100, 100),
);
const CanvasNode _b = CanvasNode(
  id: 'b',
  label: 'Node B',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(400, 100),
);
const CanvasNode _c = CanvasNode(
  id: 'c',
  label: 'Node C',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(400, 500),
);

/// 泳道 L1 里的卡（L1 折叠时看不见）。
const CanvasNode _d = CanvasNode(
  id: 'd',
  label: 'Node D',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  laneId: 'L1',
  position: Offset(700, 100),
);

/// 视口（1200 宽）右外侧的卡：贴边自动平移才框得进来。
const CanvasNode _e = CanvasNode(
  id: 'e',
  label: 'Node E',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(1300, 100),
);

const List<CanvasNode> _abc = <CanvasNode>[_a, _b, _c];

/// 两条横向泳道（从世界原点起，各厚 400）。
const List<StyleLane> _twoLanes = <StyleLane>[
  StyleLane(id: 'L1', canvasId: 'c1', label: 'L1', size: 400),
  StyleLane(id: 'L2', canvasId: 'c1', label: 'L2', size: 400, sortOrder: 1),
];

class _Lanes extends CanvasLanesController {
  _Lanes(this.seed);
  final List<StyleLane> seed;

  @override
  Future<List<StyleLane>> build(String canvasId) async => seed;

  /// 标题栏拖动落下时的重排请求；测试里不写库，只记下来。
  static final List<List<String>> reorderCalls = <List<String>>[];

  @override
  Future<void> reorderLanes(List<String> orderedIds) async {
    reorderCalls.add(orderedIds);
  }
}

class _Edges extends CanvasEdgesController {
  _Edges(this.seed);
  final List<CanvasEdge> seed;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => seed;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = _abc,
  List<StyleLane> lanes = const <StyleLane>[],
  List<CanvasEdge> edges = const <CanvasEdge>[],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(isActive: true, child: CanvasView())),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: 'c1')),
      ),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges)),
      canvasLanesControllerProvider.overrideWith(() => _Lanes(lanes)),
      canvasLaneDirectionProvider('c1')
          .overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 800),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

Matrix4 _camera(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .clone();

/// 舞台坐标 → 屏幕（全局）坐标：过当前相机。
Offset _stageToScreen(WidgetTester tester, Offset stage) =>
    tester.getTopLeft(find.byType(InteractiveViewer)) +
    MatrixUtils.transformPoint(_camera(tester), stage);

/// 世界坐标 → 屏幕（全局）坐标（无道的卡 / 缩放 1 时与卡片画出来的位置一致）。
Offset _screen(WidgetTester tester, Offset world) =>
    _stageToScreen(tester, world + kStageOrigin);

Set<String> _selection(ProviderContainer c) =>
    c.read(canvasSelectionControllerProvider('c1'));

void _select(ProviderContainer c, Set<String> ids) =>
    c.read(canvasSelectionControllerProvider('c1').notifier).replace(ids);

final Finder _frame = find.byKey(MarqueeLayer.frameKey);

Finder _inMarquee(String text) =>
    find.descendant(of: find.byType(MarqueeLayer), matching: find.text(text));

/// 从 [from] 往 [to] 方向挪 3px 的那一点：先过 InteractiveViewer 的鼠标平移阈值（2px）、不到框选阈值（4px）。
/// 识别器若不在按下时就胜出，InteractiveViewer 在这一步就把手势抢走了。
Offset _nudge(Offset from, Offset to) {
  final Offset d = to - from;
  return from + d / d.distance * 3;
}

/// 鼠标在 [from] 按下（[buttons]），先挪 3px、再经中点到 [to]；[beforeRelease] 在松手前跑，然后松手。
Future<void> _mouseDrag(
  WidgetTester tester,
  Offset from,
  Offset to, {
  int buttons = kPrimaryMouseButton,
  Future<void> Function()? beforeRelease,
}) async {
  final TestGesture g = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await g.moveTo(_nudge(from, to));
  await g.moveTo(Offset.lerp(from, to, 0.5)!);
  await g.moveTo(to);
  await tester.pump();
  if (beforeRelease != null) await beforeRelease();
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

/// 鼠标左键在 [from] 按下、挪到 [to]，不松手。
Future<TestGesture> _mouseHold(WidgetTester tester, Offset from, Offset to) async {
  final TestGesture g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  addTearDown(g.removePointer);
  await g.moveTo(_nudge(from, to));
  await g.moveTo(to);
  await tester.pump();
  return g;
}

void main() {
  testWidgets('左键拖空白框住 a、b：两张被选中，相机不动', (tester) async {
    final ProviderContainer c = await _pump(tester);
    final Matrix4 before = _camera(tester);

    await _mouseDrag(
      tester,
      _screen(tester, const Offset(80, 80)), // a 左上外 20px
      _screen(tester, const Offset(450, 150)), // b 右下内侧
    );

    expect(_selection(c), <String>{'a', 'b'});
    expect(_camera(tester), before, reason: '左键拖空白是框选，不再拖画布');
  });

  testWidgets('拖动中出框与「已选 2」；松手框消失、选中保留', (tester) async {
    final ProviderContainer c = await _pump(tester);
    final TestGesture g = await _mouseHold(
      tester,
      _screen(tester, const Offset(80, 80)),
      _screen(tester, const Offset(450, 150)),
    );

    expect(_frame, findsOneWidget);
    expect(_inMarquee('2 selected'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(MarqueeLayer.chipKey), matching: find.text('2 selected')),
      findsOneWidget,
    );

    await g.up();
    await tester.pump();
    expect(_frame, findsNothing);
    expect(find.byKey(MarqueeLayer.chipKey), findsNothing);
    expect(_selection(c), <String>{'a', 'b'});
  });

  testWidgets('只碰到一角也选中（Q1-A）', (tester) async {
    final ProviderContainer c = await _pump(tester);
    // b = (400..624, 100..291)：框只压住它右下角 4×6 那一小块。
    await _mouseDrag(
      tester,
      _screen(tester, const Offset(700, 330)),
      _screen(tester, const Offset(620, 285)),
    );
    expect(_selection(c), <String>{'b'});
  });

  testWidgets('Shift 拖框 = 加选', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'c'});
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _mouseDrag(
      tester,
      _screen(tester, const Offset(80, 80)),
      _screen(tester, const Offset(150, 150)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(_selection(c), <String>{'a', 'c'});
  });

  testWidgets('Windows：Ctrl 拖框 = 反选', (tester) async {
    final ProviderContainer c = await _pump(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      _select(c, <String>{'a', 'b'});
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      // 框住 b、c（不碰 a）。
      await _mouseDrag(
        tester,
        _screen(tester, const Offset(650, 250)),
        _screen(tester, const Offset(450, 520)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(_selection(c), <String>{'a', 'c'});
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mac：⌘ 拖框 = 反选；Ctrl 不算反选', (tester) async {
    final ProviderContainer c = await _pump(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      _select(c, <String>{'a', 'b'});
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await _mouseDrag(
        tester,
        _screen(tester, const Offset(650, 250)),
        _screen(tester, const Offset(450, 520)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(_selection(c), <String>{'a', 'c'}, reason: 'mac 上 ⌘ 拖框是反选');

      _select(c, <String>{'a', 'b'});
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouseDrag(
        tester,
        _screen(tester, const Offset(650, 250)),
        _screen(tester, const Offset(450, 520)),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(_selection(c), <String>{'b', 'c'}, reason: 'mac 上 Ctrl 不参与：按替换算');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('拖到一半按下 Shift：不动指针也立即变加选', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'c'});
    await tester.pump();

    final TestGesture g = await _mouseHold(
      tester,
      _screen(tester, const Offset(80, 80)),
      _screen(tester, const Offset(150, 150)),
    );
    expect(_selection(c), <String>{'a'}, reason: '前提：不按键 = 替换');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_selection(c), <String>{'a', 'c'}, reason: '按下 Shift 当场变加选，指针没动');
    expect(_inMarquee('2 selected'), findsOneWidget);

    await g.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(_selection(c), <String>{'a', 'c'});
  });

  testWidgets('Esc：框收起，选中恢复成按下前；再按 Esc 才清空', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'c'});
    await tester.pump();

    final TestGesture g = await _mouseHold(
      tester,
      _screen(tester, const Offset(80, 80)),
      _screen(tester, const Offset(150, 150)),
    );
    expect(_selection(c), <String>{'a'}, reason: '前提：框盖住 a');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_selection(c), <String>{'c'}, reason: 'Esc 恢复按下前的选中');
    expect(_frame, findsNothing);

    // 收框之后指针还按着：继续拖不重新起框，松手也不算点。
    await g.moveTo(_screen(tester, const Offset(450, 150)));
    await tester.pump();
    expect(_frame, findsNothing);
    expect(_selection(c), <String>{'c'});
    await g.up();
    await tester.pumpAndSettle();
    expect(_selection(c), <String>{'c'}, reason: '松手不算点空白，不清空');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_selection(c), isEmpty, reason: '再按一次 Esc 才清空选中');
  });

  testWidgets('框选中指针被取消：与 Esc 一样恢复按下前的选中', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'c'});
    await tester.pump();

    final TestGesture g = await _mouseHold(
      tester,
      _screen(tester, const Offset(80, 80)),
      _screen(tester, const Offset(150, 150)),
    );
    expect(_selection(c), <String>{'a'});

    await g.cancel();
    await tester.pump();
    expect(_selection(c), <String>{'c'});
    expect(_frame, findsNothing);
  });

  testWidgets('移动 3px 松手 = 点空白：清空选中', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'a'});
    await tester.pump();
    final Matrix4 before = _camera(tester);

    final TestGesture g = await tester.startGesture(
      _screen(tester, const Offset(900, 600)),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(g.removePointer);
    await g.moveBy(const Offset(3, 0));
    await tester.pump();
    expect(_frame, findsNothing, reason: '没过 4px：还不是框选');

    await g.up();
    await tester.pumpAndSettle();
    expect(_selection(c), isEmpty);
    expect(_camera(tester), before);
  });

  testWidgets('移动 5px 就起框', (tester) async {
    await _pump(tester);
    final TestGesture g = await tester.startGesture(
      _screen(tester, const Offset(900, 600)),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(g.removePointer);
    await g.moveBy(const Offset(5, 0));
    await tester.pump();
    expect(_frame, findsOneWidget);

    await g.up();
    await tester.pumpAndSettle();
    expect(_frame, findsNothing);
  });

  // 主 Agent 决定 2 → A：平台把 move 合并掉，抬起事件直接带着挪出去的位置来——按一次完整框选算，不算点。
  testWidgets('抬起时才报出挪动（move 被合并）：按一次完整框选处理，不算点', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'a'});
    await tester.pump();

    await tester.sendEventToBinding(PointerDownEvent(
      pointer: 71,
      device: 71,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
      position: _screen(tester, const Offset(700, 330)),
    ));
    await tester.sendEventToBinding(PointerUpEvent(
      pointer: 71,
      device: 71,
      kind: PointerDeviceKind.mouse,
      position: _screen(tester, const Offset(620, 285)),
    ));
    await tester.pumpAndSettle();

    expect(_selection(c), <String>{'b'}, reason: '框压住 b 的右下角；按点算的话会清空');
    expect(_frame, findsNothing);
  });

  testWidgets('点在连线上（< 4px）：选中这条连线', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      edges: const <CanvasEdge>[
        CanvasEdge(
          id: 'e1',
          canvasId: 'c1',
          sourceNodeId: 'a',
          targetNodeId: 'b',
          edgeType: EdgeType.data,
        ),
      ],
    );
    final Offset mid = _screen(tester, edgeMidpoint(source: _a, target: _b));

    final TestGesture g = await tester.startGesture(mid, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(1, 0));
    await g.up();
    await g.removePointer();
    await tester.pumpAndSettle();

    expect(c.read(selectedEdgeControllerProvider('c1')), 'e1');
  });

  testWidgets('连线模式下拖空白：不起框', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'b'});
    c.read(linkModeControllerProvider('c1').notifier).start('a');
    await tester.pump();
    final Set<String> before = _selection(c);

    await _mouseDrag(
      tester,
      _screen(tester, const Offset(900, 600)),
      _screen(tester, const Offset(980, 650)),
      beforeRelease: () async => expect(_frame, findsNothing),
    );

    expect(_frame, findsNothing);
    expect(_selection(c), before);
  });

  testWidgets('折叠道里的卡框不中', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      nodes: const <CanvasNode>[_a, _b, _c, _d],
      lanes: _twoLanes,
    );
    final List<({String id, double size})> slices = <({String id, double size})>[
      for (final StyleLane l in _twoLanes) (id: l.id, size: l.size),
    ];

    // d 在 L1 里：L1 是第一条道、从世界原点起，折叠前后它的渲染矩形都一样（缩放 1 时分道位移为 0）。
    Rect dRect(Set<String> collapsed) => nodeStageRect(
          node: _d,
          lanes: collapseLaneSlices(slices, collapsed),
          direction: LaneDirection.horizontal,
          transform: _camera(tester),
        );

    // 对照：没折叠时，同一个框框得中 d——框的几何是对的。
    final Rect open = dRect(const <String>{});
    await _mouseDrag(
      tester,
      _stageToScreen(tester, open.bottomRight + const Offset(30, 60)),
      _stageToScreen(tester, open.center),
    );
    expect(_selection(c), <String>{'d'}, reason: '前提：没折叠时框得中 d');

    c.read(laneCollapseProvider('c1').notifier).toggle('L1');
    await tester.pumpAndSettle();
    final Rect folded = dRect(const <String>{'L1'});
    await _mouseDrag(
      tester,
      _stageToScreen(tester, folded.bottomRight + const Offset(30, 60)),
      _stageToScreen(tester, folded.center),
    );
    expect(_selection(c), isNot(contains('d')), reason: '折叠道里的卡看不见，框不中');
  });

  testWidgets('泳道底色上起拖也是框选；标题栏上起拖仍是拖泳道', (tester) async {
    _Lanes.reorderCalls.clear();
    await _pump(tester, nodes: const <CanvasNode>[_a, _b, _c, _d], lanes: _twoLanes);

    // L1 的底色（世界 y 0..400），不压卡片、不压标题栏。
    await _mouseDrag(
      tester,
      _screen(tester, const Offset(1000, 250)),
      _screen(tester, const Offset(1060, 320)),
      beforeRelease: () async => expect(_frame, findsOneWidget, reason: '底色算空白：起框'),
    );
    expect(_frame, findsNothing);

    final Offset bar = tester.getCenter(find.byType(LaneTitleBar).first);
    await _mouseDrag(
      tester,
      bar,
      bar + const Offset(0, 80),
      beforeRelease: () async => expect(_frame, findsNothing, reason: '标题栏上起拖是拖泳道'),
    );
    expect(_frame, findsNothing);
    expect(_Lanes.reorderCalls, isNotEmpty, reason: '标题栏拖动落下走泳道重排');
  });

  testWidgets('平移工具 / 按住空格时左键拖空白：仍是平移', (tester) async {
    final ProviderContainer c = await _pump(tester);

    c.read(canvasToolModeProvider('c1').notifier).pan();
    await tester.pump();
    Matrix4 before = _camera(tester);
    await _mouseDrag(
      tester,
      _screen(tester, const Offset(900, 600)),
      _screen(tester, const Offset(980, 650)),
      beforeRelease: () async => expect(_frame, findsNothing),
    );
    expect(_camera(tester), isNot(before), reason: '平移工具：拖的是画布');

    c.read(canvasToolModeProvider('c1').notifier).select();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    before = _camera(tester);
    await _mouseDrag(
      tester,
      _screen(tester, const Offset(900, 600)),
      _screen(tester, const Offset(980, 650)),
      beforeRelease: () async => expect(_frame, findsNothing),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_camera(tester), isNot(before), reason: '按住空格：拖的是画布');
  });

  testWidgets('右键拖空白：平移，不开菜单；右键单击：抬起开空白处菜单', (tester) async {
    await _pump(tester);
    final Matrix4 before = _camera(tester);

    await _mouseDrag(
      tester,
      _screen(tester, const Offset(900, 600)),
      _screen(tester, const Offset(980, 650)),
      buttons: kSecondaryMouseButton,
      beforeRelease: () async => expect(_frame, findsNothing),
    );
    expect(_camera(tester), isNot(before), reason: '右键拖 = 平移');
    expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
    expect(_frame, findsNothing);

    await tester.tapAt(
      _screen(tester, const Offset(900, 600)),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(CanvasMenuKeys.blankMenu), findsOneWidget);
  });

  testWidgets('中键拖空白：相机平移、选中不变、不开菜单', (tester) async {
    final ProviderContainer c = await _pump(tester);
    _select(c, <String>{'a'});
    await tester.pump();
    final Matrix4 before = _camera(tester);

    await _mouseDrag(
      tester,
      _screen(tester, const Offset(900, 600)),
      _screen(tester, const Offset(980, 650)),
      buttons: kMiddleMouseButton,
      beforeRelease: () async => expect(_frame, findsNothing),
    );

    expect(_camera(tester), isNot(before), reason: '中键拖 = 平移');
    expect(_selection(c), <String>{'a'});
    expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
    expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
  });

  testWidgets('触摸单指拖空白：仍平移（不起框）', (tester) async {
    await _pump(tester);
    final Matrix4 before = _camera(tester);
    final Offset from = _screen(tester, const Offset(900, 600));

    final TestGesture g = await tester.startGesture(from);
    await g.moveBy(const Offset(3, 0));
    await g.moveBy(const Offset(40, 20));
    await g.moveBy(const Offset(40, 20));
    await tester.pump();
    expect(_frame, findsNothing);
    await g.up();
    await tester.pumpAndSettle();

    expect(_camera(tester), isNot(before), reason: '触摸拖空白 = 平移');
    expect(_frame, findsNothing);
  });

  testWidgets('贴边自动平移：指针停在视口右缘内 4px，相机往右看、视口外的卡 e 被框进来', (tester) async {
    final ProviderContainer c = await _pump(tester, nodes: const <CanvasNode>[_a, _b, _c, _e]);
    final double txBefore = _camera(tester).getTranslation().x;

    final Offset from = _screen(tester, const Offset(700, 350));
    final TestGesture g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    addTearDown(g.removePointer);
    await g.moveTo(_screen(tester, const Offset(1000, 200)));
    // 视口 1200 宽：停在 x = 1196（离右缘 4）。
    final Offset edge = Offset(1196, _screen(tester, const Offset(0, 200)).dy);
    await g.moveTo(edge);
    await tester.pump();
    expect(_selection(c), isNot(contains('e')), reason: '前提：e 还在视口外、没被框到');

    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_camera(tester).getTranslation().x, lessThan(txBefore), reason: '内容往左挪（相机往右看）');
    expect(_selection(c), contains('e'), reason: '框的当前角跟着指针换算进了新露出来的区域');

    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('双击空白仍开新建菜单', (tester) async {
    await _pump(tester);
    final Offset p = _screen(tester, const Offset(900, 600));
    final TestGesture mouse = await tester.startGesture(p, kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.down(p);
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.byKey(CanvasMenuKeys.createMenu), findsOneWidget);
  });
}
