// SetCurrentTakeCommand：撤销栈里的「设为当前 · take N」一步。
//
// 快照只有三样：配置节点 id、设之前的固定 id（可为 null = 原来没固定）、设成的固定 id。命令不持控制器，
// revert / apply 时经 env.ref 现取画布节点控制器，写固定只走 CanvasNodesController.patchTypeConfigMany
// （一个事务、失败回滚内存，抛 InkError ⇒ 栈视同 failed）。
//
// 「在不在」自己先查：patchTypeConfigMany 对不在内存的 id 静默跳过、正常返回，不能靠它判 gone。
//   - revert：配置节点已不在 ⇒ gone；旧固定的那张已删 ⇒ 照样写回、done（判据自然回落最新）。
//   - apply ：配置节点或新固定的那张已不在 ⇒ gone。
//
// 不碰任何边：下游 data 边跟着当前 take 挪归 W5 tc-take-edge-follow，挪边信息记在 W4 抽出的 PinToken 里，
// 命令本身不带边（也不预留字段）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/take_keys.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../canvas_command.dart';
import '../canvas_node.dart';

class SetCurrentTakeCommand extends CanvasCommand {
  const SetCurrentTakeCommand({
    required this.configNodeId,
    required this.previousPinnedResultId,
    required this.pinnedResultId,
    required this.takeNumber,
  });

  /// 被改固定的配置节点。
  final String configNodeId;

  /// 设之前的固定 id；null = 原来没固定（撤销时写 JSON null，回落最新）。
  final String? previousPinnedResultId;

  /// 设成当前的那张产物。
  final String pinnedResultId;

  /// 它的 take 号；null = 名下只有一个（「成片」，步名不写号）。
  final int? takeNumber;

  @override
  String label(AppLocalizations l) {
    final int? n = takeNumber;
    return n == null ? l.takeSetCurrent : l.canvasCommandSetCurrentTake(n);
  }

  @override
  Set<String> get affectedNodeIds => <String>{configNodeId, pinnedResultId};

  @override
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env) async {
    final Set<String> present = _presentIds(env);
    if (!present.contains(configNodeId)) return CanvasCommandOutcome.gone;
    await _writePin(env, previousPinnedResultId);
    return CanvasCommandOutcome.done;
  }

  @override
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env) async {
    final Set<String> present = _presentIds(env);
    if (!present.contains(configNodeId) || !present.contains(pinnedResultId)) {
      return CanvasCommandOutcome.gone;
    }
    await _writePin(env, pinnedResultId);
    return CanvasCommandOutcome.done;
  }

  /// 画布此刻在内存里的节点 id（软删的不在 listByCanvas 里，也就不在这里）。
  static Set<String> _presentIds(CanvasCommandEnv env) => <String>{
        for (final CanvasNode n
            in env.ref.read(canvasNodesControllerProvider(env.canvasId)).valueOrNull ??
                const <CanvasNode>[])
          n.id,
      };

  /// 写配置节点的固定 id；null 写 JSON null（与 jsonb `||` 一致，不删键——读的一侧把 null 当没固定）。
  Future<void> _writePin(CanvasCommandEnv env, String? pin) => env.ref
      .read(canvasNodesControllerProvider(env.canvasId).notifier)
      .patchTypeConfigMany(<String, Map<String, Object?>>{
        configNodeId: <String, Object?>{TakeKeys.pinnedResultId: pin},
      });
}
