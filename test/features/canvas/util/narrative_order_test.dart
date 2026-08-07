// SB-5 narrative 链排序 util 的用例集。
//
// 覆盖卡面点名的五类形态：单链 / 多链 / 分叉 / 环 / 孤立，外加 include 过滤
// 与「同源多出边按 sortOrder 再 id」的平手判定。核心不变量：**任何输入都产出
// 全序**（输出恰好是输入节点的一个排列，不丢不重），这是 SB-6 序列预览与
// EX-1′ 导出共享此 util 的前提——少一个节点就是少一镜。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/narrative_order.dart';

CanvasNode _node(String id, {double x = 0, double y = 0}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      position: Offset(x, y),
    );

CanvasEdge _edge(
  String id,
  String source,
  String target, {
  EdgeType type = EdgeType.narrative,
  int sortOrder = 0,
}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: type,
      sortOrder: sortOrder,
    );

List<String> _ids(List<CanvasNode> nodes) => nodes.map((n) => n.id).toList();

void main() {
  group('orderByNarrativeChain', () {
    test('空输入 → 空输出', () {
      expect(
        orderByNarrativeChain(nodes: const [], edges: const []),
        isEmpty,
      );
    });

    test('单链：a→b→c 按链序,与传入顺序和坐标都无关', () {
      // 传入顺序与 position 都刻意逆着链序,证明排序真来自边而非输入残留。
      final nodes = [
        _node('c', x: 0),
        _node('a', x: 900),
        _node('b', x: 500),
      ];
      final edges = [_edge('e1', 'a', 'b'), _edge('e2', 'b', 'c')];

      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b', 'c']);
    });

    test('只认 narrative 边——data / generation_source 边不参与建链', () {
      final nodes = [_node('b', x: 100), _node('a', x: 0)];
      final edges = [
        _edge('e1', 'b', 'a', type: EdgeType.data),
        _edge('e2', 'b', 'a', type: EdgeType.generationSource),
      ];

      // 两个节点都不在 narrative 图里 → 全部走「剩余按 position 追加」。
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b']);
    });

    test('多链：链头按 (dx, dy, id) 排,链内保持链序', () {
      final nodes = [
        _node('b1', x: 999),
        _node('a1', x: 100, y: 0),
        _node('b0', x: 0, y: 50),
        _node('a0', x: 0, y: 0),
      ];
      final edges = [_edge('e1', 'a0', 'b0'), _edge('e2', 'a1', 'b1')];

      // a0 (0,0) 先于 a1 (100,0);各自链整体连续,不交错。
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a0', 'b0', 'a1', 'b1']);
    });

    test('同坐标时按 id 兜底,保证确定性全序', () {
      final nodes = [_node('zz'), _node('aa')];
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: const [])),
          ['aa', 'zz']);
    });

    test('分叉：同源多出边按 sortOrder 排,深度优先走完一支再走下一支', () {
      final nodes = [
        _node('a'),
        _node('b'),
        _node('b2'),
        _node('c'),
      ];
      final edges = [
        _edge('e2', 'a', 'c', sortOrder: 5),
        _edge('e1', 'a', 'b', sortOrder: 1),
        _edge('e3', 'b', 'b2'),
      ];

      // sortOrder 1 的 b 支先走,且走到底(b2)才回头取 c——不是逐层 BFS。
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b', 'b2', 'c']);
    });

    test('分叉：sortOrder 平手时按边 id 兜底', () {
      final nodes = [_node('a'), _node('x'), _node('y')];
      final edges = [
        _edge('e9', 'a', 'x', sortOrder: 3),
        _edge('e1', 'a', 'y', sortOrder: 3),
      ];

      // 两条边 sortOrder 相同 → 比边 id：e1 < e9,故 y 先于 x。
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'y', 'x']);
    });

    test('汇合(菱形)：共同后继只出现一次,visited 不产生重复', () {
      final nodes = [_node('a'), _node('b'), _node('c'), _node('d')];
      final edges = [
        _edge('e1', 'a', 'b', sortOrder: 0),
        _edge('e2', 'a', 'c', sortOrder: 1),
        _edge('e3', 'b', 'd'),
        _edge('e4', 'c', 'd'),
      ];

      final out = _ids(orderByNarrativeChain(nodes: nodes, edges: edges));
      expect(out, ['a', 'b', 'd', 'c']);
      expect(out.toSet().length, out.length, reason: '不得重复输出同一节点');
    });

    test('环：纯环无入度 0 链头,整环走「剩余」兜底,不死循环不丢节点', () {
      final nodes = [_node('a', x: 0), _node('b', x: 10), _node('c', x: 20)];
      final edges = [
        _edge('e1', 'a', 'b'),
        _edge('e2', 'b', 'c'),
        _edge('e3', 'c', 'a'),
      ];

      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b', 'c']);
    });

    test('带尾环：链头可达部分照走链序,环内节点被 visited 收住', () {
      // a→b→c→b：从 a 出发能走到 b、c,c 回指 b 时 b 已 visited。
      final nodes = [_node('a'), _node('b'), _node('c')];
      final edges = [
        _edge('e1', 'a', 'b'),
        _edge('e2', 'b', 'c'),
        _edge('e3', 'c', 'b'),
      ];

      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b', 'c']);
    });

    test('孤立节点排在所有链之后,内部按 (dx, dy, id)', () {
      final nodes = [
        _node('lonely2', x: 50, y: 10),
        _node('a', x: 900),
        _node('lonely1', x: 50, y: 0),
        _node('b', x: 950),
      ];
      final edges = [_edge('e1', 'a', 'b')];

      // 链(a→b)在前——即便 a 的 x 远大于两个孤立节点。
      expect(_ids(orderByNarrativeChain(nodes: nodes, edges: edges)),
          ['a', 'b', 'lonely1', 'lonely2']);
    });

    test('指向不存在节点的悬空边被忽略,不炸也不凭空造节点', () {
      final nodes = [_node('a'), _node('b', x: 10)];
      final edges = [
        _edge('e1', 'a', 'ghost'),
        _edge('e2', 'ghost', 'b'),
      ];

      final out = orderByNarrativeChain(nodes: nodes, edges: edges);
      expect(_ids(out), ['a', 'b']);
    });

    test('include 只过滤输出,不打断链序（EX-1′ 的用法）', () {
      final nodes = [
        _node('shot1'),
        _node('shot2'),
        _node('shot3'),
      ];
      final edges = [
        _edge('e1', 'shot1', 'shot2'),
        _edge('e2', 'shot2', 'shot3'),
      ];

      // 滤掉链中间的 shot2：剩下两个仍保持 shot1 → shot3 的链相对序,
      // 而不是退化成按 id/position 重排。
      final out = orderByNarrativeChain(
        nodes: nodes,
        edges: edges,
        include: (n) => n.id != 'shot2',
      );
      expect(_ids(out), ['shot1', 'shot3']);
    });

    test('include 为 null 时全量输出', () {
      final nodes = [_node('a'), _node('b', x: 10)];
      expect(
        orderByNarrativeChain(nodes: nodes, edges: const []).length,
        2,
      );
    });

    test('全序不变量：任意形态下输出都是输入的一个排列', () {
      final nodes = [
        _node('n1', x: 0),
        _node('n2', x: 10),
        _node('n3', x: 20),
        _node('n4', x: 30),
        _node('n5', x: 40),
      ];
      final edges = [
        _edge('e1', 'n1', 'n2'), // 链
        _edge('e2', 'n3', 'n4'), // 另一链
        _edge('e3', 'n4', 'n3'), // 制造环
        _edge('e4', 'n2', 'nope'), // 悬空
      ];

      final out = orderByNarrativeChain(nodes: nodes, edges: edges);
      expect(out.length, nodes.length);
      expect(_ids(out).toSet(), _ids(nodes).toSet());
    });
  });
}
