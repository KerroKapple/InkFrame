// 节点右键菜单的判据（node_menu_model.dart）：目标集、各项的可用条件、泳道子菜单的打勾与「移出泳道」、
// 加入 / 移出泳道时的位置换算。
//
// 变异对照：拿掉 isGenerableNode 的任一条（配置节点 / image·video / 提示词不空）、generationTarget 的「恰好一张」、
// duplicateSources 的「只要配置节点」、characterSource 的「带图的产物」，对应用例当场红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lane_pin_geometry.dart';
import 'package:inkframe/features/canvas/util/node_menu_model.dart';

CanvasNode _config(
  String id, {
  CanvasNodeType type = CanvasNodeType.image,
  String? prompt = 'boat at dawn',
  String? laneId,
  Offset position = Offset.zero,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      canvasId: 'c1',
      laneId: laneId,
      position: position,
      typeConfig: <String, Object?>{'prompt': ?prompt},
    );

CanvasNode _result(String id, {String? imageUrl, String? videoUrl, String? laneId}) => CanvasNode(
      id: id,
      label: id,
      type: videoUrl != null ? CanvasNodeType.video : CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: 'src',
      canvasId: 'c1',
      laneId: laneId,
      typeConfig: <String, Object?>{
        'image_url': ?imageUrl,
        'video_url': ?videoUrl,
      },
    );

const List<StyleLane> _lanes = <StyleLane>[
  StyleLane(id: 'lane-a', canvasId: 'c1', label: 'Rain', size: 400),
  StyleLane(id: 'lane-b', canvasId: 'c1', label: 'Dusk', size: 400),
];

const List<({String id, double size})> _slices = <({String id, double size})>[
  (id: 'lane-a', size: 400),
  (id: 'lane-b', size: 400),
];

/// 卡片中心在泳道栈坐标里画在哪（横向泳道 = y）。
double _drawnCenter(CanvasNode node, {required double scale}) => crossToScreen(
      laneStart: laneStartOf(node.laneId, _slices),
      world: node.position.dy + kNodeCardSize.height / 2,
      scale: scale,
      crossTranslation: 0,
    );

void main() {
  group('nodeMenuTargets', () {
    test('右键的卡在选中集里 ⇒ 整个选中集', () {
      expect(nodeMenuTargets(<String>{'a', 'b'}, 'a'), <String>{'a', 'b'});
    });

    test('不在选中集里 ⇒ 只有它', () {
      expect(nodeMenuTargets(<String>{'a', 'b'}, 'c'), <String>{'c'});
      expect(nodeMenuTargets(const <String>{}, 'c'), <String>{'c'});
    });
  });

  group('生成', () {
    test('image / video 的配置节点、提示词不空 ⇒ 能生成', () {
      expect(isGenerableNode(_config('i')), isTrue);
      expect(isGenerableNode(_config('v', type: CanvasNodeType.video)), isTrue);
    });

    test('提示词空 / 只有空白 / 没有 ⇒ 不能', () {
      expect(isGenerableNode(_config('i', prompt: '')), isFalse);
      expect(isGenerableNode(_config('i', prompt: '   ')), isFalse);
      expect(isGenerableNode(_config('i', prompt: null)), isFalse);
    });

    test('文本 / 镜头配置节点、产物节点 ⇒ 不能', () {
      expect(isGenerableNode(_config('t', type: CanvasNodeType.text)), isFalse);
      expect(isGenerableNode(_config('s', type: CanvasNodeType.shot)), isFalse);
      final CanvasNode result = _result('r', imageUrl: 'images/r.png');
      expect(
        isGenerableNode(CanvasNode(
          id: result.id,
          label: result.label,
          type: result.type,
          role: NodeRole.result,
          sourceNodeId: 'src',
          typeConfig: const <String, Object?>{'prompt': 'boat', 'image_url': 'images/r.png'},
        )),
        isFalse,
        reason: '产物节点带着提示词也不能生成',
      );
    });

    test('generationTarget：恰好一张且能生成 ⇒ 那一张；两张 / 一张不能生成 / 空 ⇒ null', () {
      final CanvasNode i = _config('i');
      expect(generationTarget(<CanvasNode>[i]), i);
      expect(generationTarget(<CanvasNode>[i, _config('j')]), isNull);
      expect(generationTarget(<CanvasNode>[_config('i', prompt: '')]), isNull);
      expect(generationTarget(const <CanvasNode>[]), isNull);
    });
  });

  group('复制一份', () {
    test('只复制配置节点（产物不复制），顺序照旧', () {
      final CanvasNode i = _config('i');
      final CanvasNode t = _config('t', type: CanvasNodeType.text);
      final CanvasNode r = _result('r', imageUrl: 'images/r.png');
      expect(duplicateSources(<CanvasNode>[i, r, t]), <CanvasNode>[i, t]);
      expect(duplicateSources(<CanvasNode>[r]), isEmpty, reason: '只有产物 ⇒ 这一项置灰');
    });
  });

  group('存为角色', () {
    test('恰好一张带图的产物节点 ⇒ 那一张', () {
      final CanvasNode r = _result('r', imageUrl: 'images/r.png');
      expect(characterSource(<CanvasNode>[r]), r);
    });

    test('视频产物（没有 image_url）/ 配置节点 / 两张 ⇒ null', () {
      expect(characterSource(<CanvasNode>[_result('v', videoUrl: 'v.mp4')]), isNull);
      expect(characterSource(<CanvasNode>[_config('i')]), isNull);
      expect(
        characterSource(<CanvasNode>[
          _result('r1', imageUrl: 'images/1.png'),
          _result('r2', imageUrl: 'images/2.png'),
        ]),
        isNull,
      );
    });
  });

  group('加入泳道 ›', () {
    test('目标全在某条道里 ⇒ 那一条打勾；按泳道顺序列出', () {
      final List<LaneMenuOption> options = laneMenuOptions(
        lanes: _lanes,
        targets: <CanvasNode>[
          _config('i', laneId: 'lane-b'),
          _result('r', imageUrl: 'images/r.png', laneId: 'lane-b'),
        ],
      );
      expect(options.map((LaneMenuOption o) => o.lane.id), <String>['lane-a', 'lane-b']);
      expect(options.map((LaneMenuOption o) => o.current), <bool>[false, true]);
    });

    test('目标分在不同的道里 / 不在道里 ⇒ 没有一条打勾', () {
      expect(
        laneMenuOptions(
          lanes: _lanes,
          targets: <CanvasNode>[_config('i', laneId: 'lane-a'), _config('j', laneId: 'lane-b')],
        ).any((LaneMenuOption o) => o.current),
        isFalse,
      );
      expect(
        laneMenuOptions(lanes: _lanes, targets: <CanvasNode>[_config('i')])
            .any((LaneMenuOption o) => o.current),
        isFalse,
      );
    });

    test('移出泳道：目标里至少一张在还存在的道里才可点', () {
      expect(
        canRemoveFromLane(lanes: _lanes, targets: <CanvasNode>[_config('i'), _config('j', laneId: 'lane-a')]),
        isTrue,
      );
      expect(canRemoveFromLane(lanes: _lanes, targets: <CanvasNode>[_config('i')]), isFalse);
      expect(
        canRemoveFromLane(lanes: _lanes, targets: <CanvasNode>[_config('i', laneId: 'deleted-lane')]),
        isFalse,
        reason: '泳道已经删了的不算在道里',
      );
    });

    test('真要挪的节点：已经在目标道里的不动；移出时本来就不在道里的不动', () {
      final CanvasNode a = _config('a', laneId: 'lane-a');
      final CanvasNode b = _config('b', laneId: 'lane-b');
      final CanvasNode free = _config('free');
      expect(laneMoveCandidates(<CanvasNode>[a, b, free], 'lane-b'), <CanvasNode>[a, free]);
      expect(laneMoveCandidates(<CanvasNode>[a, b, free], null), <CanvasNode>[a, b]);
    });
  });

  group('laneMoveDelta（加入 / 移出泳道时的位置）', () {
    const double half = 191 / 2;

    test('卡片已经画在目标道的带里：屏幕上不动（只按新道的锚定换算世界坐标）', () {
      // 不在道里的卡，缩放 0.5：中心画在泳道栈 0.5 × 1095.5 = 547.75，在第二条道 [400, 800) 里。
      final CanvasNode free = _config('free', position: const Offset(0, 1000));
      final Offset d = laneMoveDelta(
        node: free,
        toLaneId: 'lane-b',
        laneSlices: _slices,
        direction: LaneDirection.horizontal,
        scale: 0.5,
      );
      expect(d.dx, 0);
      expect(d.dy, closeTo(-400, 1e-9));
      final CanvasNode moved = _config('free', position: free.position + d, laneId: 'lane-b');
      expect(_drawnCenter(moved, scale: 0.5), closeTo(_drawnCenter(free, scale: 0.5), 1e-9));
    });

    test('卡片在目标道的带外（上方）：收进带里，贴着近的那条边，整张卡留在带内', () {
      // 第一条道里的卡（缩放 1，中心 135.5）加入第二条道 [400, 800)：中心收到 400 + 95.5。
      final CanvasNode a = _config('a', position: const Offset(40, 40), laneId: 'lane-a');
      final Offset d = laneMoveDelta(
        node: a,
        toLaneId: 'lane-b',
        laneSlices: _slices,
        direction: LaneDirection.horizontal,
        scale: 1,
      );
      expect(d, const Offset(0, 360));
      final CanvasNode moved = _config('a', position: a.position + d, laneId: 'lane-b');
      expect(_drawnCenter(moved, scale: 1), closeTo(400 + half, 1e-9));
    });

    test('卡片在目标道的带外（下方）：收到下边内侧', () {
      final CanvasNode far = _config('far', position: const Offset(0, 2000));
      final Offset d = laneMoveDelta(
        node: far,
        toLaneId: 'lane-a',
        laneSlices: _slices,
        direction: LaneDirection.horizontal,
        scale: 1,
      );
      final CanvasNode moved = _config('far', position: far.position + d, laneId: 'lane-a');
      expect(_drawnCenter(moved, scale: 1), closeTo(400 - half, 1e-9));
    });

    test('带比卡片还窄（折叠的道）：中心放在带的中线上', () {
      const List<({String id, double size})> collapsed = <({String id, double size})>[
        (id: 'lane-a', size: kCollapsedLaneSize),
        (id: 'lane-b', size: 400),
      ];
      final CanvasNode free = _config('free', position: const Offset(0, 900));
      final Offset d = laneMoveDelta(
        node: free,
        toLaneId: 'lane-a',
        laneSlices: collapsed,
        direction: LaneDirection.horizontal,
        scale: 1,
      );
      expect(free.position.dy + d.dy + half, closeTo(kCollapsedLaneSize / 2, 1e-9));
    });

    test('移出泳道：屏幕上不动，按不在道里的卡换算世界坐标', () {
      // 第二条道里的卡，缩放 0.5：中心画在 400 + 0.5 × (595.5 − 400) = 497.75 ⇒ 不在道里时世界中心 995.5。
      final CanvasNode inB = _config('b', position: const Offset(0, 500), laneId: 'lane-b');
      final Offset d = laneMoveDelta(
        node: inB,
        toLaneId: null,
        laneSlices: _slices,
        direction: LaneDirection.horizontal,
        scale: 0.5,
      );
      expect(d, const Offset(0, 400));
      final CanvasNode moved = _config('b', position: inB.position + d);
      expect(_drawnCenter(moved, scale: 0.5), closeTo(_drawnCenter(inB, scale: 0.5), 1e-9));
    });

    test('竖向泳道：只动 x', () {
      final CanvasNode a = _config('a', position: const Offset(40, 40), laneId: 'lane-a');
      final Offset d = laneMoveDelta(
        node: a,
        toLaneId: 'lane-b',
        laneSlices: _slices,
        direction: LaneDirection.vertical,
        scale: 1,
      );
      // 卡宽 224：中心 40 + 112 = 152 收到 400 + 112。
      expect(d, const Offset(360, 0));
    });
  });

  test('NodeMenuPick：值相等即同一项（菜单行的 ValueKey 靠它）', () {
    expect(const NodeMenuPick.moveToLane('lane-a'), const NodeMenuPick.moveToLane('lane-a'));
    expect(const NodeMenuPick.moveToLane('lane-a'), isNot(const NodeMenuPick.moveToLane('lane-b')));
    expect(
      const NodeMenuPick(NodeMenuAction.removeFromLane),
      isNot(const NodeMenuPick(NodeMenuAction.laneSubmenu)),
    );
  });
}
