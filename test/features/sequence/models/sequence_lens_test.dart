// SequenceLens（P2）：buildSequence 之上的几何——起点 / 总长 / 场次标记 / 未入链 / 定位。纯函数。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/storyboard/models/sequence_shot.dart';

CanvasNode _shot(String id, {int? durationMs}) => CanvasNode(
      id: id,
      label: 'shot-$id',
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        'shot_notes': 'notes $id',
        'duration_ms': ?durationMs,
      },
    );

CanvasNode _imageConfig(String id) => CanvasNode(
      id: id,
      label: 'img-$id',
      type: CanvasNodeType.image,
      canvasId: 'c1',
    );

CanvasNode _imageResult(String id, {required String source}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      typeConfig: const <String, Object?>{'image_url': 'images/x.png'},
    );

CanvasEdge _narrative(String id, String from, String to) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
    );

void main() {
  group('buildSequenceLens', () {
    test('空画布 → empty', () {
      final SequenceLens lens = buildSequenceLens(nodes: const <CanvasNode>[], edges: const <CanvasEdge>[]);
      expect(lens.isEmpty, isTrue);
      expect(lens.totalMs, 0);
      expect(lens.markers, isEmpty);
      expect(lens.unchainedCount, 0);
    });

    test('起点 = 前序镜时长累加，总长 = 全部时长；占位镜照样计时', () {
      final SequenceLens lens = buildSequenceLens(
        nodes: <CanvasNode>[_shot('a'), _shot('b'), _shot('c')],
        edges: <CanvasEdge>[_narrative('e1', 'a', 'b'), _narrative('e2', 'b', 'c')],
      );
      expect(lens.shots.map((SequenceShot s) => s.nodeId), <String>['a', 'b', 'c']);
      expect(lens.startsMs, <int>[0, kDefaultShotDurationMs, kDefaultShotDurationMs * 2]);
      expect(lens.totalMs, kDefaultShotDurationMs * 3);
      expect(lens.placeholderCount, 3);
    });

    test('场次标记：链上每个 shot 节点在它那一镜的起点开一个，标签 = 节点名', () {
      // shot a → image config x（借产物）→ shot b：x 被 a 折叠，不单独成镜也不出标记。
      final SequenceLens lens = buildSequenceLens(
        nodes: <CanvasNode>[_shot('a'), _imageConfig('x'), _imageResult('rx', source: 'x'), _shot('b')],
        edges: <CanvasEdge>[_narrative('e1', 'a', 'x'), _narrative('e2', 'x', 'b')],
      );
      expect(lens.shots.length, 2);
      expect(lens.markers.map((SceneMarker m) => m.nodeId), <String>['a', 'b']);
      expect(lens.markers.map((SceneMarker m) => m.label), <String>['shot-a', 'shot-b']);
      expect(lens.markers.map((SceneMarker m) => m.atMs), <int>[0, kDefaultShotDurationMs]);
    });

    test('未入链 = 有产物却不在任何叙事边上的 config 节点；无产物的不算', () {
      final SequenceLens lens = buildSequenceLens(
        nodes: <CanvasNode>[
          _shot('a'),
          _shot('b'),
          _imageConfig('loose'),
          _imageResult('r-loose', source: 'loose'),
          _imageConfig('empty'),
        ],
        edges: <CanvasEdge>[_narrative('e1', 'a', 'b')],
      );
      expect(lens.unchainedCount, 1);
    });
  });

  group('locate / globalMs', () {
    final SequenceLens lens = buildSequenceLens(
      nodes: <CanvasNode>[_shot('a', durationMs: 2000), _shot('b', durationMs: 1000), _shot('c', durationMs: 3000)],
      edges: <CanvasEdge>[_narrative('e1', 'a', 'b'), _narrative('e2', 'b', 'c')],
    );

    test('落在镜内 → 该镜 + 镜内偏移', () {
      expect(lens.locate(2500), (index: 1, offsetMs: 500));
      expect(lens.locate(0), (index: 0, offsetMs: 0));
      expect(lens.locate(2000), (index: 1, offsetMs: 0), reason: '边界归下一镜的起点');
    });

    test('越界夹到首尾', () {
      expect(lens.locate(-5), (index: 0, offsetMs: 0));
      expect(lens.locate(99999), (index: 2, offsetMs: 3000));
    });

    test('globalMs 是 locate 的逆；偏移夹在镜长内', () {
      expect(lens.globalMs(1, 500), 2500);
      expect(lens.globalMs(2, 99999), 6000);
      expect(SequenceLens.empty.globalMs(3, 3), 0);
      expect(SequenceLens.empty.locate(3), (index: 0, offsetMs: 0));
    });
  });
}
