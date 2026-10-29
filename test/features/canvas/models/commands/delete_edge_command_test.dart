// DeleteEdgeCommand：撤销栈里的「删除连线」。反向找边按两端 + 类型（EdgeEndpoints），不按边 id。
//
// 装置：ProviderContainer + 本地 _Env；节点控制器 = FakeNodesController，边控制器 = 本文件就地写的 _Edges
// （harness 的 FakeEdgesController 只有 build）。两个都先挂订阅（autoDispose）再等加载完。
//
// 变异对照：
// - apply 改成按快照 id removeEdge ⇒「边被重连换了 id 仍删中」红；
// - revert 删掉在世边预检 ⇒「同两端已有在世边 ⇒ done 且不调 restore」红；
// - revert 删掉端点在不在的判断 ⇒「端点节点已删 ⇒ gone」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/commands/delete_edge_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../../_harness/fake_canvas.dart';

const String _c1 = 'c1';

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _zh = lookupAppLocalizations(const Locale('zh'));

class _Env implements CanvasCommandEnv {
  _Env(this.canvasId, this.ref);

  @override
  final String canvasId;

  @override
  final Ref ref;
}

final Provider<CanvasCommandEnv> _envProvider =
    Provider<CanvasCommandEnv>((ref) => _Env(_c1, ref));

/// a → b 的 data 边。
CanvasEdge _edge(String id, {EdgeRole role = EdgeRole.reference}) => CanvasEdge(
      id: id,
      canvasId: _c1,
      sourceNodeId: 'a',
      targetNodeId: 'b',
      edgeType: EdgeType.data,
      role: role,
    );

/// 边：removeEdge / restore 就地改内存并记下调用。
class _Edges extends CanvasEdgesController {
  _Edges(this._seed);

  final List<CanvasEdge> _seed;
  final List<String> removeCalls = <String>[];
  final List<CanvasEdge> restoreCalls = <CanvasEdge>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => _seed;

  @override
  Future<CanvasEdge?> removeEdge(String id) async {
    removeCalls.add(id);
    final List<CanvasEdge> previous = state.valueOrNull ?? const <CanvasEdge>[];
    CanvasEdge? hit;
    for (final CanvasEdge e in previous) {
      if (e.id == id) hit = e;
    }
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[
      for (final CanvasEdge e in previous)
        if (e.id != id) e,
    ]);
    return hit;
  }

  @override
  Future<void> restore(CanvasEdge edge) async {
    restoreCalls.add(edge);
    final List<CanvasEdge> previous = state.valueOrNull ?? const <CanvasEdge>[];
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[...previous, edge]);
  }
}

void main() {
  late _Edges edges;
  late ProviderContainer container;

  Future<void> setUpWith({
    required List<CanvasNode> nodes,
    required List<CanvasEdge> liveEdges,
  }) async {
    edges = _Edges(liveEdges);
    container = ProviderContainer(overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => edges),
    ]);
    addTearDown(container.dispose);
    container.listen(canvasNodesControllerProvider(_c1), (_, _) {});
    container.listen(canvasEdgesControllerProvider(_c1), (_, _) {});
    await container.read(canvasNodesControllerProvider(_c1).future);
    await container.read(canvasEdgesControllerProvider(_c1).future);
  }

  CanvasCommandEnv env() => container.read(_envProvider);

  test('revert：两端都在、没有在世的同两端边 ⇒ restore(快照)', () async {
    await setUpWith(nodes: twoNodes, liveEdges: const <CanvasEdge>[]);
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    expect(edges.restoreCalls.single.id, 'e1');
  });

  test('revert 同两端已有在世边 ⇒ done 且不调 restore', () async {
    // 撤销之前用户又把 a → b 连上了（新 id e2）：再 restore e1 就撞 uq_edges_live。
    await setUpWith(nodes: twoNodes, liveEdges: <CanvasEdge>[_edge('e2')]);
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    expect(edges.restoreCalls, isEmpty);
  });

  test('revert 端点节点已删 ⇒ gone', () async {
    await setUpWith(
      nodes: <CanvasNode>[twoNodes[1]], // 只剩 b
      liveEdges: const <CanvasEdge>[],
    );
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.revert(env()), CanvasCommandOutcome.gone);
    expect(edges.restoreCalls, isEmpty);
  });

  test('apply 按两端找边：边被重连换了 id 仍删中，之后撤销复原的是那一条', () async {
    // 撤销删线后，那条线又被删了、再重连（新 id e9）。
    await setUpWith(nodes: twoNodes, liveEdges: <CanvasEdge>[_edge('e9')]);
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.apply(env()), CanvasCommandOutcome.done);
    expect(edges.removeCalls, <String>['e9']);

    expect(await cmd.revert(env()), CanvasCommandOutcome.done);
    expect(edges.restoreCalls.single.id, 'e9', reason: '重做换了快照，撤销复原换上来的那条');
  });

  test('apply 找不到 ⇒ gone，不调 removeEdge', () async {
    await setUpWith(nodes: twoNodes, liveEdges: const <CanvasEdge>[]);
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.apply(env()), CanvasCommandOutcome.gone);
    expect(edges.removeCalls, isEmpty);
  });

  test('apply 只认类型相同的边：同两端的叙事边不算', () async {
    const CanvasEdge narrative = CanvasEdge(
      id: 'n1',
      canvasId: _c1,
      sourceNodeId: 'a',
      targetNodeId: 'b',
      edgeType: EdgeType.narrative,
    );
    await setUpWith(nodes: twoNodes, liveEdges: const <CanvasEdge>[narrative]);
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(await cmd.apply(env()), CanvasCommandOutcome.gone);
    expect(edges.removeCalls, isEmpty);
  });

  test('label 与受影响节点', () {
    final DeleteEdgeCommand cmd = DeleteEdgeCommand(_edge('e1'));

    expect(cmd.label(_en), 'Delete link');
    expect(cmd.label(_zh), '删除连线');
    expect(cmd.affectedNodeIds, <String>{'a', 'b'});
  });
}
