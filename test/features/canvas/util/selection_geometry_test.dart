// 选区几何（util/selection_geometry.dart）：框选命中 + 框选结果合并 + 选区包围盒。
//
// 命中口径（Selection Q1 → A）：碰到即算——只碰到一角、恰好贴边（交集面积 0）都算，离开 1px 不算。
// 卡片矩形按渲染位置算（世界 + kStageOrigin + 分道位移），折叠道里的卡不参与命中也不计入包围盒。
// 数据：卡片 kNodeCardSize = 224×191，舞台原点 kStageOrigin = (50000, 50000)，横向泳道 L1 厚 400、L2 厚 300。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/selection_geometry.dart';

typedef _Slices = List<({String id, double size})>;

const _Slices _lanes = <({String id, double size})>[
  (id: 'L1', size: 400),
  (id: 'L2', size: 300),
];

CanvasNode _node(
  String id,
  Offset world, {
  String? laneId,
  CanvasNodeType type = CanvasNodeType.image,
  NodeRole role = NodeRole.config,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      role: role,
      position: world,
      laneId: laneId,
    );

/// 舞台坐标的框：两个角都相对 kStageOrigin 给（Rect.fromPoints 会规范化，起点可在右下）。
Rect _box(Offset a, Offset b) =>
    Rect.fromPoints(kStageOrigin + a, kStageOrigin + b);

Set<String> _hits(
  Rect box,
  List<CanvasNode> nodes, {
  Matrix4? transform,
  Set<String> collapsed = const <String>{},
}) =>
    marqueeHits(
      stageRect: box,
      nodes: nodes,
      lanes: _lanes,
      direction: LaneDirection.horizontal,
      transform: transform ?? Matrix4.identity(),
      collapsedLaneIds: collapsed,
    );

void main() {
  // 无道卡 a：世界 (0,0) ⇒ 舞台矩形 kStageOrigin + (0,0)…(224,191)。
  final CanvasNode a = _node('a', Offset.zero);
  final double right = kNodeCardSize.width;
  final double bottom = kNodeCardSize.height;

  group('marqueeHits', () {
    test('整张框住：命中', () {
      expect(
        _hits(_box(const Offset(-10, -10), const Offset(300, 300)), <CanvasNode>[a]),
        {'a'},
      );
    });

    test('只碰到一角也算（Q1-A）', () {
      // 卡右下角往外 1px 起、往里 5px 止的小框——只盖住右下角那一小块。
      final Rect box = _box(
        Offset(right + 1, bottom + 1),
        Offset(right - 5, bottom - 5),
      );
      expect(_hits(box, <CanvasNode>[a]), {'a'});
    });

    test('恰好贴着边（交集面积 0）也算', () {
      final Rect box = _box(Offset(right, 50), Offset(right + 80, 100));
      expect(box.left, kStageOrigin.dx + right);
      expect(_hits(box, <CanvasNode>[a]), {'a'});
    });

    test('宽为 0 的框贴着边照样按闭区间判', () {
      final Rect box = _box(Offset(right, 50), Offset(right, 100));
      expect(box.width, 0);
      expect(_hits(box, <CanvasNode>[a]), {'a'});
    });

    test('离开 1px 不算', () {
      final Rect box = _box(Offset(right + 1, 50), Offset(right + 80, 100));
      expect(_hits(box, <CanvasNode>[a]), isEmpty);
    });

    test('折叠道里的卡不命中', () {
      final CanvasNode b = _node('b', const Offset(1000, 0), laneId: 'L1');
      final Rect box = _box(const Offset(900, -50), const Offset(1400, 350));
      expect(_hits(box, <CanvasNode>[b], collapsed: {'L1'}), isEmpty);
      expect(_hits(box, <CanvasNode>[b]), {'b'});
    });

    test('laneId 指向已不存在的道的卡按无道卡算', () {
      final CanvasNode g = _node('g', Offset.zero, laneId: 'gone');
      final Matrix4 half = Matrix4.diagonal3Values(0.5, 0.5, 1);
      expect(
        _hits(_box(const Offset(10, 10), const Offset(20, 20)), <CanvasNode>[g],
            transform: half),
        {'g'},
      );
    });

    test('泳道里的卡按分道位移后的位置命中（缩放 0.5）', () {
      // c 在 L2（起始边 400）、世界 (0,0)；缩放 0.5 时分道位移 = (400 · 0.5) / 0.5 = 400（纵向）。
      final CanvasNode c = _node('c', Offset.zero, laneId: 'L2');
      final Matrix4 half = Matrix4.diagonal3Values(0.5, 0.5, 1);
      expect(
        _hits(_box(const Offset(10, 410), const Offset(20, 420)), <CanvasNode>[c],
            transform: half),
        {'c'},
      );
      expect(
        _hits(_box(const Offset(10, 10), const Offset(20, 20)), <CanvasNode>[c],
            transform: half),
        isEmpty,
      );
    });

    test('节点类型不影响命中', () {
      final CanvasNode text =
          _node('t', Offset.zero, type: CanvasNodeType.text);
      final CanvasNode image = _node('i', const Offset(300, 0));
      final CanvasNode result = _node(
        'r',
        const Offset(600, 0),
        role: NodeRole.result,
      );
      expect(
        _hits(
          _box(const Offset(-10, -10), const Offset(900, 300)),
          <CanvasNode>[text, image, result],
        ),
        {'t', 'i', 'r'},
      );
    });
  });

  group('applyMarquee', () {
    test('replace / add / invert 三种', () {
      const Set<String> before = {'a', 'b'};
      const Set<String> hits = {'b', 'c'};
      expect(applyMarquee(before, hits, MarqueeMode.replace), {'b', 'c'});
      expect(applyMarquee(before, hits, MarqueeMode.add), {'a', 'b', 'c'});
      expect(applyMarquee(before, hits, MarqueeMode.invert), {'a', 'c'});
      // 不改入参。
      expect(before, {'a', 'b'});
      expect(hits, {'b', 'c'});
    });

    test('before 为空时 add、invert 都等于 hits', () {
      const Set<String> hits = {'b', 'c'};
      expect(applyMarquee(<String>{}, hits, MarqueeMode.add), {'b', 'c'});
      expect(applyMarquee(<String>{}, hits, MarqueeMode.invert), {'b', 'c'});
    });

    test('replace 返回新集合，不是 hits 本身', () {
      const Set<String> hits = {'b'};
      expect(identical(applyMarquee({'a'}, hits, MarqueeMode.replace), hits), isFalse);
    });
  });

  group('selectionBounds', () {
    Rect? bounds(
      Set<String> ids,
      List<CanvasNode> nodes, {
      Set<String> collapsed = const <String>{},
    }) =>
        selectionBounds(
          ids: ids,
          nodes: nodes,
          lanes: _lanes,
          direction: LaneDirection.horizontal,
          transform: Matrix4.identity(),
          collapsedLaneIds: collapsed,
        );

    test('两张卡的并集矩形', () {
      final CanvasNode d = _node('d', const Offset(500, 100));
      final Rect? r = bounds({'a', 'd'}, <CanvasNode>[a, d]);
      expect(r, isNotNull);
      expect(r!.topLeft, kStageOrigin);
      expect(r.bottomRight, kStageOrigin + const Offset(724, 291));
    });

    test('跳过不存在的 id 与折叠道里的卡；全被跳过返回 null', () {
      // b 在折叠的 L1 里、离 a 很远：算进去的话包围盒会被撑到 b 那边。
      final CanvasNode b = _node('b', const Offset(1000, 0), laneId: 'L1');
      final List<CanvasNode> nodes = <CanvasNode>[a, b];

      final Rect? r = bounds({'a', 'b', 'ghost'}, nodes, collapsed: {'L1'});
      expect(r, kStageOrigin & kNodeCardSize);

      expect(bounds({'b', 'ghost'}, nodes, collapsed: {'L1'}), isNull);
      expect(bounds(<String>{}, nodes), isNull);
    });
  });
}
