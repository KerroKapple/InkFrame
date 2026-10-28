// softDeleteNodesWithEdges（util/node_soft_delete.dart）：批量删节点与删除泳道和内容共用的「列边去重 →
// 先边后节点软删」。用记账 fake 记下每一次仓储调用的先后。
//
// 变异对照：去掉 seen 去重 ⇒「共用的边只软删一次」红；第二段先删节点后删边 ⇒「边全在节点之前」红；
// 交错成「列一张删一张」⇒「先列完再删」红；返回的表不按入参顺序 / 不归第一个列到它的节点 ⇒「归属」红。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/util/node_soft_delete.dart';

import '../../../_harness/fake_unit_of_work.dart';

/// 入 / 出边按节点给定；softDelete 后的边不再从 list* 里返回（同真库的软删过滤）。
class _RecordingEdges extends Fake implements EdgeRepository {
  _RecordingEdges(this.log, this.edges);

  final List<String> log;

  /// 边 id → (source, target)。
  final Map<String, (String, String)> edges;
  final Set<String> _deleted = <String>{};

  List<Map<String, Object?>> _where(bool Function((String, String) e) test) =>
      <Map<String, Object?>>[
        for (final MapEntry<String, (String, String)> e in edges.entries)
          if (!_deleted.contains(e.key) && test(e.value)) <String, Object?>{'id': e.key},
      ];

  @override
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId) async {
    log.add('listOut:$sourceNodeId');
    return _where((e) => e.$1 == sourceNodeId);
  }

  @override
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId) async {
    log.add('listIn:$targetNodeId');
    return _where((e) => e.$2 == targetNodeId);
  }

  @override
  Future<int> softDelete(String id) async {
    log.add('edge:$id');
    return _deleted.add(id) ? 1 : 0;
  }
}

class _RecordingNodes extends Fake implements NodeRepository {
  _RecordingNodes(this.log);

  final List<String> log;

  @override
  Future<int> softDelete(String id) async {
    log.add('node:$id');
    return 1;
  }
}

void main() {
  late List<String> log;
  late FakeRepositoryScope scope;

  setUp(() {
    log = <String>[];
    scope = FakeRepositoryScope(
      nodes: _RecordingNodes(log),
      edges: _RecordingEdges(log, <String, (String, String)>{
        'e_ab': ('a', 'b'), // a、b 共用
        'e_xa': ('x', 'a'), // 只连 a
        'e_by': ('b', 'y'), // 只连 b
        'e_xy': ('x', 'y'), // 与 a、b 都无关
      }),
    );
  });

  test('两个节点共用的边只软删一次', () async {
    await softDeleteNodesWithEdges(scope, <String>['a', 'b']);
    expect(log.where((l) => l == 'edge:e_ab'), hasLength(1));
    expect(log.where((l) => l.startsWith('edge:')).toSet(),
        <String>{'edge:e_ab', 'edge:e_xa', 'edge:e_by'});
    expect(log, isNot(contains('edge:e_xy')));
  });

  test('边全在节点之前软删', () async {
    await softDeleteNodesWithEdges(scope, <String>['a', 'b']);
    final lastEdge = log.lastIndexWhere((l) => l.startsWith('edge:'));
    final firstNode = log.indexWhere((l) => l.startsWith('node:'));
    expect(firstNode, greaterThan(lastEdge));
    expect(log.where((l) => l.startsWith('node:')).toList(), <String>['node:a', 'node:b']);
  });

  test('先列完全部边再删（列边全在任何软删之前）', () async {
    await softDeleteNodesWithEdges(scope, <String>['a', 'b']);
    final lastList = log.lastIndexWhere((l) => l.startsWith('list'));
    final firstWrite =
        log.indexWhere((l) => l.startsWith('edge:') || l.startsWith('node:'));
    expect(firstWrite, greaterThan(lastList));
  });

  test('归属：键序 = 入参顺序，共用的边归第一个列到它的节点', () async {
    final planned = await softDeleteNodesWithEdges(scope, <String>['b', 'a']);
    expect(planned.keys.toList(), <String>['b', 'a']);
    expect(planned['b'], unorderedEquals(<String>['e_ab', 'e_by']));
    expect(planned['a'], <String>['e_xa']);
  });

  test('没有节点 ⇒ 不碰库、返回空表', () async {
    final planned = await softDeleteNodesWithEdges(scope, const <String>[]);
    expect(planned, isEmpty);
    expect(log, isEmpty);
  });
}
