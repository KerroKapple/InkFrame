// 播放头（P2）：report 不动 seekToken（监视器自报进度不回环），用户 seek 才自增。不落库。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';

SequenceLens _lens() => buildSequenceLens(
      nodes: <CanvasNode>[
        for (final String id in <String>['a', 'b'])
          CanvasNode(
            id: id,
            label: id,
            type: CanvasNodeType.shot,
            canvasId: 'c1',
            typeConfig: <String, Object?>{'shot_notes': id, 'duration_ms': 2000},
          ),
      ],
      edges: const <CanvasEdge>[
        CanvasEdge(id: 'e', canvasId: 'c1', sourceNodeId: 'a', targetNodeId: 'b', edgeType: EdgeType.narrative),
      ],
    );

void main() {
  late ProviderContainer c;
  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
  });

  test('初始 0 / 0 / token 0', () {
    expect(c.read(sequencePlayheadProvider('c1')), const SequencePlayhead());
  });

  test('report 只改位置，seekToken 不变；同值不发新态', () {
    final SequencePlayheadController n = c.read(sequencePlayheadProvider('c1').notifier);
    int builds = 0;
    c.listen(sequencePlayheadProvider('c1'), (_, _) => builds++);

    n.report(1, 300);
    expect(c.read(sequencePlayheadProvider('c1')), const SequencePlayhead(index: 1, offsetMs: 300));
    n.report(1, 300);
    expect(builds, 1, reason: '同一位置重复 report 不应发新态');
  });

  test('selectShot 跳到该镜起点且 token +1', () {
    final SequencePlayheadController n = c.read(sequencePlayheadProvider('c1').notifier);
    n.report(0, 900);
    n.selectShot(1);
    expect(c.read(sequencePlayheadProvider('c1')), const SequencePlayhead(index: 1, offsetMs: 0, seekToken: 1));
    n.selectShot(1);
    expect(c.read(sequencePlayheadProvider('c1')).seekToken, 2, reason: '重复点同一镜也是一次 seek（回到起点）');
  });

  test('seekGlobal 按 lens 定位并 token +1', () {
    final SequencePlayheadController n = c.read(sequencePlayheadProvider('c1').notifier);
    n.seekGlobal(2500, _lens());
    expect(c.read(sequencePlayheadProvider('c1')), const SequencePlayhead(index: 1, offsetMs: 500, seekToken: 1));
  });

  test('按 canvasId 分族：另一画布不受影响', () {
    c.read(sequencePlayheadProvider('c1').notifier).selectShot(1);
    expect(c.read(sequencePlayheadProvider('c2')), const SequencePlayhead());
  });
}
