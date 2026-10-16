// 左栏大纲分组（PR-4）：buildCanvasOutline 与「在链上」判据的纯函数测试。
//
// 每一条都对着派工单 §3 的一句口径：组序跟泳道 sortOrder、组内按叙事链序、链上无泳道进
// 「未分泳道」、不在链上进「未入链」（最后、按位置、不编号）、筛选按名称或提示词不区分大小写且
// 整组都不匹配就不出、产物取最新一个并给出总数。
// 镜号是序列的口径（不是链上 DFS 序）：「镜号」组拿审查给的两个场景交叉核对——大纲每一行的号 ==
// 序列 lens 里它所在那一镜的号（「在序列中查看」的判据）== 画廊写的「序列 NNN」。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/outline_model.dart';
import 'package:inkframe/features/gallery/models/gallery_graph.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/util/shot_index.dart';

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

/// 镜头节点（剧本拆出来的那种）：正文是 shot_notes。
CanvasNode _shot(String id, {required String notes, String? lane}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      laneId: lane,
      typeConfig: <String, Object?>{'shot_notes': notes},
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

List<int?> _numbers(OutlineGroup g) => <int?>[for (final OutlineShot s in g.shots) s.sequence];

/// 交叉核对：大纲每一行的镜号 == 序列 lens 里它所在那一镜的序号（「在序列中查看」的判据，1 起；
/// 不在任何一镜里 = 不编号）。
void _expectSameAsSequence(CanvasOutline o, List<CanvasNode> nodes, List<CanvasEdge> edges) {
  final SequenceLens lens = buildSequenceLens(nodes: nodes, edges: edges);
  for (final OutlineGroup g in o.groups) {
    for (final OutlineShot s in g.shots) {
      final int i = shotIndexForSelection(lens, selection: <String>{s.node.id}, nodes: nodes);
      expect(s.sequence, i < 0 ? null : i + 1, reason: '${s.node.id} 的镜号与序列视图不一致');
    }
  }
}

/// 画廊给这张产物写的「序列 NNN」（只有一张画布 c1）。
int? _gallerySequenceOf(List<CanvasNode> nodes, List<CanvasEdge> edges, String relativePath) =>
    GalleryIndex.build(
      GalleryGraph(
        canvases: const <GalleryCanvasInfo>[GalleryCanvasInfo(id: 'c1', name: 'c1')],
        nodesByCanvas: <String, List<CanvasNode>>{'c1': nodes},
        edgesByCanvas: <String, List<CanvasEdge>>{'c1': edges},
        slotsByNode: const <String, List<GalleryBatchSlot>>{},
      ),
    ).sequenceIndexOf('c1', relativePath);

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
    test('镜号是全画布的，从 1 起：跨泳道交错时组内号不连续', () {
      // 三个都有提示词 ⇒ 各自成一镜（既无产物也无备注的节点在序列里会被跳过，见「镜号」组）。
      final CanvasOutline o = _build(
        <CanvasNode>[
          _config('a', lane: 'L1', prompt: 'harbor'),
          _config('b', lane: 'L2', prompt: 'boat'),
          _config('c', lane: 'L1', prompt: 'peaks'),
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

  group('镜号 = 序列的口径（与 buildSequence / lens、画廊交叉核对）', () {
    test('场景 A：S1→S2→S3 的镜头链，S2 上「用本镜备注生成图像」接出的 C2 有图 ⇒ C2 与 S2 同号，S3 是 03', () {
      // 边：S1→S2（sortOrder 0）、S2→S3（sortOrder 1）、S2→C2（sortOrder 0）；C2 名下有图。
      // 链上 DFS 序是 S1、S2、C2、S3——按它编号 C2 写 03、S3 写 04，而序列把 C2 的图借给了 S2。
      final List<CanvasNode> nodes = <CanvasNode>[
        _shot('S1', notes: 'harbor at dawn'),
        _shot('S2', notes: 'a lone boat'),
        _shot('S3', notes: 'far peaks'),
        _config('C2', prompt: 'a lone boat'),
        _result('R2', source: 'C2', at: DateTime.utc(2026, 5, 1)),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[
        _narrative('S1', 'S2'),
        _narrative('S2', 'S3', sortOrder: 1),
        _narrative('S2', 'C2'),
      ];
      final CanvasOutline o = _build(nodes, edges: edges);

      expect(_ids(o.groups.single), <String>['S1', 'S2', 'C2', 'S3'], reason: '行序仍是叙事链序');
      expect(_numbers(o.groups.single), <int?>[1, 2, 2, 3]);
      _expectSameAsSequence(o, nodes, edges);
      expect(_gallerySequenceOf(nodes, edges, 'images/R2.png'), 2, reason: '画廊给这张图写「序列 002」');
    });

    test('场景 B：C1→C2（C2 没提示词、没产物）→C3（有图）⇒ C2 借走 C3 的图成一镜，C3 与 C2 同号', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _config('C1', prompt: 'harbor at dawn'),
        _config('C2'),
        _config('C3', prompt: 'far peaks'),
        _result('R3', source: 'C3', at: DateTime.utc(2026, 5, 1)),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[_narrative('C1', 'C2'), _narrative('C2', 'C3')];
      final CanvasOutline o = _build(nodes, edges: edges);

      expect(_ids(o.groups.single), <String>['C1', 'C2', 'C3']);
      expect(_numbers(o.groups.single), <int?>[1, 2, 2]);
      _expectSameAsSequence(o, nodes, edges);
      expect(_gallerySequenceOf(nodes, edges, 'images/R3.png'), 2, reason: '画廊给这张图写「序列 002」');
    });

    test('链上但不在任何一镜里（既无产物也无备注、也没借到）：不编号，仍留在泳道组里', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _config('a', lane: 'L1', prompt: 'harbor'),
        _config('b', lane: 'L1'),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[_narrative('a', 'b')];
      final CanvasOutline o = _build(nodes, edges: edges, lanes: <StyleLane>[_lane('L1', 0)]);

      expect(o.groups.single.kind, OutlineGroupKind.lane);
      expect(_ids(o.groups.single), <String>['a', 'b']);
      expect(_numbers(o.groups.single), <int?>[1, null]);
      _expectSameAsSequence(o, nodes, edges);
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
      expect(o.groups.single.shots.single.sequence, 3, reason: '筛选不改镜号：还是全画布的那个号');
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
