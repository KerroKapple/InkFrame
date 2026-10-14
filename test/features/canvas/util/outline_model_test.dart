// 左栏大纲分组（PR-4）：buildCanvasOutline 与「在链上」判据的纯函数测试。
//
// 每一条都对着派工单 §3 的一句口径：组序跟泳道 sortOrder、组内按叙事链序、链上无泳道进
// 「未分泳道」、不在链上进「未入链」（最后、按位置、不编号）、编号是全画布链序、筛选按名称或
// 提示词不区分大小写且整组都不匹配就不出、产物取最新一个并给出总数。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/outline_model.dart';

CanvasNode _config(
  String id, {
  String? lane,
  Offset position = Offset.zero,
  String prompt = '',
  CanvasNodeType type = CanvasNodeType.image,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      laneId: lane,
      position: position,
      typeConfig: <String, Object?>{'prompt': prompt},
    );

CanvasNode _result(String id, {required String source, required DateTime at, bool video = false}) =>
    CanvasNode(
      id: id,
      label: id,
      type: video ? CanvasNodeType.video : CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{
        if (video) 'video_url': 'videos/$id.mp4' else 'image_url': 'images/$id.png',
      },
    );

CanvasEdge _narrative(String from, String to, {int sortOrder = 0}) => CanvasEdge(
      id: 'e-$from-$to',
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
      sortOrder: sortOrder,
    );

StyleLane _lane(String id, int sortOrder) =>
    StyleLane(id: id, canvasId: 'c1', label: id, sortOrder: sortOrder);

CanvasOutline _build(
  List<CanvasNode> nodes, {
  List<CanvasEdge> edges = const <CanvasEdge>[],
  List<StyleLane> lanes = const <StyleLane>[],
  String query = '',
}) =>
    buildCanvasOutline(
      nodes: nodes,
      edges: edges,
      lanes: lanes,
      query: query,
      nameOf: (CanvasNode n) => n.label,
      promptOf: (CanvasNode n) => n.promptText,
    );

List<String> _ids(OutlineGroup g) => <String>[for (final OutlineShot s in g.shots) s.node.id];

void main() {
  group('narrativeChainMembers / narrativeSequenceIndex', () {
    test('两端都在节点集里的 narrative 边才算；悬空边与 data 边不算', () {
      final List<CanvasNode> nodes = <CanvasNode>[_config('a'), _config('b'), _config('c')];
      final List<CanvasEdge> edges = <CanvasEdge>[
        _narrative('a', 'b'),
        _narrative('b', 'gone'), // 一端已删
        const CanvasEdge(
          id: 'data',
          canvasId: 'c1',
          sourceNodeId: 'b',
          targetNodeId: 'c',
          edgeType: EdgeType.data,
        ),
      ];
      expect(narrativeChainMembers(nodes, edges), <String>{'a', 'b'});
      expect(narrativeSequenceIndex(nodes, edges), <String, int>{'a': 1, 'b': 2});
    });

    test('没有链 → 空表', () {
      expect(narrativeSequenceIndex(<CanvasNode>[_config('a')], const <CanvasEdge>[]), isEmpty);
    });
  });

  group('分组', () {
    test('泳道组按 sortOrder（不按传入顺序）；组内按叙事链序；链上无泳道进「未分泳道」排在泳道组之后', () {
      // 链：a → b → c → d → e（位置故意倒着摆，证明组内序看链不看位置）。
      final List<CanvasNode> nodes = <CanvasNode>[
        _config('e', lane: 'L1', position: const Offset(0, 0)),
        _config('d', position: const Offset(100, 0)),
        _config('c', lane: 'L2', position: const Offset(200, 0)),
        _config('b', lane: 'L1', position: const Offset(300, 0)),
        _config('a', lane: 'L2', position: const Offset(400, 0)),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[
        _narrative('a', 'b'),
        _narrative('b', 'c'),
        _narrative('c', 'd'),
        _narrative('d', 'e'),
      ];
      // 传入顺序 L1 在前，但 sortOrder 是 L2 = 0、L1 = 1。
      final CanvasOutline o = _build(
        nodes,
        edges: edges,
        lanes: <StyleLane>[_lane('L1', 1), _lane('L2', 0)],
      );

      expect(o.groups.map((OutlineGroup g) => g.kind), <OutlineGroupKind>[
        OutlineGroupKind.lane,
        OutlineGroupKind.lane,
        OutlineGroupKind.unassigned,
      ]);
      expect(o.groups[0].lane?.id, 'L2');
      expect(_ids(o.groups[0]), <String>['a', 'c']);
      expect(o.groups[1].lane?.id, 'L1');
      expect(_ids(o.groups[1]), <String>['b', 'e']);
      expect(_ids(o.groups[2]), <String>['d']);
      expect(o.configCount, 5);
    });

    test('泳道已不在（laneId 指向一条删掉的道）也算「未分泳道」', () {
      final CanvasOutline o = _build(
        <CanvasNode>[_config('a', lane: 'gone'), _config('b')],
        edges: <CanvasEdge>[_narrative('a', 'b')],
      );
      expect(o.groups.single.kind, OutlineGroupKind.unassigned);
      expect(_ids(o.groups.single), <String>['a', 'b']);
    });

    test('不在链上的进「未入链」：放在最后、按位置 (dx, dy) 排、不编号', () {
      final CanvasOutline o = _build(
        <CanvasNode>[
          _config('chainA'),
          _config('chainB'),
          _config('loose2', lane: 'L1', position: const Offset(500, 10)),
          _config('loose1', position: const Offset(500, 0)),
          _config('loose0', position: const Offset(-20, 900)),
        ],
        edges: <CanvasEdge>[_narrative('chainA', 'chainB')],
        lanes: <StyleLane>[_lane('L1', 0)],
      );
      expect(o.groups.last.kind, OutlineGroupKind.unchained);
      expect(_ids(o.groups.last), <String>['loose0', 'loose1', 'loose2'],
          reason: '在泳道里但不在链上的照样进未入链');
      for (final OutlineShot s in o.groups.last.shots) {
        expect(s.sequence, isNull, reason: '${s.node.id} 不在链上，不编号');
      }
    });

    test('只列配置节点：result 节点不成行；空泳道不出组头', () {
      final CanvasOutline o = _build(
        <CanvasNode>[
          _config('a', lane: 'L1'),
          _config('b', lane: 'L1'),
          _result('r', source: 'a', at: DateTime.utc(2026)),
        ],
        edges: <CanvasEdge>[_narrative('a', 'b')],
        lanes: <StyleLane>[_lane('L1', 0), _lane('Empty', 1)],
      );
      expect(o.groups, hasLength(1));
      expect(_ids(o.groups.single), <String>['a', 'b']);
      expect(o.configCount, 2);
    });

    test('画布上没有配置节点 → configCount 0（面板出空态）', () {
      final CanvasOutline o = _build(<CanvasNode>[
        _result('r', source: 'x', at: DateTime.utc(2026)),
      ]);
      expect(o.groups, isEmpty);
      expect(o.configCount, 0);
    });
  });

  group('编号', () {
    test('链序是全画布的，从 1 起：跨泳道交错时组内号不连续', () {
      final CanvasOutline o = _build(
        <CanvasNode>[
          _config('a', lane: 'L1'),
          _config('b', lane: 'L2'),
          _config('c', lane: 'L1'),
        ],
        edges: <CanvasEdge>[_narrative('a', 'b'), _narrative('b', 'c')],
        lanes: <StyleLane>[_lane('L1', 0), _lane('L2', 1)],
      );
      expect(
        <int?>[for (final OutlineShot s in o.groups[0].shots) s.sequence],
        <int?>[1, 3],
      );
      expect(o.groups[1].shots.single.sequence, 2);
    });
  });

  group('筛选', () {
    final List<CanvasNode> nodes = <CanvasNode>[
      _config('Harbor dawn', lane: 'L1', prompt: 'misty river'),
      _config('Boat', lane: 'L1', prompt: 'A lone FISHERMAN'),
      _config('Mountain', lane: 'L2', prompt: 'far peaks'),
      _config('Reference', prompt: 'ink wash'),
    ];
    final List<CanvasEdge> edges = <CanvasEdge>[
      _narrative('Harbor dawn', 'Boat'),
      _narrative('Boat', 'Mountain'),
    ];
    final List<StyleLane> lanes = <StyleLane>[_lane('L1', 0), _lane('L2', 1)];

    test('按名称不区分大小写包含匹配', () {
      final CanvasOutline o = _build(nodes, edges: edges, lanes: lanes, query: '  HARBOR ');
      expect(o.groups, hasLength(1));
      expect(_ids(o.groups.single), <String>['Harbor dawn']);
    });

    test('按提示词不区分大小写包含匹配', () {
      final CanvasOutline o = _build(nodes, edges: edges, lanes: lanes, query: 'fisherman');
      expect(_ids(o.groups.single), <String>['Boat']);
    });

    test('一组里一个都不匹配，整组不画；筛选不改编号；configCount 仍是筛选前的数', () {
      final CanvasOutline o = _build(nodes, edges: edges, lanes: lanes, query: 'peaks');
      expect(o.groups.single.lane?.id, 'L2', reason: 'L1 一镜都没命中 → 整组不出，未入链同理');
      expect(o.groups.single.shots.single.sequence, 3, reason: '编号还是全画布链序');
      expect(o.configCount, 4);
    });

    test('都不匹配 → 没有组，但 configCount > 0（只是没命中，不是空画布）', () {
      final CanvasOutline o = _build(nodes, edges: edges, lanes: lanes, query: 'zzz');
      expect(o.groups, isEmpty);
      expect(o.configCount, 4);
    });
  });

  group('产物子行', () {
    test('最新一个（按 created_at，不按列表序）+ 总数', () {
      final CanvasOutline o = _build(<CanvasNode>[
        _config('a'),
        // 列表序最后的是最旧的——取最新必须看时间，不能取末位。
        _result('new', source: 'a', at: DateTime.utc(2026, 3)),
        _result('mid', source: 'a', at: DateTime.utc(2026, 2)),
        _result('old', source: 'a', at: DateTime.utc(2026, 1)),
        _result('other', source: 'b', at: DateTime.utc(2026, 4)),
      ]);
      final OutlineShot s = o.groups.single.shots.single;
      expect(s.latest?.id, 'new');
      expect(s.artifactCount, 3, reason: '别的节点的产物不算');
    });

    test('没有产物 → latest 为 null、count 0；只有占位（无 url）的 result 不算产物', () {
      final CanvasOutline o = _build(<CanvasNode>[
        _config('a'),
        const CanvasNode(
          id: 'placeholder',
          label: 'p',
          type: CanvasNodeType.image,
          role: NodeRole.result,
          sourceNodeId: 'a',
        ),
      ]);
      final OutlineShot s = o.groups.single.shots.single;
      expect(s.latest, isNull);
      expect(s.artifactCount, 0);
    });
  });
}
