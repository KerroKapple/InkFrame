// 适应视口的纯函数（viewport_fit.dart）：缩放夹紧、只缩小不放大、留白、空集，以及泳道里的卡片按缩放之后
// 真正画出来的位置去框（包围盒随缩放变）。
//
// 变异对照：拿掉「不超过 1」（cap 换成 kCanvasMaxScale）⇒「只缩小、不放大」红；拿掉最小缩放夹紧 ⇒「夹在最小
// 缩放」红；fitArea 不扣留白 ⇒「留白」红；transformFittingScaledRect 只拿上限那一档的包围盒算缩放（不随缩放
// 重算）⇒「泳道里的卡片」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/viewport_fit.dart';
import 'package:inkframe/features/canvas/util/viewport_focus.dart';

/// 顶 64、底 48、左右各 24 的留白（与画布的 kCanvasFitInsets 同形）。
const EdgeInsets _insets = EdgeInsets.fromLTRB(24, 64, 24, 48);
const Size _viewport = Size(1000, 700);

/// 可用区域：x 24..976（宽 952），y 64..652（高 588）。
const Rect _area = Rect.fromLTRB(24, 64, 976, 652);

/// 舞台矩形经相机落到视口里的矩形。
Rect _onScreen(Matrix4 camera, Rect stage) => MatrixUtils.transformRect(camera, stage);

/// [r] 整个落在 [_area] 里（容差 0.5px：二分的精度远小于它）。
bool _inArea(Rect r) =>
    r.left >= _area.left - 0.5 &&
    r.top >= _area.top - 0.5 &&
    r.right <= _area.right + 0.5 &&
    r.bottom <= _area.bottom + 0.5;

CanvasNode _card(String id, Offset position, {String? laneId}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.text,
      canvasId: 'c1',
      laneId: laneId,
      position: position,
    );

/// 卡片在相机 [camera] 下真正画在视口哪里（与卡片 Positioned 同源：nodeStageRect + 相机）。
Rect _cardOnScreen(
  Matrix4 camera,
  CanvasNode node,
  List<({String id, double size})> lanes,
) =>
    _onScreen(
      camera,
      nodeStageRect(
        node: node,
        lanes: lanes,
        direction: LaneDirection.horizontal,
        transform: camera,
      ),
    );

void main() {
  group('fitArea', () {
    test('视口扣掉留白', () {
      expect(fitArea(_viewport, _insets), _area);
    });

    test('视口还没量出来 / 扣完没地方了 ⇒ null', () {
      expect(fitArea(Size.zero, _insets), isNull);
      expect(fitArea(const Size(40, 100), _insets), isNull);
    });
  });

  group('transformFittingRect', () {
    test('矩形比可用区域大：缩到刚好放得下（取更紧的那一边），并居中', () {
      // 2000 × 1000：宽要缩到 952 / 2000 = 0.476，高只要 588 / 1000 = 0.588——取 0.476。
      const Rect stage = Rect.fromLTWH(50000, 50000, 2000, 1000);
      final Matrix4 m = transformFittingRect(
        stageRect: stage,
        viewportSize: _viewport,
        insets: _insets,
      )!;
      expect(scaleOf(m), closeTo(0.476, 1e-9));
      final Rect r = _onScreen(m, stage);
      expect(r.left, closeTo(_area.left, 1e-6));
      expect(r.right, closeTo(_area.right, 1e-6));
      expect(r.center.dy, closeTo(_area.center.dy, 1e-6), reason: '另一个方向居中');
    });

    test('只缩小、不放大：一张卡那么小的矩形保持 100%，居中在可用区域里', () {
      const Rect stage = Rect.fromLTWH(50040, 50040, 224, 191);
      final Matrix4 m = transformFittingRect(
        stageRect: stage,
        viewportSize: _viewport,
        insets: _insets,
      )!;
      expect(scaleOf(m), 1.0, reason: '放得下就不缩，更不放大');
      final Offset center = _onScreen(m, stage).center;
      expect(center.dx, closeTo(_area.center.dx, 1e-6));
      expect(center.dy, closeTo(_area.center.dy, 1e-6));
    });

    test('缩放夹在最小缩放：最小缩放也放不下时用最小缩放，仍居中', () {
      const Rect stage = Rect.fromLTWH(0, 0, 90000, 90000);
      final Matrix4 m = transformFittingRect(
        stageRect: stage,
        viewportSize: _viewport,
        insets: _insets,
      )!;
      expect(scaleOf(m), kCanvasMinScale);
      final Offset center = _onScreen(m, stage).center;
      expect(center.dx, closeTo(_area.center.dx, 1e-6));
      expect(center.dy, closeTo(_area.center.dy, 1e-6));
    });

    test('留白：内容不进顶部让出的那一条（工具条）与底部那一截（缩放条）', () {
      // 又高又窄：高度是更紧的那一边，正好贴满上下留白之间。
      const Rect stage = Rect.fromLTWH(50000, 50000, 300, 2000);
      final Rect r = _onScreen(
        transformFittingRect(stageRect: stage, viewportSize: _viewport, insets: _insets)!,
        stage,
      );
      expect(r.top, closeTo(_insets.top, 1e-6));
      expect(r.bottom, closeTo(_viewport.height - _insets.bottom, 1e-6));
    });

    test('视口还没量出来 ⇒ null（调用方不动相机）', () {
      expect(
        transformFittingRect(
          stageRect: const Rect.fromLTWH(0, 0, 10, 10),
          viewportSize: Size.zero,
          insets: _insets,
        ),
        isNull,
      );
    });
  });

  group('transformFittingNodes', () {
    test('空集 ⇒ null', () {
      expect(
        transformFittingNodes(
          nodes: const <CanvasNode>[],
          lanes: const <({String id, double size})>[],
          direction: LaneDirection.horizontal,
          viewportSize: _viewport,
          insets: _insets,
        ),
        isNull,
      );
    });

    test('不在泳道里的卡片：缩完之后每一张都落在可用区域里，且贴满更紧的那一边', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _card('a', const Offset(40, 40)),
        _card('far', const Offset(3000, 1800)),
        _card('west', const Offset(-1500, -900)),
      ];
      const List<({String id, double size})> noLanes = <({String id, double size})>[];
      final Matrix4 m = transformFittingNodes(
        nodes: nodes,
        lanes: noLanes,
        direction: LaneDirection.horizontal,
        viewportSize: _viewport,
        insets: _insets,
      )!;
      expect(scaleOf(m), lessThan(1.0));
      final List<Rect> drawn = <Rect>[
        for (final CanvasNode n in nodes) _cardOnScreen(m, n, noLanes),
      ];
      for (final Rect r in drawn) {
        expect(_inArea(r), isTrue, reason: '$r 应在 $_area 里');
      }
      final Rect bounds = drawn.reduce((Rect a, Rect b) => a.expandToInclude(b));
      expect(
        (bounds.width - _area.width).abs() < 0.5 || (bounds.height - _area.height).abs() < 0.5,
        isTrue,
        reason: '缩放取的是放得下的最大一档：至少一边贴满',
      );
    });

    // 两条横向泳道（各 400 厚）：泳道里的卡片以本道起始边为锚缩放，第二条道里的卡缩小之后会往下挪
    // （分道位移 = 起始边 × (1 − s) / s）。按 100% 时的包围盒算出来的缩放，缩完它就掉出视口底边。
    test('泳道里的卡片：按缩放之后真正画出来的位置框——每一张都在可用区域里，且竖向贴满', () {
      const List<({String id, double size})> lanes = <({String id, double size})>[
        (id: 'lane-a', size: 400),
        (id: 'lane-b', size: 400),
      ];
      final List<CanvasNode> nodes = <CanvasNode>[
        _card('top', const Offset(0, -1500)),
        _card('in-a', const Offset(300, 100), laneId: 'lane-a'),
        _card('in-b', const Offset(0, 500), laneId: 'lane-b'),
      ];
      final Matrix4 m = transformFittingNodes(
        nodes: nodes,
        lanes: lanes,
        direction: LaneDirection.horizontal,
        viewportSize: _viewport,
        insets: _insets,
      )!;
      expect(scaleOf(m), lessThan(1.0), reason: '前提：要缩小，分道位移才不为零');
      expect(scaleOf(m), greaterThan(kCanvasMinScale), reason: '前提：没被夹到最小缩放');
      final List<Rect> drawn = <Rect>[
        for (final CanvasNode n in nodes) _cardOnScreen(m, n, lanes),
      ];
      for (final Rect r in drawn) {
        expect(_inArea(r), isTrue, reason: '$r 应在 $_area 里');
      }
      final Rect bounds = drawn.reduce((Rect a, Rect b) => a.expandToInclude(b));
      expect(bounds.height, closeTo(_area.height, 0.5), reason: '竖向是更紧的那一边：放得下的最大一档');
    });
  });
}
