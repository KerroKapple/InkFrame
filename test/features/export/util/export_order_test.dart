// EX-1′：导出对话框默认序 = narrative 链序。
//
// 为什么不能直接把 video result 节点丢给 orderByNarrativeChain：result 节点
// 挂在 config 节点下（sourceNodeId），**自己不在 narrative 链上**——按 result
// 集合建链会一条边都找不到，排序直接退化成 position.x。正确路径是先按链排
// config/shot 节点，再经 artifacts util 映射到各自最新产物。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/export/util/export_order.dart';

CanvasNode _shot(String id, {double x = 0}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      projectId: 'p1',
      position: Offset(x, 0),
    );

CanvasNode _video(
  String id, {
  required String source,
  double x = 0,
  DateTime? createdAt,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      projectId: 'p1',
      sourceNodeId: source,
      createdAt: createdAt,
      position: Offset(x, 0),
      typeConfig: <String, Object?>{'video_url': '$id.mp4'},
    );

CanvasEdge _narr(String id, String s, String t) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: s,
      targetNodeId: t,
      edgeType: EdgeType.narrative,
    );

List<String> _ids(List<CanvasNode> ns) => ns.map((n) => n.id).toList();

void main() {
  group('orderVideoNodesForExport', () {
    test('无 narrative 边 → 退回 position.x 升序（与旧行为一致）', () {
      final nodes = [
        _shot('s1'),
        _video('v2', source: 's1', x: 900),
        _video('v1', source: 's1', x: 100),
      ];
      expect(_ids(orderVideoNodesForExport(allNodes: nodes, edges: const [])),
          ['v1', 'v2']);
    });

    test('有链时按链序,压过 position.x', () {
      // 三镜的产物在画布上刻意左右颠倒摆放：链序 s1→s2→s3,x 却是 3、2、1。
      final nodes = [
        _shot('s1', x: 0),
        _shot('s2', x: 300),
        _shot('s3', x: 600),
        _video('v1', source: 's1', x: 900),
        _video('v2', source: 's2', x: 500),
        _video('v3', source: 's3', x: 100),
      ];
      final edges = [_narr('e1', 's1', 's2'), _narr('e2', 's2', 's3')];

      expect(_ids(orderVideoNodesForExport(allNodes: nodes, edges: edges)),
          ['v1', 'v2', 'v3']);
    });

    test('一个 shot 多次重跑 → take 成组跟在该镜位置,新的在前', () {
      // 候选集不收窄（旧 take 照样列出,与本卡之前行为一致）,只保证它们
      // 挨着自己那一镜、且最新的排前面——而不是散落到列表末尾。
      final nodes = [
        _shot('s1'),
        _shot('s2', x: 300),
        _video('v1', source: 's1'),
        _video('v2old', source: 's2', createdAt: DateTime.utc(2026, 1, 1)),
        _video('v2new', source: 's2', createdAt: DateTime.utc(2026, 8, 7)),
      ];
      final edges = [_narr('e1', 's1', 's2')];

      final out = _ids(orderVideoNodesForExport(allNodes: nodes, edges: edges));
      expect(out, ['v1', 'v2new', 'v2old']);
    });

    test('链外的孤立产物排在链上产物之后,内部按 position.x', () {
      final nodes = [
        _shot('s1'),
        _shot('s2', x: 300),
        _video('chain1', source: 's1', x: 999),
        _video('chain2', source: 's2', x: 998),
        _video('loose2', source: 'nobody', x: 50),
        _video('loose1', source: 'nobody2', x: 10),
      ];
      final edges = [_narr('e1', 's1', 's2')];

      expect(_ids(orderVideoNodesForExport(allNodes: nodes, edges: edges)),
          ['chain1', 'chain2', 'loose1', 'loose2']);
    });

    test('只出可导出的 video result——config / image / 无 url 一律不进', () {
      final nodes = [
        _shot('s1'),
        _video('ok', source: 's1'),
        const CanvasNode(
          id: 'img',
          label: 'img',
          type: CanvasNodeType.image,
          role: NodeRole.result,
          canvasId: 'c1',
          projectId: 'p1',
          sourceNodeId: 's1',
          typeConfig: <String, Object?>{'image_url': 'a.png'},
        ),
        const CanvasNode(
          id: 'nourl',
          label: 'nourl',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          canvasId: 'c1',
          projectId: 'p1',
          sourceNodeId: 's1',
          typeConfig: <String, Object?>{},
        ),
        const CanvasNode(
          id: 'nocanvas',
          label: 'nocanvas',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          projectId: 'p1',
          sourceNodeId: 's1',
          typeConfig: <String, Object?>{'video_url': 'x.mp4'},
        ),
      ];
      expect(_ids(orderVideoNodesForExport(allNodes: nodes, edges: const [])),
          ['ok']);
    });

    test('不重复输出：一个产物即便被多条路径够到也只出现一次', () {
      final nodes = [
        _shot('s1'),
        _shot('s2', x: 300),
        _video('shared', source: 's1'),
      ];
      // s1→s2 与 s2→s1 构成环,遍历会两次经过 s1 附近。
      final edges = [_narr('e1', 's1', 's2'), _narr('e2', 's2', 's1')];

      final out = _ids(orderVideoNodesForExport(allNodes: nodes, edges: edges));
      expect(out, ['shared']);
    });

    test('空输入 → 空输出', () {
      expect(orderVideoNodesForExport(allNodes: const [], edges: const []),
          isEmpty);
    });
  });
}
