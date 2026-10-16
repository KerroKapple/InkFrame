// take 号：素材页（widgets/left_rail/assets_model.dart 的格子标签）与检查器历史页（widgets/inspector_history_panel.dart）
// 共用的那一个编号函数，两处的号不会走岔。
//
// 放在 util 而不是素材页的 model 里：检查器不该为了一个编号函数去 import 左栏素材页的文件。
import '../models/canvas_node.dart';
import 'node_artifacts.dart';

/// take 号——素材页的格子标签与检查器历史页共用这一个函数，两处的号不会走岔。
///
/// 同一来源（result 节点的 sourceNodeId，即它的配置节点）名下有产物的 result 节点按生成时间正序编号，
/// 最早的是 take 1；「有产物」「谁先谁后」都照 [resultsFor]（产物 url 非空；按 created_at，缺戳的垫底）。
/// 名下只有一个的不进表——它是「成片」，两处都不写号；没有来源的孤儿产物也不进表（各自成片）。
/// 批量 slot 不是 result 节点，不参与；批量的 result 容器转正之前没有产物 url，同样不参与。
/// [nodes] 是同一张画布的节点。
Map<String, int> takeNumbersOn(List<CanvasNode> nodes) {
  // 按来源分桶，桶内保持节点列表原序（resultsFor 对缺时间戳的产物按原序定先后）。
  final Map<String, List<CanvasNode>> bySource = <String, List<CanvasNode>>{};
  for (final CanvasNode n in nodes) {
    final String? source = n.sourceNodeId;
    if (n.role != NodeRole.result || source == null) continue;
    (bySource[source] ??= <CanvasNode>[]).add(n);
  }
  final Map<String, int> out = <String, int>{};
  for (final MapEntry<String, List<CanvasNode>> e in bySource.entries) {
    final List<CanvasNode> newestFirst = resultsFor(sourceNodeId: e.key, nodes: e.value);
    if (newestFirst.length < 2) continue;
    for (int i = 0; i < newestFirst.length; i++) {
      out[newestFirst[i].id] = newestFirst.length - i;
    }
  }
  return out;
}
