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

/// 内存 Fake：build 返回 seed，removeNode/restore 就地增删。
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
