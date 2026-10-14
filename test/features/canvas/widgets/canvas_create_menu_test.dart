// 新建菜单接到画布上（canvas_view / canvas_shortcuts / create_node_menu / canvas_tool_actions）。
//
//   - 从出端口拖线：落在另一张卡上 = 连线（走连线模式那一条 linkTo，image → video 默认首帧）；落在空白处 =
//     在松手点开带上下文的新建菜单，选「当首帧」⇒ 节点落在松手点 + 一条首帧 data 边 + 新节点被单选。
//   - 边写失败：刚建的节点被删掉（不留半截）+ 错误卡；回滚本身也失败：节点留下、被单选 + 错误卡（B10）。
//   - 「下一镜」的叙事边 sortOrder 排在锚点已有的分叉之后（B7）。
//   - 拖线途中 Esc：取消拖线，松手什么都不写。
//   - 拖线途中源卡被删：画布层取消拖线，其余卡片不再显示成连线候选（B5）。
//   - 平移工具开着：端口不可拖（拖的是画布）。
//   - 没选中的卡（端口只在悬停时亮）：按在端口上慢慢往外拖，指针先越出卡片盒——还是拖线，卡片不被拖走（B2）。
//   - 双击空白 / Tab / 空白处右键「新建…」：开的是同一个新建菜单（不带上下文）。
//   - 空白处右键在抬起时开、锚点是按下点；按住右键拖动（拖画布）不开（B4）。
//   - 双击的第一下得是一次单击：拖画布那一下、双指捏合都不算（B3）。
//   - 建节点只有一条路（B9）：I / G / T 与 Tab 菜单里不带上下文的项落在「视口中心 + 散布」、判泳道写 laneId、
//     新节点只单选不挪相机；双击 / 右键「新建…」/ 拖线松手仍落在指定点、不加散布。
//   - 打字时 Tab 不开菜单；焦点在画布里的按钮上，Tab 照常走焦点遍历。
//   - 视频产物源：菜单不出首帧 / 尾帧 / 参考。
//   - 从菜单开的对话框（泳道 / 导入脚本…）一打开就持焦，按键不穿到框后面的画布上（B1）；画布所在的路由上面
//     压着对话框时，画布一概不要焦点（第一层兜底，换一个没有 autofocus 的框照样成立）。
//
// 变异对照：拿掉 addNodeFromMenu 的回滚 ⇒「边写失败」红；拿掉 Esc 里取消拖线那一层 ⇒「拖线途中 Esc」红；
// 把 Tab 的 _CanvasFocusedAction 换成不设门的 Action ⇒「打字时 Tab」「按钮上 Tab」两条红。
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

/// 节点：增删都落在内存态里（新节点要进画布，定位请求才落得了地），并记下建了什么、删了什么。
/// [failRemove] = 删节点写库必失败（记下这次尝试、抛 InkError、内存态不动）。
class _Nodes extends CanvasNodesController {
  _Nodes(this._seed, {this.failRemove = false});
  final List<CanvasNode> _seed;
  final bool failRemove;

  /// addNode 收到的类型、落点与泳道归属，按调用顺序。新节点 id 依次是 new-1、new-2……
  final List<({CanvasNodeType type, Offset position, String? laneId})> added =
      <({CanvasNodeType type, Offset position, String? laneId})>[];

  /// removeNode 收到的 id，按调用顺序。
  final List<String> removed = <String>[];

  /// moveNode 收到的 id（拖卡片的落点），按调用顺序。只记、不改内存态。
  final List<String> moved = <String>[];

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    moved.add(id);
  }

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add((type: type, position: position, laneId: laneId));
    final CanvasNode node = CanvasNode(
      id: 'new-${added.length}',
      label: label,
      type: type,
      role: role,
      canvasId: arg,
      position: position,
    );
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      ...state.valueOrNull ?? const <CanvasNode>[],
      node,
    ]);
    return node;
  }

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    removed.add(id);
    if (failRemove) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'removeNode'});
    }
    final List<CanvasNode> previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? gone;
    for (final CanvasNode n in previous) {
      if (n.id == id) gone = n;
    }
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in previous)
        if (n.id != id) n,
    ]);
    final CanvasNode? node = gone;
    return node == null ? null : (node: node, edgeIds: const <String>[]);
  }
}

/// 连线：起始边集由 [seed] 给；记下建出来的边；[fail] = 写库必失败（真控制器失败时回滚内存再上抛 InkError）。
class _Edges extends CanvasEdgesController {
  _Edges({this.fail = false, this.seed = const <CanvasEdge>[]});
  final bool fail;
  final List<CanvasEdge> seed;
  final List<CanvasEdge> added = <CanvasEdge>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => seed;

  @override
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    EdgeRole Function(List<CanvasEdge> current)? roleResolver,
    int sortOrder = 0,
  }) async {
    if (fail) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'createEdge'});
    }
    final List<CanvasEdge> current = state.valueOrNull ?? const <CanvasEdge>[];
    final CanvasEdge edge = CanvasEdge(
      id: 'e${added.length + 1}',
      canvasId: arg,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      edgeType: edgeType,
      // 与真控制器同口径：解析器在「此刻的边集合」上求值。
      role: roleResolver?.call(current) ?? role,
      sortOrder: sortOrder,
    );
    added.add(edge);
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[...current, edge]);
    return edge;
  }
}

/// 拖线的源（图像配置）与连线的目标（视频配置），并排在舞台左上。
const CanvasNode _img = CanvasNode(
  id: 'img',
  label: 'Shot 01',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  position: Offset(40, 40),
);
const CanvasNode _vid = CanvasNode(
  id: 'vid',
  label: 'Shot 02',
  type: CanvasNodeType.video,
  canvasId: 'c1',
  position: Offset(400, 40),
);

/// 一条从世界原点起、厚 2000 的横向泳道：舞台左上一大片都在道里。
class _OneLane extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async =>
      const <StyleLane>[StyleLane(id: 'lane-1', canvasId: 'c1', label: 'Ink', size: 2000)];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = const <CanvasNode>[_img, _vid],
  List<CanvasEdge> edges = const <CanvasEdge>[],
  bool withLane = false,
  bool failEdges = false,
  bool failRemove = false,
  RecordingToastService? toast,
  Widget Function(Widget canvas)? around,
}) async {
  const Widget canvas = CanvasView();
  await pumpInkApp(
    tester,
    Scaffold(
      body: CanvasShortcuts(
        isActive: true,
        child: around == null ? canvas : around(canvas),
      ),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: 'c1')),
      ),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes, failRemove: failRemove)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(fail: failEdges, seed: edges)),
      canvasLanesControllerProvider
          .overrideWith(() => withLane ? _OneLane() : EmptyLanesController()),
      canvasLaneDirectionProvider('c1')
          .overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(toast ?? RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 800),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

_Nodes _nodesOf(ProviderContainer c) =>
    c.read(canvasNodesControllerProvider('c1').notifier) as _Nodes;

_Edges _edgesOf(ProviderContainer c) =>
    c.read(canvasEdgesControllerProvider('c1').notifier) as _Edges;

Finder _card(String id) => find.byKey(ValueKey<String>('node-card-$id'));

/// 选中源卡片（端口按需显示：选中时两侧端口都亮出来），返回它出端口上的按点。
///
/// 圆点的中心正落在卡片右缘上——那一半在卡片盒外、点不到（命中先按卡片盒筛），所以往里收 3px 按。
Future<Offset> _revealPort(
  WidgetTester tester,
  ProviderContainer c,
  String id,
) async {
  c.read(canvasSelectionControllerProvider('c1').notifier).select(id);
  await tester.pump();
  return tester.getCenter(
        find.descendant(of: _card(id), matching: find.byKey(NodeCard.outPortKey)),
      ) -
      const Offset(3, 0);
}

/// 从 [from] 按下、过触摸阈值、移到 [to]；[beforeRelease] 在松手前跑（按 Esc 之类），然后松手。
Future<void> _dragWire(
  WidgetTester tester,
  Offset from,
  Offset to, {
  Future<void> Function()? beforeRelease,
}) async {
  final TestGesture gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(30, 0));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  if (beforeRelease != null) await beforeRelease();
  await gesture.up();
  await tester.pumpAndSettle();
}

Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

const String _firstFrame = 'First frame · New video';
const String _lastFrame = 'Last frame · New video';
const String _reference = 'Reference · New image';
const String _nextShot = 'Next shot (narrative)';
const List<String> _plainLabels = <String>[
  'Image config',
  'Video config',
  'Text',
  'Shot',
  'Lane',
];

/// 视口 1200 × 800 的中心 (600, 400) 在初始相机下的世界坐标（视口 = 世界 + (0, stageTopInset)）。
const Offset _viewportCenterWorld = Offset(600, 400 - InkToolbarSize.stageTopInset);

/// [topLeft] 那张新卡片的中心落在视口中心的散布范围里（±60，node_position.dart）。
void _expectScatteredAroundViewportCenter(Offset topLeft) {
  final Offset center = topLeft + Offset(kNodeCardSize.width / 2, kNodeCardSize.height / 2);
  expect((center.dx - _viewportCenterWorld.dx).abs(), lessThanOrEqualTo(60), reason: 'x：$center');
  expect((center.dy - _viewportCenterWorld.dy).abs(), lessThanOrEqualTo(60), reason: 'y：$center');
}

/// 从菜单开出来的对话框 [dialog] 拿着键盘（B1）：主焦点在它的输入框里；不点输入框直接按 Backspace / L / Esc——
/// 选中的卡 [selected] 还在、画布没进连线、Esc 关的是对话框、画布选中不变。
///
/// 不用 enterText：它会替我们把焦点给到输入框，正好把「焦点被画布要走」盖住。
Future<void> _expectDialogOwnsKeys(
  WidgetTester tester,
  ProviderContainer c, {
  required Finder dialog,
  required String selected,
}) async {
  expect(dialog, findsOneWidget);
  final Iterable<EditableText> fields = tester.widgetList<EditableText>(
    find.descendant(of: dialog, matching: find.byType(EditableText)),
  );
  expect(
    fields.any((EditableText f) => f.focusNode.hasPrimaryFocus),
    isTrue,
    reason: '主焦点在对话框的输入框里，不在画布上',
  );

  await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
  await tester.pumpAndSettle();
  expect(_nodesOf(c).removed, isEmpty, reason: 'Backspace 不得删掉框后面选中的卡');

  await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
  await tester.pump();
  expect(c.read(linkModeControllerProvider('c1')), isNull, reason: 'L 不得在画布上进连线');

  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(dialog, findsNothing, reason: 'Esc 关的是对话框');
  expect(
    c.read(canvasSelectionControllerProvider('c1')),
    <String>{selected},
    reason: 'Esc 没落到画布上：选中不变',
  );
}

void _expectMenuAt(WidgetTester tester, Key key, Offset at) {
  final Finder menu = find.byKey(key);
  expect(menu, findsOneWidget);
  final Offset topLeft = tester.getTopLeft(menu);
  expect(topLeft.dx, closeTo(at.dx, 0.5));
  expect(topLeft.dy, closeTo(at.dy, 0.5));
}

/// 不带上下文的新建菜单开在 [at]：五项都在，带上下文的项一项没有。
void _expectPlainCreateMenuAt(WidgetTester tester, Offset at) {
  _expectMenuAt(tester, CanvasMenuKeys.createMenu, at);
  final Finder menu = find.byKey(CanvasMenuKeys.createMenu);
  for (final String label in _plainLabels) {
    expect(
      find.descendant(of: menu, matching: find.text(label)),
      findsOneWidget,
      reason: label,
    );
  }
  expect(find.text(_firstFrame), findsNothing);
}

void main() {
  group('从出端口拖线', () {
    testWidgets('拖到另一张卡上：走 linkTo 建出一条边，image → video 默认首帧，出连线成功提示',
        (tester) async {
      final RecordingToastService toast = RecordingToastService();
      final ProviderContainer c = await _pump(tester, toast: toast);
      final Offset grab = await _revealPort(tester, c, 'img');

      await _dragWire(tester, grab, tester.getCenter(_card('vid')));

      final List<CanvasEdge> edges = _edgesOf(c).added;
      expect(edges, hasLength(1));
      expect(edges.single.sourceNodeId, 'img');
      expect(edges.single.targetNodeId, 'vid');
      expect(edges.single.edgeType, EdgeType.data);
      expect(
        edges.single.role,
        EdgeRole.firstFrame,
        reason: '与连线模式同一条 linkTo：image → video 默认首帧',
      );
      expect(toast.titles, <String>['Link created']);
      expect(toast.kinds, <ToastKind>[ToastKind.success]);
      expect(c.read(linkModeControllerProvider('c1')), isNull,
          reason: 'linkTo 收尾时退出连线模式');
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing,
          reason: '落在卡上不开菜单');
      expect(_nodesOf(c).added, isEmpty);
    });

    testWidgets('拖到空白处：新建菜单开在松手点（带上下文）；选「当首帧」⇒ 节点落在松手点 + 首帧 data 边 + 新节点被单选',
        (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Offset grab = await _revealPort(tester, c, 'img');
      const Offset drop = Offset(700, 500);
      final Matrix4 cameraBefore = _ivTransform(tester).clone();

      await _dragWire(tester, grab, drop);

      _expectMenuAt(tester, CanvasMenuKeys.createMenu, drop);
      for (final String label in <String>[_firstFrame, _lastFrame, _reference, _nextShot]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Image config'), findsNothing,
          reason: '带上下文时不出不带上下文的那五项');

      await tester.tap(find.text(_firstFrame));
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added, hasLength(1));
      expect(nodes.added.single.type, CanvasNodeType.video);
      // 初始相机下视口 = 世界 + (0, stageTopInset)：节点左上角落在松手点。
      expect(nodes.added.single.position.dx, closeTo(drop.dx, 0.5));
      expect(
        nodes.added.single.position.dy,
        closeTo(drop.dy - InkToolbarSize.stageTopInset, 0.5),
      );
      final CanvasEdge edge = _edgesOf(c).added.single;
      expect(edge.sourceNodeId, 'img');
      expect(edge.targetNodeId, 'new-1');
      expect(edge.edgeType, EdgeType.data);
      expect(edge.role, EdgeRole.firstFrame);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'},
          reason: '新节点建好后被单选');
      expect(_ivTransform(tester), cameraBefore,
          reason: '新节点就落在松手点：只单选、不挪相机');
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('从产物卡拖到空白选「下一镜」：建来源配置的类型，叙事边从来源配置节点连出', (tester) async {
      const CanvasNode take = CanvasNode(
        id: 'take',
        label: 'Shot 01 take',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        sourceNodeId: 'img',
        canvasId: 'c1',
        position: Offset(40, 320),
        typeConfig: <String, Object?>{'image_url': 'images/take.png'},
      );
      final ProviderContainer c = await _pump(tester, nodes: const <CanvasNode>[_img, _vid, take]);
      final Offset grab = await _revealPort(tester, c, 'take');

      await _dragWire(tester, grab, const Offset(700, 560));
      expect(find.text(_firstFrame), findsOneWidget, reason: '图像产物照样出首帧 / 尾帧 / 参考');
      await tester.tap(find.text(_nextShot));
      await tester.pumpAndSettle();

      expect(_nodesOf(c).added.single.type, CanvasNodeType.image, reason: '与来源配置同类型');
      final CanvasEdge edge = _edgesOf(c).added.single;
      expect(edge.edgeType, EdgeType.narrative);
      expect(edge.sourceNodeId, 'img', reason: '叙事边只连配置节点：从产物的来源配置节点连出');
      expect(edge.targetNodeId, 'new-1');
    });

    testWidgets('落点在泳道里：泳道归属随建节点一次写进去', (tester) async {
      final ProviderContainer c = await _pump(tester, withLane: true);
      final Offset grab = await _revealPort(tester, c, 'img');

      await _dragWire(tester, grab, const Offset(700, 500));
      await tester.tap(find.text(_firstFrame));
      await tester.pumpAndSettle();

      expect(_nodesOf(c).added.single.laneId, 'lane-1');
    });

    testWidgets('拖线途中按 Esc：取消拖线，松手不开菜单、不连线、不建节点', (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Offset grab = await _revealPort(tester, c, 'img');

      await _dragWire(
        tester,
        grab,
        const Offset(700, 500),
        beforeRelease: () async {
          expect(c.read(canvasWireDragProvider('c1')), isNotNull,
              reason: '前置：拖线已经开始');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(c.read(canvasWireDragProvider('c1')), isNull,
              reason: 'Esc 先取消拖线');
        },
      );

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
      expect(_nodesOf(c).added, isEmpty);
      expect(_edgesOf(c).added, isEmpty);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'img'},
          reason: 'Esc 这一下只剥拖线这一层，不清选中');
    });

    // B5：拖线途中源卡被删，源卡的插槽跟着卸载——手势再也回调不到，插槽自己的清理用的 ref 也已不可用。
    // 拖线状态得由知道节点集的画布层收掉，不然虚线与「可连目标」高亮一直挂着。
    testWidgets('拖线途中源卡被删：拖线取消，其余卡片不再显示成连线候选，松手什么都不发生', (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Offset grab = await _revealPort(tester, c, 'img');
      NodeCard vidCard() => tester.widget<NodeCard>(
            find.descendant(of: _card('vid'), matching: find.byType(NodeCard)),
          );

      final TestGesture gesture = await tester.startGesture(grab);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(c.read(canvasWireDragProvider('c1'))?.sourceNodeId, 'img', reason: '前提：拖线已经开始');
      expect(vidCard().isLinkCandidate, isTrue, reason: '前提：拖线期间其余卡片是可连的目标');

      await _nodesOf(c).removeNode('img');
      await tester.pumpAndSettle();

      expect(c.read(canvasWireDragProvider('c1')), isNull, reason: '源卡没了：拖线取消');
      expect(vidCard().isLinkCandidate, isFalse, reason: '其余卡片不再显示成连线候选');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing, reason: '松手不开菜单');
      expect(_edgesOf(c).added, isEmpty, reason: '松手不连线');
    });

    testWidgets('拖线途中按 Esc 之后落在另一张卡上：也不连线', (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Offset grab = await _revealPort(tester, c, 'img');

      await _dragWire(
        tester,
        grab,
        tester.getCenter(_card('vid')),
        beforeRelease: () async {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
        },
      );

      expect(_edgesOf(c).added, isEmpty);
    });

    // B2：没选中的卡，出端口只在悬停时亮。在端口上按下后慢慢往外拖，指针先越出卡片盒、悬停态先掉——端口一拆，
    // 拖线手势跟着拆，接着过阈值的就成了卡片自己的拖动（卡片被拖走、落库）。按下就得把端口钉住。
    testWidgets('没选中的卡：悬停亮出端口，按下后先挪 1.5px 出卡片盒、再拖到 40px 外——还是拖线，卡片没被拖走',
        (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Finder port =
          find.descendant(of: _card('img'), matching: find.byKey(NodeCard.outPortKey));
      expect(port, findsNothing, reason: '前提：没选中、没悬停、没挂线——端口不亮');

      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(_card('img')));
      await tester.pump();
      expect(port, findsOneWidget, reason: '前提：悬停亮出端口');
      expect(c.read(canvasSelectionControllerProvider('c1')), isEmpty);

      // 圆点的中心正在卡片右缘上：往里收 0.5px 按下，再往外挪 1.5px 就越出了卡片盒——
      // 鼠标的拖动阈值是 2px，这一下还没起拖，悬停态却已经掉了。
      final Offset press = tester.getCenter(port) - const Offset(0.5, 0);
      await mouse.moveTo(press);
      await tester.pump();
      await mouse.down(press);
      await tester.pump();
      await mouse.moveBy(const Offset(1.5, 0));
      await tester.pump();
      expect(port, findsOneWidget, reason: '按着端口时端口钉住，悬停态掉了也不收');
      await mouse.moveBy(const Offset(40, 0));
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();

      expect(_nodesOf(c).moved, isEmpty, reason: '拖的是线，不是卡片：不能有 moveNode');
      final CanvasMenuRequest? menu = c.read(canvasMenuRequestProvider('c1'));
      expect(menu?.kind, CanvasMenuKind.create, reason: '拖线落在空白处：开新建菜单');
      expect(menu?.sourceNodeId, 'img', reason: '带着「从哪张卡拖出来」的上下文');
    });

    testWidgets('平移工具开着：端口不可拖——从端口起拖拖的是画布，不起拖线、不开菜单', (tester) async {
      final ProviderContainer c = await _pump(tester);
      final Offset grab = await _revealPort(tester, c, 'img');
      c.read(canvasToolModeProvider('c1').notifier).pan();
      await tester.pump();
      final Matrix4 before = _ivTransform(tester).clone();

      final TestGesture gesture = await tester.startGesture(grab);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(c.read(canvasWireDragProvider('c1')), isNull,
          reason: '平移时端口按不到，起不了拖线');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
      expect(_edgesOf(c).added, isEmpty);
      expect(_ivTransform(tester), isNot(before), reason: '拖的是画布');
    });
  });

  group('新建菜单：建节点与连线', () {
    testWidgets('边写失败：刚建的节点被删掉（不留半截），并弹错误卡', (tester) async {
      final RecordingToastService toast = RecordingToastService();
      final ProviderContainer c =
          await _pump(tester, failEdges: true, toast: toast);
      c
          .read(canvasMenuRequestProvider('c1').notifier)
          .openCreate(const Offset(700, 500), sourceNodeId: 'img');
      await tester.pumpAndSettle();

      await tester.tap(find.text(_firstFrame));
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added, hasLength(1), reason: '先建节点');
      expect(nodes.removed, <String>['new-1'], reason: '边写失败 ⇒ 回滚删掉刚建的节点');
      expect(
        c.read(canvasNodesControllerProvider('c1')).valueOrNull!.map((CanvasNode n) => n.id),
        isNot(contains('new-1')),
      );
      expect(toast.titles, <String>['Failed to add node']);
      expect(toast.kinds, <ToastKind>[ToastKind.error]);
      expect(c.read(canvasSelectionControllerProvider('c1')), isNot(contains('new-1')));
    });

    // B10：回滚本身也失败——节点留在画布上，至少让它被选中（用户看得见、能手动删），照样出错误卡。
    testWidgets('边写失败、回滚也失败：节点留在画布上并被单选（不挪相机），弹错误卡', (tester) async {
      final RecordingToastService toast = RecordingToastService();
      final ProviderContainer c =
          await _pump(tester, failEdges: true, failRemove: true, toast: toast);
      final Matrix4 cameraBefore = _ivTransform(tester).clone();
      c
          .read(canvasMenuRequestProvider('c1').notifier)
          .openCreate(const Offset(700, 500), sourceNodeId: 'img');
      await tester.pumpAndSettle();

      await tester.tap(find.text(_firstFrame));
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added, hasLength(1));
      expect(nodes.removed, <String>['new-1'], reason: '试过回滚');
      expect(
        c.read(canvasNodesControllerProvider('c1')).valueOrNull!.map((CanvasNode n) => n.id),
        contains('new-1'),
        reason: '回滚没成：节点还在',
      );
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'},
          reason: '留下的节点被单选');
      expect(_ivTransform(tester), cameraBefore, reason: '只单选、不挪相机');
      expect(toast.titles, <String>['Failed to add node']);
      expect(toast.kinds, <ToastKind>[ToastKind.error]);
    });

    testWidgets('「下一镜（叙事）」：建与源同类型的配置节点 + 一条 narrative 边（源 → 新）', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c
          .read(canvasMenuRequestProvider('c1').notifier)
          .openCreate(const Offset(700, 500), sourceNodeId: 'img');
      await tester.pumpAndSettle();

      await tester.tap(find.text(_nextShot));
      await tester.pumpAndSettle();

      expect(_nodesOf(c).added.single.type, CanvasNodeType.image);
      final CanvasEdge edge = _edgesOf(c).added.single;
      expect(edge.sourceNodeId, 'img');
      expect(edge.targetNodeId, 'new-1');
      expect(edge.edgeType, EdgeType.narrative);
    });

    // B7：原来「下一镜」不设 sortOrder（默认 0），与锚点已有的叙事分叉同序——谁先谁后落到边 id（UUID）上。
    testWidgets('「下一镜」：锚点已有一条 sortOrder=0 的叙事出边 ⇒ 新边 sortOrder=1，排在已有分支之后',
        (tester) async {
      const CanvasEdge existing = CanvasEdge(
        id: 'n0',
        canvasId: 'c1',
        sourceNodeId: 'img',
        targetNodeId: 'vid',
        edgeType: EdgeType.narrative,
      );
      final ProviderContainer c = await _pump(tester, edges: const <CanvasEdge>[existing]);
      c
          .read(canvasMenuRequestProvider('c1').notifier)
          .openCreate(const Offset(700, 500), sourceNodeId: 'img');
      await tester.pumpAndSettle();

      await tester.tap(find.text(_nextShot));
      await tester.pumpAndSettle();

      final CanvasEdge edge = _edgesOf(c).added.single;
      expect(edge.edgeType, EdgeType.narrative);
      expect(edge.sourceNodeId, 'img');
      expect(edge.sortOrder, 1);
    });

    testWidgets('视频产物源：菜单不出首帧 / 尾帧 / 参考三项', (tester) async {
      const CanvasNode take = CanvasNode(
        id: 'take',
        label: 'Take',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        canvasId: 'c1',
        sourceNodeId: 'vid',
        position: Offset(700, 40),
        typeConfig: <String, Object?>{'video_url': 'take.mp4'},
      );
      final ProviderContainer c =
          await _pump(tester, nodes: const <CanvasNode>[_img, _vid, take]);
      c
          .read(canvasMenuRequestProvider('c1').notifier)
          .openCreate(const Offset(700, 500), sourceNodeId: 'take');
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsOneWidget);
      expect(find.text(_firstFrame), findsNothing);
      expect(find.text(_lastFrame), findsNothing);
      expect(find.text(_reference), findsNothing);
    });

    testWidgets('菜单键盘：↓ ↵ 执行第二项（视频配置），节点落在视口中心（+ 散布，与 G 同一条路）、不连线、被单选',
        (tester) async {
      final ProviderContainer c = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added.single.type, CanvasNodeType.video);
      _expectScatteredAroundViewportCenter(nodes.added.single.position);
      expect(_edgesOf(c).added, isEmpty, reason: '不带上下文：只建节点、不连线');
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'});
    });

    testWidgets('菜单里 Esc：关菜单、什么都不建；焦点回到画布，再按 Tab 又能打开', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
      expect(_nodesOf(c).added, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsOneWidget,
          reason: '焦点回到了画布本身，Tab 又归它');
    });

    testWidgets('点菜单外面：菜单关掉，什么都不建', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsOneWidget);

      await tester.tapAt(const Offset(1000, 700));
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
      expect(_nodesOf(c).added, isEmpty);
    });
  });

  group('三个不带上下文的入口开的是同一个菜单', () {
    testWidgets('双击舞台空白 → 在双击点开新建菜单', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      await tester.tapAt(p);
      await tester.tapAt(p);
      await tester.pumpAndSettle();

      _expectPlainCreateMenuAt(tester, p);
    });

    // B3：自己数的双击原来只看「第二下离第一下按下点多远、隔多久」——拖画布那一下被当成了第一下。
    testWidgets('拖画布之后 300ms 内在原处再按一下：不算双击，不开菜单', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      final TestGesture drag = await tester.startGesture(p);
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tapAt(p);
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing, reason: '拖动不是双击的第一下');
    });

    testWidgets('拖出去又拖回原处再松手，接着在原处按一下：也不算双击（挪出过点击容差就不是单击）', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      final TestGesture drag = await tester.startGesture(p);
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      await drag.moveBy(const Offset(-40, 0));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tapAt(p);
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('一根手指按着不放时，另一根手指在别处点两下：不算双击', (tester) async {
      await _pump(tester);
      final TestGesture rest = await tester.startGesture(const Offset(300, 600));
      await tester.pump();

      await tester.tapAt(const Offset(700, 500));
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing, reason: '另有指针按着时不算');

      await rest.up();
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('双指捏合：第二根手指在第一根旁边落下，不算双击', (tester) async {
      await _pump(tester);
      final TestGesture first = await tester.startGesture(const Offset(700, 500));
      await tester.pump();
      final TestGesture second = await tester.startGesture(const Offset(760, 500));
      await tester.pump();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing, reason: '另有指针按着时不算');

      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('真正的双击（鼠标，两下都在原处抬起）：照常在双击点开新建菜单', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      final TestGesture mouse = await tester.startGesture(p, kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.down(p);
      await mouse.up();
      await tester.pumpAndSettle();

      _expectPlainCreateMenuAt(tester, p);
    });

    testWidgets('单击空白不开菜单：两下隔得比双击窗口久，也不算双击', (tester) async {
      await _pump(tester);
      await tester.tapAt(const Offset(700, 500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('画布持焦按 Tab → 在视口中心开新建菜单', (tester) async {
      await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // 视口 1200 × 800，中心 (600, 400)。
      _expectPlainCreateMenuAt(tester, const Offset(600, 400));
    });

    testWidgets('空白处右键 → 空白处右键菜单（只有四项）；点「新建…」→ 原地换成新建菜单', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      await tester.tapAt(
        p,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      _expectMenuAt(tester, CanvasMenuKeys.blankMenu, p);
      final Finder blank = find.byKey(CanvasMenuKeys.blankMenu);
      for (final String label in <String>['New…', 'Import script…', 'Select all', 'Fit view']) {
        expect(
          find.descendant(of: blank, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('Tab'), findsOneWidget, reason: '「新建…」行尾的键位提示');

      await tester.tap(find.text('New…'));
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
      _expectPlainCreateMenuAt(tester, p);
    });

    // B4：原来右键一按下就开菜单——按住右键拖会把画布拖走，菜单还钉在原处。
    testWidgets('空白处按住右键拖动：不开右键菜单（拖的是画布）', (tester) async {
      await _pump(tester);
      final TestGesture drag = await tester.startGesture(
        const Offset(700, 500),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await drag.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing, reason: '按下 / 拖动时都不开');

      await drag.up();
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing, reason: '挪出了点击容差：抬起也不开');
    });

    testWidgets('空白处按住右键拖出去又拖回原处再松手：也不开（按着时挪出过点击容差就是在拖）', (tester) async {
      await _pump(tester);
      final TestGesture drag = await tester.startGesture(
        const Offset(700, 500),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await drag.moveBy(const Offset(60, 0));
      await tester.pump();
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
    });

    testWidgets('空白处右键单击：抬起时开，锚点是按下的那一点（容差内的手抖不挪锚点）', (tester) async {
      await _pump(tester);
      const Offset p = Offset(700, 500);
      final TestGesture click = await tester.startGesture(
        p,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing, reason: '按下时还不开');

      await click.moveBy(const Offset(0.8, 0));
      await click.up();
      await tester.pumpAndSettle();
      _expectMenuAt(tester, CanvasMenuKeys.blankMenu, p);
    });

    testWidgets('空白处右键菜单「全选」：选中画布上全部节点', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await tester.tapAt(
        const Offset(700, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'img', 'vid'});
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
    });
  });

  // B9：原来菜单项标着 I / G / T，走的却不是这几个键的路——按键路径不判泳道、不选中新节点，菜单路径落在锚点上。
  group('B9：工具条 / 单键 / Tab 菜单同一条建节点路径', () {
    testWidgets('I：视口中心落在泳道里 ⇒ 新节点带 laneId、被单选、相机不动', (tester) async {
      final ProviderContainer c = await _pump(tester, withLane: true);
      final Matrix4 cameraBefore = _ivTransform(tester).clone();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added.single.type, CanvasNodeType.image);
      expect(nodes.added.single.laneId, 'lane-1', reason: '判泳道归属，写 laneId');
      _expectScatteredAroundViewportCenter(nodes.added.single.position);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'},
          reason: '新节点被单选');
      expect(_ivTransform(tester), cameraBefore, reason: '只单选、不挪相机');
    });

    testWidgets('Tab 菜单「图像配置」：与 I 同一条路——落在视口中心 + 散布（不落在菜单锚点上）、判泳道、单选',
        (tester) async {
      final ProviderContainer c = await _pump(tester, withLane: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      _expectPlainCreateMenuAt(tester, const Offset(600, 400));

      await tester.tap(
        find.descendant(
          of: find.byKey(CanvasMenuKeys.createMenu),
          matching: find.text('Image config'),
        ),
      );
      await tester.pumpAndSettle();

      final _Nodes nodes = _nodesOf(c);
      expect(nodes.added.single.type, CanvasNodeType.image);
      _expectScatteredAroundViewportCenter(nodes.added.single.position);
      expect(nodes.added.single.laneId, 'lane-1');
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'});
    });

    testWidgets('双击空白开的菜单：建出来的节点仍落在双击点上（带落点的入口不加散布）', (tester) async {
      final ProviderContainer c = await _pump(tester);
      const Offset p = Offset(700, 500);
      await tester.tapAt(p);
      await tester.tapAt(p);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(CanvasMenuKeys.createMenu),
          matching: find.text('Image config'),
        ),
      );
      await tester.pumpAndSettle();

      final Offset at = _nodesOf(c).added.single.position;
      expect(at.dx, closeTo(p.dx, 0.5));
      expect(at.dy, closeTo(p.dy - InkToolbarSize.stageTopInset, 0.5));
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'});
    });
  });

  group('B1：从菜单开的对话框拿着键盘，按键不穿到框后面的画布上', () {
    testWidgets('Tab 新建菜单 →「泳道」：泳道框一打开就持焦', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('img');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byKey(CanvasMenuKeys.createMenu), matching: find.text('Lane')),
      );
      await tester.pumpAndSettle();
      expect(find.text('New lane'), findsOneWidget, reason: '前提：开的是「新建泳道」框');

      await _expectDialogOwnsKeys(tester, c, dialog: find.byType(Dialog), selected: 'img');
    });

    testWidgets('空白处右键 →「导入脚本…」：导入框一打开就持焦', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('img');
      await tester.pump();
      await tester.tapAt(
        const Offset(700, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(CanvasMenuKeys.blankMenu),
          matching: find.text('Import script…'),
        ),
      );
      await tester.pumpAndSettle();

      await _expectDialogOwnsKeys(
        tester,
        c,
        dialog: find.byType(ScriptImportDialog),
        selected: 'img',
      );
    });

    // 第一层单独钉：照「收菜单时要回焦点 → 开对话框」的时序走一遍，换成一个什么都不 autofocus 的框。以后新加的
    // 对话框入口忘了另外两层（关菜单不还焦点、框里 autofocus），也得靠这一层兜住。
    testWidgets('画布所在的路由上面压着对话框：收菜单的焦点回收与舞台按下的回收都不要焦点', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('img');
      await tester.pump();
      await tester.tapAt(
        const Offset(700, 500),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsOneWidget, reason: '前提：菜单开着、菜单持焦');

      final BuildContext canvas = tester.element(find.byType(CanvasView));
      c.read(canvasMenuRequestProvider('c1').notifier).close();
      CanvasShortcuts.reclaimFocusIfOrphaned(canvas);
      unawaited(
        showDialog<void>(
          context: canvas,
          builder: (BuildContext _) => const AlertDialog(content: Text('bare dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('bare dialog'), findsOneWidget);

      CanvasShortcuts.reclaimFocus(canvas);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(_nodesOf(c).removed, isEmpty, reason: '焦点没被要回画布：Backspace 不删框后面选中的卡');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(c.read(linkModeControllerProvider('c1')), isNull, reason: 'L 不得在画布上进连线');
    });
  });

  group('Tab 只在画布本身持焦时接管', () {
    testWidgets('在文本框里打字时按 Tab：不开新建菜单（文本编辑让位）', (tester) async {
      final TextEditingController field = TextEditingController();
      addTearDown(field.dispose);
      final ProviderContainer c = await _pump(
        tester,
        around: (Widget canvas) => Column(
          children: <Widget>[
            Expanded(child: canvas),
            // 提示词条 / 检查器文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
            TextField(controller: field),
          ],
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();
      expect(isEditingText(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(c.read(canvasMenuRequestProvider('c1')), isNull);
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
    });

    testWidgets('焦点在画布里的按钮上按 Tab：照常走焦点遍历，不开新建菜单', (tester) async {
      final FocusNode first = FocusNode(debugLabel: 'first');
      final FocusNode second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final ProviderContainer c = await _pump(
        tester,
        around: (Widget canvas) => Column(
          children: <Widget>[
            Expanded(child: canvas),
            // 检查器按钮 / 工具条键替身：同处于 CanvasShortcuts 子树内、但不是文本框的可聚焦控件。
            Row(
              children: <Widget>[
                TextButton(focusNode: first, onPressed: () {}, child: const Text('one')),
                TextButton(focusNode: second, onPressed: () {}, child: const Text('two')),
              ],
            ),
          ],
        ),
      );

      first.requestFocus();
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(c.read(canvasMenuRequestProvider('c1')), isNull);
      expect(find.byKey(CanvasMenuKeys.createMenu), findsNothing);
      expect(second.hasPrimaryFocus, isTrue, reason: 'Tab 照常把焦点移到下一个控件');
    });
  });
}
