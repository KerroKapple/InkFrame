// 画布层的内存 Fake 集合（从 canvas_shortcuts_test.dart 提取，T8）。
//
// 提取动机：外壳级的 V1/V2 端到端用例（shell_keepalive_test.dart /
// shell_focus_test.dart）需要一个「有节点、不碰磁盘、不碰内嵌 PG」的画布，
// 与 canvas_shortcuts_test.dart 的需求逐字相同。复制一份会让两处的节点表
// 悄悄漂移——V2 断言 findsNWidgets(2) 依赖的正是「twoNodes 恰好两个」。
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';

/// 内存 Fake：build 返回 seed，removeNode / restore / removeNodes / restoreAll 就地增删，
/// moveNodes 就地挪。
class FakeNodesController extends CanvasNodesController {
  FakeNodesController(this._seed);
  final List<CanvasNode> _seed;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? removed;
    for (final CanvasNode n in previous) {
      if (n.id == id) removed = n;
    }
    state = AsyncData(
      previous.where((n) => n.id != id).toList(growable: false),
    );
    if (removed == null) return null;
    return (node: removed, edgeIds: const <String>[]);
  }

  @override
  Future<void> restore(NodeDeletion deletion) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData([...previous, deletion.node]);
  }

  /// 整批删除：内存就地移除，按 [ids] 顺序给在内存里的节点各一个令牌（无边）。
  @override
  Future<List<NodeDeletion>> removeNodes(Set<String> ids) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final Map<String, CanvasNode> byId = <String, CanvasNode>{
      for (final CanvasNode n in previous) n.id: n,
    };
    state = AsyncData(
      previous.where((n) => !ids.contains(n.id)).toList(growable: false),
    );
    return <NodeDeletion>[
      for (final String id in ids)
        if (byId.containsKey(id)) (node: byId[id]!, edgeIds: const <String>[]),
    ];
  }

  /// 整批复原：内存里已经在的不重复插入；返回实际插回的节点数。
  @override
  Future<int> restoreAll(List<NodeDeletion> deletions) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    final Set<String> present = <String>{for (final CanvasNode n in previous) n.id};
    final List<CanvasNode> back = <CanvasNode>[
      for (final NodeDeletion d in deletions)
        if (present.add(d.node.id)) d.node,
    ];
    state = AsyncData([...previous, ...back]);
    return back.length;
  }

  /// 整组挪动：内存就地改位置 + 泳道（laneId 为 null 即移出泳道）。
  @override
  Future<void> moveNodes(Map<String, NodeMove> moves) async {
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData([
      for (final CanvasNode n in previous)
        if (moves.containsKey(n.id))
          n.copyWith(
            position: n.position + moves[n.id]!.delta,
            laneId: moves[n.id]!.laneId,
            clearLaneId: moves[n.id]!.laneId == null,
          )
        else
          n,
    ]);
  }
}

/// 在 [FakeNodesController] 上记下建 / 挪节点的调用，不碰仓储、也不改内存态：
/// I / G / T 快捷键与平移工具的用例只关心「调没调、调的是谁」，新卡片怎么渲染
/// 不归它们管（少画几张卡，少一处与本用例无关的失败面）。
class RecordingNodesController extends FakeNodesController {
  RecordingNodesController(super.seed);

  /// addNode 收到的节点类型，按调用顺序。
  final List<CanvasNodeType> added = <CanvasNodeType>[];

  /// moveNode 收到的节点 id，按调用顺序（拖拽落点）。
  final List<String> moved = <String>[];

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add(type);
    return CanvasNode(
      id: 'added-${added.length}',
      label: label,
      type: type,
      role: role,
      canvasId: arg,
      position: position,
    );
  }

  @override
  Future<void> moveNode(
    String id,
    Offset delta, {
    required String? laneId,
  }) async {
    moved.add(id);
  }

  /// moveNodes 收到的整批挪法，按调用顺序（与 moveNode 一样只记不改内存）。
  final List<Map<String, NodeMove>> movedBatches = <Map<String, NodeMove>>[];

  @override
  Future<void> moveNodes(Map<String, NodeMove> moves) async {
    movedBatches.add(Map<String, NodeMove>.of(moves));
  }
}

class FakeEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

class EmptyLanesController extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => const <StyleLane>[];
}

/// NodeCard 通过 fileResolverServiceProvider 解析缩略图；用桩隔离磁盘/appPaths。
class StubFileResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) => throw UnimplementedError();

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) => File(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}__inkframe_missing__'
    '${Platform.pathSeparator}$relativePath',
  );

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory(
        '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}__inkframe_missing__',
      );
}

/// 固定尺寸的文本节点（不触发任何图片/视频加载路径）。
CanvasNode textNode(String id, String label, double x, {String canvasId = 'c1'}) =>
    CanvasNode(
      id: id,
      label: label,
      type: CanvasNodeType.text,
      canvasId: canvasId,
      position: Offset(x, 40),
      size: const Size(180, 120),
    );

/// 两个文本节点 'a' / 'b'——V2 的 findsNWidgets(2) 直接锚在这个基数上。
final List<CanvasNode> twoNodes = <CanvasNode>[
  textNode('a', 'Node A', 40),
  textNode('b', 'Node B', 320),
];
