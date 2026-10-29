// MoveNodesCommand：撤销栈里的「挪动节点」——目前进栈的只有拖动换道（「移入 / 移出泳道「X」」，
// widgets/stage/node_card_slot.dart）；不换道的普通拖动、整组拖动由后续切片复用本命令（label 用 move）。
//
// 只持快照：每张卡挪动前 / 后的世界坐标 + 泳道（[NodePlacement]，与 util/drop_placement.dart 同一个类型）。
// - revert：对此刻还在内存里的 id，位移 = before 位置 − 此刻位置、泳道 = before 的道，一次 moveNodes 整批落库
//   ——期间被别处挪过也回得去；一个都不在 ⇒ gone；抛 InkError ⇒ failed。
// - apply：同上，换成 after。
//
// 步名里的泳道名是快照时的**原始** label（没起名 = 空串 / 道已不在 = null），到 [label] 时才落成当前语言的
// 「未命名泳道」——在 record 时就本地化会把那一刻的语言冻进命令。
import '../../../../core/errors/ink_error.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../util/drop_placement.dart';
import '../canvas_command.dart';
import '../canvas_node.dart';

/// 步名的种类：普通移动（按张数）/ 移入某道 / 移出某道。
enum MoveNodesLabelKind { move, intoLane, outOfLane }

/// 步名的原料：种类 + 泳道原始名（null / 空 ⇒ 显示时写「未命名泳道」）。
typedef MoveNodesLabel = ({MoveNodesLabelKind kind, String? laneName});

class MoveNodesCommand extends CanvasCommand {
  const MoveNodesCommand({
    required this.before,
    required this.after,
    required MoveNodesLabel label,
  }) : labelSpec = label;

  /// 每张卡挪动之前的位置与泳道。
  final Map<String, NodePlacement> before;

  /// 每张卡挪动之后的位置与泳道。
  final Map<String, NodePlacement> after;

  /// 步名原料。不叫 `label`：会和 [label] 方法撞名。
  final MoveNodesLabel labelSpec;

  @override
  Set<String> get affectedNodeIds => before.keys.toSet();

  @override
  String label(AppLocalizations l) {
    final String? raw = labelSpec.laneName;
    final String lane = raw == null || raw.isEmpty ? l.laneUntitled : raw;
    return switch (labelSpec.kind) {
      MoveNodesLabelKind.move => l.canvasCommandMoveNodes(before.length),
      MoveNodesLabelKind.intoLane => l.canvasCommandMoveIntoLane(lane),
      MoveNodesLabelKind.outOfLane => l.canvasCommandMoveOutOfLane(lane),
    };
  }

  @override
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env) =>
      _moveTo(env, before);

  @override
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env) =>
      _moveTo(env, after);

  /// 把此刻还在的卡挪到 [target] 写的位置与泳道：位移按「目标 − 此刻」算，一次 moveNodes。
  static Future<CanvasCommandOutcome> _moveTo(
    CanvasCommandEnv env,
    Map<String, NodePlacement> target,
  ) async {
    final List<CanvasNode> current =
        env.ref.read(canvasNodesControllerProvider(env.canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final Map<String, NodeMove> moves = <String, NodeMove>{
      for (final CanvasNode n in current)
        if (target.containsKey(n.id))
          n.id: (
            delta: target[n.id]!.world - n.position,
            laneId: target[n.id]!.laneId,
          ),
    };
    if (moves.isEmpty) return CanvasCommandOutcome.gone;
    try {
      await env.ref
          .read(canvasNodesControllerProvider(env.canvasId).notifier)
          .moveNodes(moves);
    } on InkError catch (_) {
      return CanvasCommandOutcome.failed;
    }
    return CanvasCommandOutcome.done;
  }
}
