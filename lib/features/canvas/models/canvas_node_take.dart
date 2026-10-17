// CanvasNode 上与「当前 take」有关的派生属性（canvas_node.dart 是手写类，派生属性写成扩展，不改它）。
//
// 当前 take = 固定的 ?? 最新的；判据在 util/node_artifacts.dart 的 currentResultFor，这里只负责把
// type_config 里的固定 id 读干净。
import '../../../core/constants/take_keys.dart';
import 'canvas_node.dart';

extension CanvasNodeTake on CanvasNode {
  /// 配置节点固定的产物 id（type_config['pinned_result_id']）。
  /// 非空字符串才算；缺键 / null / 空串 / 非字符串一律当没固定，返回 null。
  String? get pinnedResultId {
    final Object? v = typeConfig[TakeKeys.pinnedResultId];
    return v is String && v.isNotEmpty ? v : null;
  }
}

/// 配置节点 id → 它固定的产物 id。只收 role == config 且有固定的节点；固定的产物是否还活着
/// 不在这里判（由 currentResultFor 在候选里找，找不到就回落最新）。
Map<String, String> pinnedResultIdsBySource(Iterable<CanvasNode> nodes) => <String, String>{
      for (final CanvasNode n in nodes)
        if (n.role == NodeRole.config)
          if (n.pinnedResultId case final String pin) n.id: pin,
    };
