// DeleteEdgeCommand：撤销栈里的「删除连线」（舞台上选中线的 ✕、检查器入边区的「移除」，见
// util/canvas_edge_delete.dart）。
//
// 反向找边按两端 + 类型（EdgeEndpoints），不按边 id：撤销重建 / 用户重连出来的线 id 都会变。
// - revert：在世边里已有同两端的 ⇒ 视为已复原、done，不再写库（再 restore 会撞 uq_edges_live 23505）；
//   任一端节点已不在 ⇒ gone；否则 restore(快照)——沿用 restore 里首 / 尾帧的降级逻辑。
// - apply（重做）：按两端找到在世的那条 ⇒ removeEdge(它的 id) 并把快照换成它；找不到 ⇒ gone。
// 快照在重做后会换，所以本类不是 const。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/ink_error.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../providers/canvas_edges_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../canvas_command.dart';
import '../canvas_edge.dart';
import '../canvas_node.dart';
import '../edge_endpoints.dart';

class DeleteEdgeCommand extends CanvasCommand {
  DeleteEdgeCommand(CanvasEdge removed)
      : _snapshot = removed,
        _key = EdgeEndpoints.of(removed);

  /// 复原用的快照：重做之后换成重做那次删掉的那条。
  CanvasEdge _snapshot;

  /// 这条线的身份：两端 + 类型（role 只给复原用、不参与匹配）。
  final EdgeEndpoints _key;

  @override
  Set<String> get affectedNodeIds =>
      <String>{_key.sourceNodeId, _key.targetNodeId};

  @override
  String label(AppLocalizations l) => l.canvasCommandDeleteEdge;

  @override
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env) async {
    final List<CanvasEdge> live =
        env.ref.read(canvasEdgesControllerProvider(env.canvasId)).valueOrNull ??
            const <CanvasEdge>[];
    // 同两端已经有一条在世的（撤销之前用户又连上了）：就当已复原。
    if (findEdgeByEndpoints(live, _key) != null) {
      return CanvasCommandOutcome.done;
    }
    final List<CanvasNode> nodes =
        env.ref.read(canvasNodesControllerProvider(env.canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final Set<String> present = <String>{for (final CanvasNode n in nodes) n.id};
    if (!present.contains(_key.sourceNodeId) ||
        !present.contains(_key.targetNodeId)) {
      return CanvasCommandOutcome.gone;
    }
    try {
      await env.ref
          .read(canvasEdgesControllerProvider(env.canvasId).notifier)
          .restore(_snapshot);
    } on InkError catch (_) {
      return CanvasCommandOutcome.failed;
    }
    return CanvasCommandOutcome.done;
  }

  @override
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env) async {
    final List<CanvasEdge> live =
        env.ref.read(canvasEdgesControllerProvider(env.canvasId)).valueOrNull ??
            const <CanvasEdge>[];
    final CanvasEdge? found = findEdgeByEndpoints(live, _key);
    if (found == null) return CanvasCommandOutcome.gone;
    final CanvasEdge? removed;
    try {
      removed = await env.ref
          .read(canvasEdgesControllerProvider(env.canvasId).notifier)
          .removeEdge(found.id);
    } on InkError catch (_) {
      return CanvasCommandOutcome.failed;
    }
    if (removed == null) return CanvasCommandOutcome.gone;
    _snapshot = removed;
    return CanvasCommandOutcome.done;
  }
}
