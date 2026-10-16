// shotIndexByNode（sequence/util/shot_index.dart）：一次给出每个节点所在那一镜。
//
// 它不另写折叠规则，逐个节点问的就是 shotIndexForSelection 用的那个判据——这里钉两件事：结果与逐个节点
// 调 shotIndexForSelection 完全一致；不在任何一镜里的节点不在表里。左栏大纲的镜号、⌘K 的「序列 NNN」
// 由它而来（canvas/util/outline_model.dart 的 sequenceShotNumbers）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/util/shot_index.dart';

CanvasNode _shot(String id, String notes) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'shot_notes': notes},
    );

CanvasNode _imageResult(String id, {required String source, required DateTime at}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{'image_url': 'images/$id.png'},
    );

CanvasEdge _narrative(String from, String to) => CanvasEdge(
      id: '$from-$to',
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
    );

void main() {
  // s1 ──narrative──> ic1 ──narrative──> s2：ic1 把它的最新产物 r1 借给了 s1（折叠，不单独成镜），
  // 所以序列只有两镜：0 = s1（放 r1），1 = s2（备注占位）。r0 是 ic1 更早的一张；loose 不在链上。
  final List<CanvasNode> nodes = <CanvasNode>[
    _shot('s1', 'harbor'),
    const CanvasNode(
      id: 'ic1',
      label: 'ic1',
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'prompt': 'boat at dawn'},
    ),
    _imageResult('r0', source: 'ic1', at: DateTime.utc(2026, 5, 1)),
    _imageResult('r1', source: 'ic1', at: DateTime.utc(2026, 5, 2)),
    _shot('s2', 'mountain'),
    const CanvasNode(id: 'loose', label: 'loose', type: CanvasNodeType.text, canvasId: 'c1'),
  ];
  final SequenceLens lens = buildSequenceLens(
    nodes: nodes,
    edges: <CanvasEdge>[_narrative('s1', 'ic1'), _narrative('ic1', 's2')],
  );

  test('每个节点所在那一镜：镜头自己、借出产物的配置和它名下的产物都归借走产物的那一镜；不在任何一镜里的不在表里', () {
    expect(shotIndexByNode(lens, nodes: nodes), <String, int>{
      's1': 0,
      'ic1': 0,
      'r0': 0,
      'r1': 0,
      's2': 1,
    });
  });

  test('与逐个节点调 shotIndexForSelection 完全一致（同一个判据，不是第二份规则）', () {
    final Map<String, int> byNode = shotIndexByNode(lens, nodes: nodes);
    for (final CanvasNode n in nodes) {
      expect(
        byNode[n.id] ?? -1,
        shotIndexForSelection(lens, selection: <String>{n.id}, nodes: nodes),
        reason: n.id,
      );
    }
  });

  test('序列是空的 → 空表', () {
    expect(shotIndexByNode(SequenceLens.empty, nodes: nodes), isEmpty);
  });
}
