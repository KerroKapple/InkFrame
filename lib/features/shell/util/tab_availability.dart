// 标签可用性判据——【原样搬运】自已删除的 canvas_top_chrome.dart：
// _SequencePreviewButton._hasNarrative / _ExportVideoButton._canExport。
//
// 抽成纯函数而非在标签体里重写：重写会悄悄改变禁用条件，而
// canvas_top_chrome_{sequence,export}_test.dart 搬过去的那批用例正是靠这两条判据
// 定义"禁用"的含义。两者与删除同一个 commit，中间不存在判据缺失的版本。
//
// 都写成顶层函数（而非闭包）以便直接喂给 provider.select(...)：select 要求
// 传入的函数在多次 build 之间 identical，方法 tear-off 满足这一点。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../export/util/export_order.dart';

/// 画布上是否存在 narrative 边。门控只看【边】不看节点：没有叙事链就没有
/// "序列"可言，而画布上有一堆互不相连的节点是常态。
bool hasNarrativeEdges(AsyncValue<List<CanvasEdge>> async) =>
    (async.valueOrNull ?? const <CanvasEdge>[])
        .any((CanvasEdge e) => e.edgeType == EdgeType.narrative);

/// 画布上是否有可导出的 video result（且带得出 projectId）。
bool canExportVideo(AsyncValue<List<CanvasNode>> async) {
  final List<CanvasNode> videoNodes =
      exportableVideoNodes(async.valueOrNull ?? const <CanvasNode>[]);
  return videoNodes.isNotEmpty && videoNodes.first.projectId != null;
}
