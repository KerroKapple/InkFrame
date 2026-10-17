// 「当前 take」的固定 id 读取（canvas_node_take.dart）：type_config.pinned_result_id 只认非空字符串，
// 其余一律当没固定——判据回落最新，不会拿一个空串 / 数字去候选里找。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/canvas_node_take.dart';

CanvasNode _node(
  String id, {
  Map<String, Object?> typeConfig = const <String, Object?>{},
  NodeRole role = NodeRole.config,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: role,
      canvasId: 'c1',
      sourceNodeId: role == NodeRole.result ? 'cfg' : null,
      typeConfig: typeConfig,
    );

void main() {
  test('pinnedResultId：非空字符串才算', () {
    expect(_node('a', typeConfig: <String, Object?>{'pinned_result_id': 'r1'}).pinnedResultId, 'r1');
    expect(_node('missing').pinnedResultId, isNull, reason: '缺键');
    expect(_node('null', typeConfig: <String, Object?>{'pinned_result_id': null}).pinnedResultId, isNull);
    expect(_node('empty', typeConfig: <String, Object?>{'pinned_result_id': ''}).pinnedResultId, isNull);
    expect(_node('number', typeConfig: <String, Object?>{'pinned_result_id': 42}).pinnedResultId, isNull);
  });

  test('pinnedResultIdsBySource 只收有固定的配置节点', () {
    final Map<String, String> pins = pinnedResultIdsBySource(<CanvasNode>[
      _node('cfgA', typeConfig: <String, Object?>{'pinned_result_id': 'rA'}),
      _node('cfgB'),
      _node('cfgC', typeConfig: <String, Object?>{'pinned_result_id': ''}),
      // 产物节点上就算带了这个键也不收：固定是配置节点的属性。
      _node('rX', role: NodeRole.result, typeConfig: <String, Object?>{'pinned_result_id': 'rY', 'video_url': 'x.mp4'}),
    ]);
    expect(pins, <String, String>{'cfgA': 'rA'});
  });
}
