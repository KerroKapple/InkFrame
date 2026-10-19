// 画布撤销 / 重做的执行口：快捷键（Ctrl Z · Ctrl Y / ⌘Z · ⇧⌘Z，shortcuts/undo_keys.dart）、空白处右键菜单
// （canvas_menu/undo_menu_items.dart）、⌘K（动作表的撤销 / 重做两行，本文件的 [canvasHistoryAppActions]）与
// 后续撤销卡（[runCanvasUndoStep]）共用这一条路。
//
// 栈本身在 providers/canvas_history_controller.dart（只管换栈、不出 UI，冲挂起写入也在那边做）；这里只管「做完之后」：
//   - done ⇒ 选中受影响的节点里此刻还在的（一个都不在 ⇒ 只把它们从选中里拿掉，其余选中不动）→ 不在视口里就平移过去
//     （缩放不变）→ 画布底部胶囊「已撤销 · <步名>」+「重做 <键位>」（重做反过来：「已重做 · <步名>」+「撤销 <键位>」）。
//     胶囊上的反向按钮只在那一步此刻正好在对面栈顶时给：按步撤销栈中间的一步不进 redo、撤销在途时又登记了新步
//     redo 被清——这两种情形点「重做」重做的不是这一步，干脆不给按钮。
//   - gone ⇒ 胶囊「这一步已无法撤销」（纯文字）：栈已丢掉那一步，不连带撤下一步。
//   - failed ⇒ 错误卡「撤销失败」（通知卡不自动消失，胶囊 2 s 会被错过）；那一步原样留在栈顶，可以再按。
//   - empty / busy ⇒ 静默（栈空按键、撤销在途再按：设计没画反馈，定为都不出）。
// 反馈只走画布底部胶囊（失败卡除外），同一个 dedupeKey，连按只留最新一条。
//
// read 的取法：三个入口一律传 ProviderScope.containerOf(context, listen: false).read——胶囊上的「重做」最多 4 s 后
// 才被点，闭包里不能攥一个那时可能已卸载的 WidgetRef 的 ref.read。测试直接传 container.read。
//
// 「看不看得见」按闭区间判（与 selection_geometry.dart 的 _touches 同口径）：受影响节点的并集只贴着视口边也算
// 看得见、不平移。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../app_actions/app_action.dart';
import '../../app_actions/app_action_ids.dart';
import '../../app_actions/planned_keys.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../../settings/util/shortcut_catalog.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../providers/canvas_capsule.dart';
import '../providers/canvas_history_controller.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/lane_collapse_controller.dart';
import 'lane_geometry.dart';
import 'selection_geometry.dart';
import 'viewport_focus.dart';

/// WidgetRef.read 与 ProviderContainer.read 都能传。
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// 快捷键注册表里撤销 / 重做两条绑定的 id（菜单行尾、胶囊键位按 id 取，与设置「快捷键」页同源）。
const String kCanvasUndoBindingId = 'canvasUndo';
const String kCanvasRedoBindingId = 'canvasRedo';

/// 撤销 / 重做胶囊的 dedupeKey：连按只留最新一条（原地改字，不一张张换）。
const String kCanvasHistoryCapsuleKey = 'canvas-history';

/// 撤销 undo 栈顶那一步，再做后效（见头注）。
Future<CanvasUndoResult> runCanvasUndo(
  ProviderReader read, {
  required String canvasId,
  required AppLocalizations l,
  required bool isMac,
}) async {
  final CanvasUndoResult result =
      await read(canvasHistoryControllerProvider(canvasId).notifier).undo();
  _afterEffects(
    read,
    canvasId: canvasId,
    l: l,
    isMac: isMac,
    result: result,
    undone: true,
  );
  return result;
}

/// 重做 redo 栈顶那一步，再做后效（见头注）。
Future<CanvasUndoResult> runCanvasRedo(
  ProviderReader read, {
  required String canvasId,
  required AppLocalizations l,
  required bool isMac,
}) async {
  final CanvasUndoResult result =
      await read(canvasHistoryControllerProvider(canvasId).notifier).redo();
  _afterEffects(
    read,
    canvasId: canvasId,
    l: l,
    isMac: isMac,
    result: result,
    undone: false,
  );
  return result;
}

/// 按步撤销（撤销卡上的「撤销」：点哪步撤哪步，见 CanvasHistoryController.undoSpecific），后效同 [runCanvasUndo]。
Future<CanvasUndoResult> runCanvasUndoStep(
  ProviderReader read, {
  required String canvasId,
  required String stepId,
  required AppLocalizations l,
  required bool isMac,
}) async {
  final CanvasUndoResult result = await read(
    canvasHistoryControllerProvider(canvasId).notifier,
  ).undoSpecific(stepId);
  _afterEffects(
    read,
    canvasId: canvasId,
    l: l,
    isMac: isMac,
    result: result,
    undone: true,
  );
  return result;
}

/// 撤销那一行的名字：没有可撤的 =「撤销」；有 =「撤销 <步名>」。
String canvasUndoMenuLabel(AppLocalizations l, CanvasHistoryStep? step) =>
    step == null
        ? l.commonUndo
        : l.canvasHistoryUndoStep(step.command.label(l));

/// 重做那一行的名字：没有可重做的 =「重做」；有 =「重做 <步名>」。
String canvasRedoMenuLabel(AppLocalizations l, CanvasHistoryStep? step) =>
    step == null
        ? l.appActionRedo
        : l.canvasHistoryRedoStep(step.command.label(l));

/// 撤销 / 重做之后要不要把相机挪过去：受影响节点的并集 [stageBounds]（舞台坐标）与视口有任何相交（闭区间，
/// 贴边也算）⇒ null，不动；完全在视口外 ⇒ 保持 [current] 的缩放、把并集中心移到视口中心。
/// 视口还没上报尺寸（[viewportSize] 为空）⇒ null。
Matrix4? revealAffectedTransform({
  required Matrix4 current,
  required Size viewportSize,
  required Rect stageBounds,
}) {
  if (viewportSize.isEmpty) return null;
  final Rect visible =
      MatrixUtils.inverseTransformRect(current, Offset.zero & viewportSize);
  if (_touches(visible, stageBounds)) return null;
  return transformCenteringRect(
    current: current,
    viewportSize: viewportSize,
    stageRect: stageBounds,
  );
}

/// 闭区间相交（与 selection_geometry.dart 的 _touches 同口径）。
bool _touches(Rect a, Rect b) =>
    a.left <= b.right &&
    b.left <= a.right &&
    a.top <= b.bottom &&
    b.top <= a.bottom;

/// 一次撤销 / 重做之后的后效。[undone]：true = 撤销（含按步撤销），false = 重做。
void _afterEffects(
  ProviderReader read, {
  required String canvasId,
  required AppLocalizations l,
  required bool isMac,
  required CanvasUndoResult result,
  required bool undone,
}) {
  final CanvasHistoryStep? step = result.step;
  switch (result.status) {
    case CanvasUndoStatus.done:
      if (step == null) return;
      final Set<String> still =
          _selectAffected(read, canvasId, step.command.affectedNodeIds);
      _revealAffected(read, canvasId, still);
      _showDoneCapsule(
        read,
        canvasId: canvasId,
        l: l,
        isMac: isMac,
        step: step,
        undone: undone,
      );
    case CanvasUndoStatus.gone:
      read(canvasCapsuleProvider(canvasId).notifier).show(
        CanvasCapsuleMessage(
          text: l.canvasUndoStepGone,
          dedupeKey: kCanvasHistoryCapsuleKey,
        ),
      );
    case CanvasUndoStatus.failed:
      read(toastServiceProvider).show(l.undoFailed, kind: ToastKind.error);
    case CanvasUndoStatus.empty:
    case CanvasUndoStatus.busy:
      break;
  }
}

/// 选中受影响节点里此刻还在的（替换原选中）；一个都不在 ⇒ 只把它们从选中里拿掉，其余不动。返回还在的那些。
Set<String> _selectAffected(
  ProviderReader read,
  String canvasId,
  Set<String> affected,
) {
  final List<CanvasNode> nodes =
      read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final Set<String> present = <String>{for (final CanvasNode n in nodes) n.id};
  final Set<String> still = <String>{
    for (final String id in affected)
      if (present.contains(id)) id,
  };
  final CanvasSelectionController selection =
      read(canvasSelectionControllerProvider(canvasId).notifier);
  if (still.isEmpty) {
    selection.removeAll(affected);
  } else {
    selection.replace(still);
  }
  return still;
}

/// [ids] 的并集完全不在视口里 ⇒ 平移过去（缩放不变）。并集按当前相机、含分道位移、跳过折叠道里的卡
/// （selection_geometry.dart 的 selectionBounds）；泳道切片 / 方向的取法与 focusNodeOnCanvas、_fitNodes 同。
void _revealAffected(ProviderReader read, String canvasId, Set<String> ids) {
  if (ids.isEmpty) return;
  final List<CanvasNode> nodes =
      read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final TransformationController transform =
      read(canvasTransformControllerProvider(canvasId));
  final Set<String> collapsed = read(laneCollapseProvider(canvasId));
  final List<StyleLane> lanes =
      read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
          const <StyleLane>[];
  // 不在（现存）泳道里的卡没有分道位移，也就不必去读泳道方向。
  final Set<String> laneIds = <String>{for (final StyleLane l in lanes) l.id};
  final bool laned = nodes.any(
    (CanvasNode n) => ids.contains(n.id) && laneIds.contains(n.laneId),
  );
  final LaneDirection direction = laned
      ? (read(canvasLaneDirectionProvider(canvasId)).valueOrNull ??
          LaneDirection.horizontal)
      : LaneDirection.horizontal;
  final Rect? bounds = selectionBounds(
    ids: ids,
    nodes: nodes,
    lanes: laned
        ? collapseLaneSlices(
            <({String id, double size})>[
              for (final StyleLane l in lanes) (id: l.id, size: l.size),
            ],
            collapsed,
          )
        : const <({String id, double size})>[],
    direction: direction,
    transform: transform.value,
    collapsedLaneIds: collapsed,
  );
  if (bounds == null) return;
  final Matrix4? next = revealAffectedTransform(
    current: transform.value,
    viewportSize: read(canvasViewportSizeProvider(canvasId)),
    stageBounds: bounds,
  );
  if (next != null) transform.value = next;
}

/// done 的胶囊：「已撤销 · <步名>」+「重做 <键位>」，或「已重做 · <步名>」+「撤销 <键位>」。
/// 反向按钮只在这一步此刻正好在对面栈顶时给（见头注）。
void _showDoneCapsule(
  ProviderReader read, {
  required String canvasId,
  required AppLocalizations l,
  required bool isMac,
  required CanvasHistoryStep step,
  required bool undone,
}) {
  final String name = step.command.label(l);
  final String text =
      undone ? l.canvasHistoryUndone(name) : l.canvasHistoryRedone(name);
  final CanvasHistoryState history =
      read(canvasHistoryControllerProvider(canvasId));
  final CanvasHistoryStep? opposite =
      undone ? history.redo.lastOrNull : history.undo.lastOrNull;
  final CanvasCapsuleController capsule =
      read(canvasCapsuleProvider(canvasId).notifier);
  if (opposite?.id != step.id) {
    capsule.show(
      CanvasCapsuleMessage(text: text, dedupeKey: kCanvasHistoryCapsuleKey),
    );
    return;
  }
  capsule.show(
    CanvasCapsuleMessage(
      text: text,
      kind: CanvasCapsuleKind.action,
      dedupeKey: kCanvasHistoryCapsuleKey,
      actionLabel: undone ? l.appActionRedo : l.commonUndo,
      actionHint: canvasBindingLabel(
        undone ? kCanvasRedoBindingId : kCanvasUndoBindingId,
        isMac: isMac,
      ),
      onAction: () => unawaited(
        undone
            ? runCanvasRedo(read, canvasId: canvasId, l: l, isMac: isMac)
            : runCanvasUndo(read, canvasId: canvasId, l: l, isMac: isMac),
      ),
    ),
  );
}

// ===== 动作表的撤销 / 重做两行（app_action_catalog.dart 的「编辑」段） =====

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// 执行口的签名（[runCanvasUndo] / [runCanvasRedo]）。
typedef _HistoryRun = Future<CanvasUndoResult> Function(
  ProviderReader read, {
  required String canvasId,
  required AppLocalizations l,
  required bool isMac,
});

/// 撤销 / 重做两行。不在画布上灰着不藏，原因「先打开一个画布」（与动作表画布行同一约定）；画布上栈顶为空或
/// 撤销在途 ⇒ 灰着，原因「没有可撤销 / 可重做的操作」。启用 ⇔ 原因为 null（出自同一个判据）。
/// ⌘K：画布在场才进（inPalette），⌘K 只画启用的行，所以栈空时 ⌘K 里没有这两行。
final List<AppAction> canvasHistoryAppActions = <AppAction>[
  _historyAction(
    id: AppActionIds.undo,
    label: (AppLocalizations l) => l.commonUndo,
    icon: Icons.undo,
    macKey: PlannedKeys.undoMac,
    otherKey: PlannedKeys.undoOther,
    top: (CanvasHistoryState s) => s.undo.lastOrNull,
    nothing: (AppLocalizations l) => l.canvasHistoryNothingToUndo,
    run: runCanvasUndo,
  ),
  _historyAction(
    id: AppActionIds.redo,
    label: (AppLocalizations l) => l.appActionRedo,
    icon: Icons.redo,
    macKey: PlannedKeys.redoMac,
    otherKey: PlannedKeys.redoOther,
    top: (CanvasHistoryState s) => s.redo.lastOrNull,
    nothing: (AppLocalizations l) => l.canvasHistoryNothingToRedo,
    run: runCanvasRedo,
  ),
];

AppAction _historyAction({
  required String id,
  required String Function(AppLocalizations l) label,
  required IconData icon,
  required ShortcutActivator macKey,
  required ShortcutActivator otherKey,
  required CanvasHistoryStep? Function(CanvasHistoryState s) top,
  required String Function(AppLocalizations l) nothing,
  required _HistoryRun run,
}) {
  /// 此刻为什么不能用：null = 能用。
  String Function(AppLocalizations l)? blocker(AppActionContext c) {
    final String? canvasId = c.canvasId;
    if (canvasId == null) {
      return (AppLocalizations l) => l.appActionReasonOpenCanvas;
    }
    final CanvasHistoryState s =
        c.ref.read(canvasHistoryControllerProvider(canvasId));
    return s.busy || top(s) == null ? nothing : null;
  }

  return AppAction(
    id: id,
    group: AppActionGroup.edit,
    label: label,
    macKey: macKey,
    otherKey: otherKey,
    icon: icon,
    isAvailable: (AppActionContext c) => true,
    isEnabled: (AppActionContext c) => blocker(c) == null,
    disabledReason: (AppActionContext c, AppLocalizations l) =>
        blocker(c)?.call(l),
    inPalette: (AppActionContext c) => c.canvasId != null,
    run: (AppActionContext c) async {
      final String? canvasId = c.canvasId;
      if (canvasId == null) return;
      await run(
        ProviderScope.containerOf(c.context, listen: false).read,
        canvasId: canvasId,
        l: AppLocalizations.of(c.context),
        isMac: _isMac,
      );
    },
  );
}
