// CurrentTakeController：「设为当前」的唯一执行口——检查器历史页每行、产物检查器动作行、take 卡右键菜单、
// 新 take 完成通知卡上的「设为当前」都走 [CurrentTakeController.setCurrent]。
//
// 一次设为当前 = 写配置节点的 type_config.pinned_result_id（CanvasNodesController.patchTypeConfigMany，一个事务、
// 失败回滚内存）→ 入撤销栈一步（SetCurrentTakeCommand，名「设为当前 · take N」）→ 画布底部胶囊同文案 +「撤销」。
// 序列 / 导出默认勾选 / 画廊 / ⌘K / 大纲都经 currentResultFor 读这个键，写完立即跟随。
//
// 规则：
//   - 已是当前（含「没固定、它是最新」）⇒ alreadyCurrent：不写库、不入栈、不出胶囊。
//   - 来源配置节点不在（孤儿产物 / 来源已删）或产物本身不在 ⇒ noSource。
//   - 写库失败 ⇒ 内存已由 patchTypeConfigMany 回滚；出错误卡（InkError 的本地化即通用写失败文案），不入栈、
//     不出胶囊，返回 failed；再点一次可重试。
//   - 胶囊的「撤销」= runCanvasUndoStep(stepId)：与 Ctrl Z 同一条后效（gone / failed 的反馈一致），不直接调栈。
//     不设 dedupeKey——kCanvasHistoryCapsuleKey 是撤销 / 重做结果胶囊的键，别占。
//
// 画布没开着时（通知卡隔很久才点）：入口先挂一个订阅保活节点控制器、等它加载完，再照常写库、入那张画布的撤销栈
// （撤销栈按 canvasId 分族、keepAlive；胶囊画在那张不可见的画布上，没人看也无妨）。
//
// 控制器内只 read、不 watch 任何 provider：胶囊回调可能在本 provider 被 autoDispose 回收之后才触发，
// 那时仍要能用 ref.read（没有 watch 过的依赖，ref 就不会「过期」）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/take_keys.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../../settings/util/shortcut_catalog.dart';
import '../models/canvas_node.dart';
import '../models/canvas_node_take.dart';
import '../models/commands/set_current_take_command.dart';
import '../util/canvas_history_actions.dart';
import '../util/take_status.dart';
import 'canvas_capsule.dart';
import 'canvas_history_controller.dart';
import 'canvas_nodes_controller.dart';

/// 一次「设为当前」的结果。
enum SetCurrentTakeOutcome {
  /// 写成了、入栈一步、出了胶囊。
  done,

  /// 它本来就是当前：什么也没做。
  alreadyCurrent,

  /// 产物不在，或它没有来源配置节点（孤儿 / 来源已删）：什么也没做。
  noSource,

  /// 写库失败：内存已回滚、出了错误卡、没入栈。
  failed,
}

/// 按 canvasId 分族。
final currentTakeControllerProvider =
    Provider.autoDispose.family<CurrentTakeController, String>(
  (Ref ref, String canvasId) =>
      CurrentTakeController(ref, canvasId),
  name: 'currentTakeControllerProvider',
);

class CurrentTakeController {
  CurrentTakeController(this._ref, this.canvasId);

  final Ref _ref;
  final String canvasId;

  /// 把产物 [resultNodeId] 设为它那一镜的当前 take（见头注）。[l] 由调用方在 await 之前取好。
  Future<SetCurrentTakeOutcome> setCurrent(
    String resultNodeId, {
    required AppLocalizations l,
  }) async {
    // 进行中保护：整段写入期间不让本 provider 被 autoDispose 回收（同 inspector_submit_controller._attemptWrite）。
    final KeepAliveLink link = _ref.keepAlive();
    // 保活节点控制器：画布没开着时它是 autoDispose 的，两次 await 之间会被释放。
    final nodesProvider = canvasNodesControllerProvider(canvasId);
    final ProviderSubscription<AsyncValue<List<CanvasNode>>> keepNodes =
        _ref.listen<AsyncValue<List<CanvasNode>>>(nodesProvider, (_, _) {});
    try {
      final List<CanvasNode> nodes;
      try {
        nodes = await _ref.read(nodesProvider.future);
      } on InkError {
        // 节点表都读不出来：找不到来源，按 noSource 静默（读失败另有画布层的错误面）。
        return SetCurrentTakeOutcome.noSource;
      }
      final CanvasNode? result = _byId(nodes, resultNodeId);
      final String? sourceId = result?.sourceNodeId;
      final CanvasNode? config = sourceId == null ? null : _byId(nodes, sourceId);
      final ResultTakeStatus? status =
          result == null ? null : resultTakeStatusOf(result, nodes);
      if (result == null || config == null || config.role != NodeRole.config || status == null) {
        return SetCurrentTakeOutcome.noSource;
      }
      if (status.current) return SetCurrentTakeOutcome.alreadyCurrent;

      final String? previous = config.pinnedResultId;
      try {
        await _ref.read(nodesProvider.notifier).patchTypeConfigMany(
          <String, Map<String, Object?>>{
            config.id: <String, Object?>{TakeKeys.pinnedResultId: resultNodeId},
          },
        );
      } on InkError catch (e) {
        _ref.read(toastServiceProvider).show(l10nErrorFor(l, e), kind: ToastKind.error);
        return SetCurrentTakeOutcome.failed;
      }

      final SetCurrentTakeCommand command = SetCurrentTakeCommand(
        configNodeId: config.id,
        previousPinnedResultId: previous,
        pinnedResultId: resultNodeId,
        takeNumber: status.number,
      );
      final String stepId =
          _ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(command);
      _showCapsule(command, stepId: stepId, l: l);
      return SetCurrentTakeOutcome.done;
    } finally {
      keepNodes.close();
      link.close();
    }
  }

  /// 胶囊：「设为当前 · take N」+「撤销 <键位>」。点「撤销」= 按步撤销这一步（与 Ctrl Z 同一条后效）。
  void _showCapsule(
    SetCurrentTakeCommand command, {
    required String stepId,
    required AppLocalizations l,
  }) {
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    // 胶囊回调可能在本 provider 回收之后才触发：攥的是 ref.read（只 read 不 watch，回收后照样能用）。
    final ProviderReader read = _ref.read;
    final String id = canvasId;
    _ref.read(canvasCapsuleProvider(canvasId).notifier).show(
          CanvasCapsuleMessage(
            text: command.label(l),
            kind: CanvasCapsuleKind.action,
            actionLabel: l.commonUndo,
            actionHint: canvasBindingLabel(kCanvasUndoBindingId, isMac: isMac),
            onAction: () => unawaited(
              runCanvasUndoStep(read, canvasId: id, stepId: stepId, l: l, isMac: isMac),
            ),
          ),
        );
  }

  static CanvasNode? _byId(List<CanvasNode> nodes, String id) {
    for (final CanvasNode n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}
