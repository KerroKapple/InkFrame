// 大纲 / ⌘K 的镜号（canvas/util/outline_model.dart）：sequenceShotNumbers 与组头计数 OutlineGroup.shotCount。
//
// 镜号是序列的口径：序列 lens 折叠后的镜序，节点归哪一镜复用「在序列中查看」的判据（shotIndexByNode）。
// 大纲行号与序列视图 / 画廊的交叉核对在 outline_model_test.dart 的「镜号」组；这里钉函数本身的输出。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/outline_model.dart';

CanvasNode _shot(String id, String notes) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      typeConfig: <String, Object?>{'shot_notes': notes},
    );

CanvasNode _image(String id, {String prompt = ''}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'prompt': prompt},
    );

CanvasNode _result(String id, String source) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: source,
      createdAt: DateTime.utc(2026, 5, 1),
      typeConfig: <String, Object?>{'image_url': 'images/$id.png'},
    );

CanvasEdge _narrative(String from, String to, {int sortOrder = 0}) => CanvasEdge(
      id: 'e-$from-$to',
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
      sortOrder: sortOrder,
    );

void main() {
  group('sequenceShotNumbers', () {
    test('镜头链 S1→S2→S3、S2 接出的 C2 有图：C2 和它的图都归 S2 那一镜，S3 是第 3 镜', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _shot('S1', 'harbor at dawn'),
        _shot('S2', 'a lone boat'),
        _shot('S3', 'far peaks'),
        _image('C2', prompt: 'a lone boat'),
        _result('R2', 'C2'),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[
        _narrative('S1', 'S2'),
        _narrative('S2', 'S3', sortOrder: 1),
        _narrative('S2', 'C2'),
      ];
      expect(sequenceShotNumbers(nodes, edges), <String, int>{
        'S1': 1,
        'S2': 2,
        'C2': 2,
        'R2': 2,
        'S3': 3,
      });
    });

    test('链上但折叠时被跳过的（自己没产物没备注，也没借到）、不在链上的：都不在表里', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _image('a', prompt: 'harbor'),
        _image('b'),
        _image('loose', prompt: 'peaks'),
      ];
      expect(sequenceShotNumbers(nodes, <CanvasEdge>[_narrative('a', 'b')]), <String, int>{'a': 1});
    });

    test('没有叙事链 → 空表', () {
      expect(sequenceShotNumbers(<CanvasNode>[_image('a', prompt: 'x')], const <CanvasEdge>[]), isEmpty);
    });
  });

  test('OutlineGroup.shotCount：组内不同镜号的个数——同一镜的几行只算一次，没有镜号的行不算', () {
    final OutlineGroup group = OutlineGroup(
      kind: OutlineGroupKind.unassigned,
      shots: <OutlineShot>[
        OutlineShot(node: _shot('S1', 'x'), sequence: 1),
        OutlineShot(node: _shot('S2', 'y'), sequence: 2),
        OutlineShot(node: _image('C2'), sequence: 2),
        OutlineShot(node: _image('b')),
      ],
    );
    expect(group.shotCount, 2);
  });
}
