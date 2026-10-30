// DeleteNodesCommand：撤销栈里的「删除 N 个节点」——连带删掉的线一起撤 / 重做。
//
// 进栈时机：canvas_node_delete.dart 的 removeNode / removeNodes 做成之后，拿它们返回的撤销令牌
// （NodeDeletion：节点快照 + 同事务级联软删的边 id）建本命令再 record。
//
// - revert：一次 restoreAll（一个事务放回全部节点与边）。受影响行全 0（行已被硬删 / 画布已关）⇒ gone；
//   抛 InkError ⇒ failed（步留栈顶）；否则 done。done 且令牌里有导入节点 ⇒ 让节点控制器失效重载：
//   复制途中被删的导入壳，令牌快照里没有 url，库里已由导入控制器补上，不重载就看不到图。
// - apply（重做）：只删此刻还在内存里的那些，一次 removeNodes，并换成这次删出来的新令牌——
//   下一次撤销要复原的是这次级联软删的边，不是第一次那批；一个都不在 ⇒ gone。
//
// 令牌在重做后会被替换，所以本类不是 const；令牌本身仍是快照（不持控制器引用）。
// 撤销删除时节点原来的泳道已被删：照旧复原 lane_id（与 restoreAll 现状相同），留给 undo-lanes。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/ink_error.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../canvas_command.dart';
import '../canvas_node.dart';
import '../canvas_node_import.dart';

class DeleteNodesCommand extends CanvasCommand {
  DeleteNodesCommand(List<NodeDeletion> deletions)
      : _deletions = List<NodeDeletion>.unmodifiable(deletions),
        _order = List<String>.unmodifiable(
          <String>[for (final NodeDeletion d in deletions) d.node.id],
        );

  /// 当前这批撤销令牌：重做之后换成重做那次删出来的。
  List<NodeDeletion> _deletions;

  /// 被删节点 id，按第一次删除时的顺序（重做时按这个顺序再删）。
  final List<String> _order;

  @override
  Set<String> get affectedNodeIds => _order.toSet();

  @override
  String label(AppLocalizations l) =>
      l.canvasCommandDeleteNodes(affectedNodeIds.length);

  @override
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env) async {
    final CanvasNodesController nodes =
        env.ref.read(canvasNodesControllerProvider(env.canvasId).notifier);
    final List<NodeDeletion> tokens = _deletions;
    final int restored;
    try {
      restored = await nodes.restoreAll(tokens);
    } on InkError catch (_) {
      return CanvasCommandOutcome.failed;
    }
    // 行全没了（被硬删 / 画布已关）：这一步作废。
    if (restored == 0) return CanvasCommandOutcome.gone;
    if (tokens.any((NodeDeletion d) => d.node.isImported)) {
      env.ref.invalidate(canvasNodesControllerProvider(env.canvasId));
    }
    return CanvasCommandOutcome.done;
  }

  @override
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env) async {
    final List<CanvasNode> current =
        env.ref.read(canvasNodesControllerProvider(env.canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final Set<String> present = <String>{
      for (final CanvasNode n in current) n.id,
    };
    final Set<String> ids = <String>{
      for (final String id in _order)
        if (present.contains(id)) id,
    };
    if (ids.isEmpty) return CanvasCommandOutcome.gone;
    final List<NodeDeletion> next;
    try {
      next = await env.ref
          .read(canvasNodesControllerProvider(env.canvasId).notifier)
          .removeNodes(ids);
    } on InkError catch (_) {
      return CanvasCommandOutcome.failed;
    }
    if (next.isEmpty) return CanvasCommandOutcome.gone;
    _deletions = List<NodeDeletion>.unmodifiable(next);
    return CanvasCommandOutcome.done;
  }
}
