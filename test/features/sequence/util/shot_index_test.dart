// 「在序列中查看 / 定位」的跳镜头判据 shotIndexForSelection（sequence/util/shot_index.dart）。
//
// PR-8b 把它从 shell_tab_bar.dart 原样搬出来（标签栏「在序列中查看」与画布节点右键菜单「在序列中定位」
// 共用），用例随之从 shell_tab_bar_view_in_sequence_test.dart 原样搬过来：产物归到来源那一镜，把产物借给
// 前一镜的配置节点（折叠）落在借走它的那一镜，多选取链序最靠前的。外壳级的切标签 + 跳播放头仍在那个文件里。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/util/shot_index.dart';

CanvasNode _shot(String id, {Map<String, Object?> config = const <String, Object?>{}}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: config,
    );

CanvasNode _imageConfig(String id) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: const <String, Object?>{'prompt': 'boat at dawn'},
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
  group('shotIndexForSelection', () {
    // s1 ──narrative──> ic1 ──narrative──> s2：ic1 把它的最新产物 r1 借给了 s1（折叠，不单独成镜），
    // 所以序列只有两镜：0 = s1（放 r1），1 = s2（备注占位）。r0 是 ic1 更早的一张。
    final List<CanvasNode> nodes = <CanvasNode>[
      _shot('s1', config: const <String, Object?>{'shot_notes': 'harbor'}),
      _imageConfig('ic1'),
      _imageResult('r0', source: 'ic1', at: DateTime.utc(2026, 5, 1)),
      _imageResult('r1', source: 'ic1', at: DateTime.utc(2026, 5, 2)),
      _shot('s2', config: const <String, Object?>{'shot_notes': 'mountain'}),
      const CanvasNode(id: 'loose', label: 'loose', type: CanvasNodeType.text, canvasId: 'c1'),
    ];
    final SequenceLens lens = buildSequenceLens(
      nodes: nodes,
      edges: <CanvasEdge>[_narrative('s1', 'ic1'), _narrative('ic1', 's2')],
    );

    int indexOf(Set<String> selection) =>
        shotIndexForSelection(lens, selection: selection, nodes: nodes);

    test('前提：序列是两镜，第 0 镜放的是 r1', () {
      expect(lens.shots.map((s) => s.nodeId), <String>['s1', 's2']);
      expect(lens.shots.first.artifactNodeId, 'r1');
    });

    test('自己就是那一镜', () {
      expect(indexOf(<String>{'s1'}), 0);
      expect(indexOf(<String>{'s2'}), 1);
    });

    test('那一镜放的就是它（选中的是成片）', () {
      expect(indexOf(<String>{'r1'}), 0);
    });

    test('把产物借给前一镜的配置节点 → 借走它产物的那一镜；它名下更早的产物同样归过去', () {
      expect(indexOf(<String>{'ic1'}), 0);
      expect(indexOf(<String>{'r0'}), 0);
    });

    test('多选：取链序最靠前的那一镜', () {
      expect(indexOf(<String>{'s2', 'ic1'}), 0);
      expect(indexOf(<String>{'loose', 's2'}), 1);
    });

    test('没选中 / 都不在链上 ⇒ -1', () {
      expect(indexOf(const <String>{}), -1);
      expect(indexOf(<String>{'loose'}), -1);
      expect(indexOf(<String>{'missing'}), -1);
    });
  });
}
