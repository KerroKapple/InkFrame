// 落点换算（util/drop_placement.dart）。
//
// 新建菜单的落点 = 新卡片的左上角画在菜单锚点上：落进泳道时按拖卡片落点同一套判定（resolveLaneDrop）
// 换到那条道的锚定——不管相机怎么缩放平移、落没落进道，卡片画出来的左上角都在锚点上。「画出来」与
// canvas_view 同源：displacedNodes 给舞台坐标（世界 + 舞台原点 + 分道位移），再过相机。
// 另钉「舞台上一点落在哪张卡上」按绘制顺序取最上面那张（拖线落点判「连线还是开菜单」靠它）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/drop_placement.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lane_pin_geometry.dart';
import 'package:inkframe/theme/tokens.dart';

typedef _Slices = List<({String id, double size})>;

const _Slices _noLanes = <({String id, double size})>[];

/// 相机：缩放 [s]，世界原点画在视口的 [origin] 上（screen = s · stage + t）。
Matrix4 _camera(double s, Offset origin) => Matrix4.identity()
  ..translateByDouble(
    origin.dx - s * kStageHalf,
    origin.dy - s * kStageHalf,
    0.0,
    1.0,
  )
  ..scaleByDouble(s, s, 1.0, 1.0);

/// 卡片左上角画在视口里的哪一点（与 canvas_view 的渲染同源）。
Offset _drawnTopLeft(
  CanvasNode node,
  Matrix4 m,
  _Slices lanes,
  LaneDirection direction,
) {
  final CanvasNode drawn = displacedNodes(
    nodes: <CanvasNode>[node],
    lanes: lanes,
    direction: direction,
    transform: m,
  ).single;
  return MatrixUtils.transformPoint(m, drawn.position);
}

CanvasNode _placed(NodePlacement p) => CanvasNode(
      id: 'n',
      label: 'n',
      type: CanvasNodeType.image,
      position: p.world,
      laneId: p.laneId,
    );

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-4));
  expect(actual.dy, closeTo(expected.dy, 1e-4));
}

void main() {
  group('createNodePlacement', () {
    test('初始相机、没有泳道：世界坐标 = 视口坐标 − 让出的工具条那一条', () {
      final NodePlacement p = createNodePlacement(
        viewportPoint: const Offset(300, 200),
        transform: initialCanvasTransform(),
        laneSlices: _noLanes,
        direction: LaneDirection.horizontal,
      );
      expect(p.laneId, isNull);
      _expectOffset(p.world, const Offset(300, 200 - InkToolbarSize.stageTopInset));
    });

    test('缩放 + 平移过的相机：不在道里的卡片画出来左上角就在锚点上', () {
      final Matrix4 m = _camera(0.5, const Offset(137, 91));
      const Offset at = Offset(420, 310);
      final NodePlacement p = createNodePlacement(
        viewportPoint: at,
        transform: m,
        laneSlices: _noLanes,
        direction: LaneDirection.horizontal,
      );
      expect(p.laneId, isNull);
      _expectOffset(
        _drawnTopLeft(_placed(p), m, _noLanes, LaneDirection.horizontal),
        at,
      );
    });

    test('横向泳道：卡片中心落在哪条道就归哪条道，画出来左上角仍在锚点上', () {
      final Matrix4 m = _camera(0.5, const Offset(0, 64));
      const _Slices lanes = <({String id, double size})>[
        (id: 'a', size: 300.0),
        (id: 'b', size: 400.0),
      ];
      // 泳道栈锚在世界原点：a 在视口 y [64, 364)，b 在 [364, 764)。卡片半高 × 0.5 ≈ 48，
      // 锚点 y = 400 ⇒ 卡片中心在 y ≈ 448，落在 b。
      const Offset at = Offset(250, 400);
      final NodePlacement p = createNodePlacement(
        viewportPoint: at,
        transform: m,
        laneSlices: lanes,
        direction: LaneDirection.horizontal,
      );
      expect(p.laneId, 'b');
      _expectOffset(
        _drawnTopLeft(_placed(p), m, lanes, LaneDirection.horizontal),
        at,
      );
    });

    test('竖向泳道：同一套判定换到横轴上', () {
      final Matrix4 m = _camera(1.5, const Offset(40, 0));
      const _Slices lanes = <({String id, double size})>[
        (id: 'a', size: 250.0),
        (id: 'b', size: 250.0),
      ];
      // 泳道栈锚在世界原点：a 在视口 x [40, 290)，b 在 [290, 540)。卡片半宽 × 1.5 = 168，
      // 锚点 x = 200 ⇒ 卡片中心在 x = 368，落在 b。
      const Offset at = Offset(200, 120);
      final NodePlacement p = createNodePlacement(
        viewportPoint: at,
        transform: m,
        laneSlices: lanes,
        direction: LaneDirection.vertical,
      );
      expect(p.laneId, 'b');
      _expectOffset(
        _drawnTopLeft(_placed(p), m, lanes, LaneDirection.vertical),
        at,
      );
    });

    test('卡片中心落在所有道之外：不归道，按全局变换落', () {
      final Matrix4 m = _camera(1, const Offset(0, 64));
      const _Slices lanes = <({String id, double size})>[(id: 'a', size: 200.0)];
      // a 在视口 y [64, 264)；锚点 y = 600 远在下面。
      const Offset at = Offset(100, 600);
      final NodePlacement p = createNodePlacement(
        viewportPoint: at,
        transform: m,
        laneSlices: lanes,
        direction: LaneDirection.horizontal,
      );
      expect(p.laneId, isNull);
      _expectOffset(p.world, const Offset(100, 600 - 64));
    });
  });

  group('resolveLaneDrop（拖卡片落点与新建菜单落点共用）', () {
    const _Slices lanes = <({String id, double size})>[
      (id: 'a', size: 300.0),
      (id: 'b', size: 200.0),
    ];

    test('道里落回同一条道：横截坐标原样', () {
      // 屏幕 = 300 + 0.5 × (400 − 300) = 350 ⇒ b；逆回去还是 400。
      final ({String? laneId, double crossWorld}) drop = resolveLaneDrop(
        centerCrossWorld: 400,
        fromLaneId: 'b',
        laneSlices: lanes,
        direction: LaneDirection.horizontal,
        scale: 0.5,
      );
      expect(drop.laneId, 'b');
      expect(drop.crossWorld, closeTo(400, 1e-9));
    });

    test('从道里拖出所有道：不归道，换成全局变换下的世界坐标（屏幕位置不变）', () {
      // 屏幕 = 300 + 0.5 × (1000 − 300) = 650 ⇒ 不在任何道（栈厚 500）⇒ 全局：650 / 0.5 = 1300。
      final ({String? laneId, double crossWorld}) drop = resolveLaneDrop(
        centerCrossWorld: 1000,
        fromLaneId: 'b',
        laneSlices: lanes,
        direction: LaneDirection.horizontal,
        scale: 0.5,
      );
      expect(drop.laneId, isNull);
      expect(drop.crossWorld, closeTo(1300, 1e-9));
    });

    test('从不在道里拖进一条道：按那条道的锚定换算', () {
      // 屏幕 = 0.5 × 700 = 350 ⇒ b；b 的锚定：300 + (350 − 300) / 0.5 = 400。
      final ({String? laneId, double crossWorld}) drop = resolveLaneDrop(
        centerCrossWorld: 700,
        fromLaneId: null,
        laneSlices: lanes,
        direction: LaneDirection.horizontal,
        scale: 0.5,
      );
      expect(drop.laneId, 'b');
      expect(drop.crossWorld, closeTo(400, 1e-9));
    });
  });

  test('viewportToWorld：初始相机下 = 视口坐标 − 让出的工具条那一条', () {
    _expectOffset(
      viewportToWorld(const Offset(10, 100), initialCanvasTransform()),
      const Offset(10, 100 - InkToolbarSize.stageTopInset),
    );
  });

  group('topmostNodeAt', () {
    CanvasNode card(String id, Offset at) =>
        CanvasNode(id: id, label: id, type: CanvasNodeType.text, position: at);
    final List<CanvasNode> drawn = <CanvasNode>[
      card('under', Offset.zero),
      card('over', const Offset(100, 50)),
    ];

    test('两张重叠：取后画的（压在上面的）那张', () {
      expect(topmostNodeAt(point: const Offset(150, 100), drawn: drawn), 'over');
    });

    test('只压着一张就是它；哪张都不压着 ⇒ null', () {
      expect(topmostNodeAt(point: const Offset(20, 20), drawn: drawn), 'under');
      expect(topmostNodeAt(point: const Offset(900, 900), drawn: drawn), isNull);
    });

    test('命中区就是 kNodeCardSize：右缘本身不算在内（与卡片盒的命中同一个口径）', () {
      final List<CanvasNode> one = <CanvasNode>[card('a', Offset.zero)];
      expect(
        topmostNodeAt(point: Offset(kNodeCardSize.width - 0.5, 10), drawn: one),
        'a',
      );
      expect(
        topmostNodeAt(point: Offset(kNodeCardSize.width, 10), drawn: one),
        isNull,
      );
    });
  });
}
