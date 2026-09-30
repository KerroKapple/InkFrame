// 序列 lens 的 provider：按 canvasId 分族，watch 节点 + 边控制器（画布常驻订阅时即已加载）。
// 两个控制器任一未就绪 ⇒ 空 lens（不阻塞界面，列表空态自会呈现）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_edges_controller.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../models/sequence_lens.dart';

final sequenceLensProvider = Provider.autoDispose.family<SequenceLens, String>(
  (ref, canvasId) {
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
    final List<CanvasEdge> edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[];
    return buildSequenceLens(nodes: nodes, edges: edges);
  },
  name: 'sequenceLensProvider',
);
