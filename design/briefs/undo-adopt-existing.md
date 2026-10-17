# undo-adopt-existing · 已有撤销卡并进栈：删节点、删连线、拖动换道；卡片只是提醒，收起后 Ctrl Z 仍可撤
- 波次 W3 / lane A / 基底：叠在 undo-shortcuts-ui、nodes-batch-ops 之后（W2 全部合入后的 origin/main）；依赖切片：undo-stack（CanvasHistoryController / CanvasCommand / EdgeEndpoints）、undo-shortcuts-ui（`runCanvasUndoStep` / `runCanvasUndo`）、nodes-batch-ops（`removeNodes` / `restoreAll` / `moveNodes` / `NodeMove`）、canvas-view-split（`stage/stage_edge_layer.dart` 的 `StageEdgeDeleteOverlay`、`stage/node_card_slot.dart` 的 `NodeCardSlot`）；阻塞决定：无。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/<切片id>`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
删节点（单选 / 多选）、删连线（舞台上选中线的 ✕、检查器入边区的「移除」）、拖动换道这三类操作，除了照旧弹撤销卡，还进画布撤销栈：卡片 8 秒收起后按 Ctrl Z / ⌘Z 仍能撤，撤完可 Ctrl Y / ⇧⌘Z 重做。
卡上「撤销」只撤卡上写的那一步（Q1-A）。关掉画布 / 项目时，这张画布的卡当场收起，残留的「撤销」点了也不再假装成功（修现存缺陷：现在 restore 静默不做事）。

## 设计依据
UndoClipboard.dc.html：
- 「和撤销卡的关系 · 卡片是提醒，栈才是本体」：卡片收起后按 Ctrl Z 仍可撤销；删除节点 / 拖动换道（resolveCardDrop 已弹的那张）进栈之外再弹卡，卡上「撤销」撤卡上这一步；关闭画布 / 项目丢掉它的栈并收起它的卡——现在卡还能点，restore 却什么也不做。
- 「什么进栈」：删除节点，连带它的线 →「删除 3 个节点」；加入 / 移出泳道 →「移入泳道「水墨」」；连线 / 删线 / 改语义。
- 「要补的底座」反向令牌：已有 NodeDeletion、removeEdge；反向找边按两端、不按边 id。
- 按建议：Q1 → A（只撤卡上那一步，从栈里抽掉）。Q2–Q5 与本片无关。
- 设计缺口：卡片清单只列了「删除节点 / 解散 / 删除泳道和内容 / 剪切 / 拖动换道」，没列删连线——本单保留舞台删线的现有卡（不回归），并让检查器入边区「移除」走同一条路（原来静默、连失败都吞掉）。
- 设计缺口：不换道的普通拖动这一片不进栈（属 W4 undo-node-create-move）；换道拖动的步名用「移入 / 移出泳道」。
- 设计缺口：撤销删除时节点原来所在的泳道已被删——板上没画；本单照旧复原 lane_id（与现状 restore 相同），留给 undo-lanes（W6）。

## 允许改的文件
- `lib/features/canvas/models/commands/delete_nodes_command.dart`（新）：`DeleteNodesCommand`。
- `lib/features/canvas/models/commands/delete_edge_command.dart`（新）：`DeleteEdgeCommand`。
- `lib/features/canvas/models/commands/move_nodes_command.dart`（新）：`MoveNodesCommand` + `NodePlacement` + `MoveNodesLabel`（W4 复用，不再另定义）。
- `lib/features/canvas/util/canvas_edge_delete.dart`（新，偏离约定的新文件）：`deleteEdgeWithUndo`，舞台与检查器共用。
- `lib/features/canvas/util/canvas_node_delete.dart`：单选 / 多选成功后 `record` 一步再出卡；删掉 `_restore` / `_restoreAll`。
- `lib/features/canvas/util/canvas_snackbars.dart`：`showCanvasUndoSnack` 改为按步 id 出卡并 `bindCard`；加不依赖 context 的 `showCanvasUndoSnackWith`；改头注「画布没有撤销快捷键」那句。
- `lib/features/canvas/widgets/stage/stage_edge_layer.dart`（由 canvas-view-split 新建）：`StageEdgeDeleteOverlay` 的删边改调 `deleteEdgeWithUndo`，删掉 `_restoreEdge`。
- `lib/features/canvas/widgets/stage/node_card_slot.dart`（由 canvas-view-split 新建）：`_commitDrag` 换道成功后 `record(MoveNodesCommand)` + `showCanvasUndoSnackWith`，删掉闭包 `undo()`。
- `lib/features/canvas/widgets/node_inputs_section.dart`：第 245 行 `ctrl.removeEdge(edge.id).catchError(...)` 改为 `deleteEdgeWithUndo`。
- 测试：`test/features/canvas/util/canvas_snackbars_test.dart`、`test/features/canvas/widgets/canvas_lane_drag_test.dart`、`test/features/canvas/widgets/canvas_node_delete_undo_test.dart`（新）、`test/features/canvas/models/commands/delete_nodes_command_test.dart`（新）、`…/delete_edge_command_test.dart`（新）、`…/move_nodes_command_test.dart`（新）、`test/features/canvas/widgets/node_inputs_section_test.dart`（追加）、`test/features/canvas/widgets/canvas_view_test.dart`（只改 fake 类：`_RestoreFailNodesController` 等改覆盖 `restoreAll`，断言不动）、`test/features/canvas/widgets/canvas_node_menu_test.dart`（只改 `_Nodes` fake 补 `restoreAll`，如需）。

## 不许碰的文件
- marquee-select：`widgets/stage/stage_pointer_layer.dart`、`widgets/canvas_view.dart`、`widgets/marquee_layer.dart`、`providers/canvas_marquee.dart`、`providers/canvas_tool_mode.dart`。
- tc-set-current：`providers/current_take_controller.dart`、`inspector_history_panel.dart`、`image_result_inspector.dart`、`video_result_inspector.dart`、`result_inspector_parts.dart`、`node_card.dart`、`canvas_menu/set_current_menu_items.dart`、`notifications/widgets/job_notification_listener.dart`、`export/widgets/export_video_dialog.dart`、`models/commands/set_current_take_command.dart`。
- import-media-command：`shortcuts/import_media_keys.dart`、`util/canvas_import_actions.dart`、`canvas_menu/import_media_menu_items.dart`。
- help-actions：`app_actions/help_actions.dart`、`left_rail/help_menu_popover.dart`、`left_rail/canvas_left_rail.dart`、`settings/widgets/diagnostics_section.dart`、`startup/widgets/startup_error_view.dart`、`services/github_update_check_service.dart`、`settings/providers/update_check_controller.dart`、`settings/providers/settings_page.dart`。
- 四张注册表本片都不碰；`canvas_nodes_controller.dart` / `canvas_edges_controller.dart` / `canvas_history_controller.dart` / `canvas_history_actions.dart` 只调用不改。
- （主 Agent 自查补充）help-actions：`lib/core/constants/app_repo.dart`（新）、`lib/theme/components/ink_menu_panel.dart`（只加可选 `tooltip`）、`lib/theme/primitives/ink_activatable.dart`（只加可选 `focusNode`）、`lib/features/settings/widgets/diagnostics_section.dart`、`lib/features/startup/widgets/startup_error_view.dart`、`lib/services/github_update_check_service.dart`。

## 具体改动
```dart
// models/commands/delete_nodes_command.dart
class DeleteNodesCommand extends CanvasCommand {
  DeleteNodesCommand(List<NodeDeletion> deletions);   // 非 const：重做后换成新令牌
  @override String label(AppLocalizations l);          // l.canvasCmdDeleteNodes(n)
  @override Set<String> get affectedNodeIds;           // 被删节点 id
  // revert：restoreAll(令牌) → 返回 0 ⇒ gone；InkError ⇒ failed；否则 done
  // apply：此刻还在内存里的 id → removeNodes → 换新令牌；一个都不在 ⇒ gone
}
// models/commands/delete_edge_command.dart
class DeleteEdgeCommand extends CanvasCommand {
  DeleteEdgeCommand(CanvasEdge removed);               // 记快照 + EdgeEndpoints.of(removed)
  // revert：findEdgeByEndpoints 已有在世边 ⇒ done（不再 restore）；任一端节点已不在 ⇒ gone；否则 restore(快照)
  // apply：findEdgeByEndpoints 找到 ⇒ removeEdge(找到的 id) 并换快照；找不到 ⇒ gone
  // affectedNodeIds = {source, target}；label = l.canvasCmdDeleteEdge
}
// models/commands/move_nodes_command.dart
typedef NodePlacement = ({Offset position, String? laneId});
enum MoveNodesLabelKind { move, intoLane, outOfLane }
typedef MoveNodesLabel = ({MoveNodesLabelKind kind, String? laneName});      // laneName 在 record 时快照；空 ⇒ l.laneUntitled
class MoveNodesCommand extends CanvasCommand {
  const MoveNodesCommand({required Map<String, NodePlacement> before, required Map<String, NodePlacement> after, required MoveNodesLabel label});
  // revert：对此刻还在的 id，delta = before.position − 当前位置、laneId = before.laneId → 一次 moveNodes；一个都不在 ⇒ gone
  // apply：同上换成 after
}
// util/canvas_edge_delete.dart
Future<void> deleteEdgeWithUndo(BuildContext context, WidgetRef ref, {required String canvasId, required String edgeId});
// util/canvas_snackbars.dart
void showCanvasUndoSnack(BuildContext context, {required String message, required String canvasId, required String stepId});
void showCanvasUndoSnackWith(ProviderContainer container, AppLocalizations l, {required String message, required String canvasId, required String stepId});
```
- `showCanvasUndoSnackWith`：`handle = toasts.show(message, kind: ToastKind.undo, primary: ToastAction(l.commonUndo, () => unawaited(runCanvasUndoStep(container.read, canvasId: …, stepId: …, l: l, isMac: defaultTargetPlatform == TargetPlatform.macOS))))`，随后 `container.read(canvasHistoryControllerProvider(canvasId).notifier).bindCard(stepId, handle)`。context 版本在同步段取出 container 与 l 后委托它。
- `NodeCardSlot._commitDrag`：await 前照旧取齐 l / container / nodesCtrl / origin / fromLaneId；移动成功且换了道 ⇒ 从 container 读该节点此刻位置作为 `after`，`record(MoveNodesCommand(before: {id: (origin, fromLaneId)}, after: {id: (现位置, drop.laneId)}, label: (kind: intoLane/outOfLane, laneName: …)))`，再 `showCanvasUndoSnackWith(container, l, message: laneMessage, …)`。
- 先操作、成功后才 `record`；失败不进栈、不出撤销卡。

## 行为规则与边界情况
1. 单选删除：`removeNode` 成功且有令牌 ⇒ 记一步「删除 1 个节点」+ 卡「Node deleted · 撤销」；无令牌 ⇒ 只出 info 卡、不进栈（现状）；失败 ⇒ `nodeDeleteFailed`，不进栈。
2. 多选删除：一次 `removeNodes` ⇒ 记一步「删除 N 个节点」+ 一张卡；失败一张不删、不进栈。
3. 删线（舞台 ✕ 与检查器「移除」同一函数）：成功 ⇒ 记一步「删除连线」+ 卡「Link deleted · 撤销」；失败 ⇒ `edgeDeleteFailed`（检查器原来吞掉失败，现在报）。
4. 拖动换道：换了道才记一步并出卡（「已移入泳道「X」」/「已移出泳道「X」」）；没换道的普通拖动不进栈（W4 再接）；移动失败 ⇒ `nodeMoveFailed`、不进栈。
5. 卡上「撤销」= `undoSpecific(该步)`：该步在栈顶 ⇒ 等同 Ctrl Z（进重做栈）；之后又做过别的 ⇒ 只撤这一步、从栈里抽掉，后做的步原样留在栈里（Q1-A）。
6. 卡片 8 秒自动收起后，该步仍在栈里，Ctrl Z 照撤；Ctrl Z 撤掉某步时它的卡当场收起。
7. 关画布（换画布 / closeCanvas / closeProject）⇒ 该画布全部撤销卡 dismiss；残留按钮被调用 ⇒ `undoSpecific` 返回 empty，不调任何 controller、不出任何卡（修「卡还能点、restore 什么也不做」）。
8. 撤销删除节点：一次 `restoreAll`；受影响行全 0 ⇒ gone（胶囊「这一步已无法撤销」）；InkError ⇒ `undoFailed` 错误卡、步留栈顶。
9. 撤销删线：同两端（source / target / edgeType）已有在世边 ⇒ 视为已复原、不再写库（避免 uq_edges_live 23505）；任一端节点已不在 ⇒ gone；否则 restore（沿用 restore 里首 / 尾帧降级逻辑）。
10. 重做删线：按两端找边，不按旧 id——撤销后边被删了又重连（新 id）也能删中；找不到 ⇒ gone。
11. 撤销换道：按「before 位置 − 此刻位置」算位移（期间被别处挪过也回得去，与现有闭包同义），lane 回原道；节点已删 ⇒ gone。
12. 撤销 / 重做后的选中、平移、胶囊由 undo-shortcuts-ui 的执行口统一做（卡片路径与 Ctrl Z 路径同一套反馈）。
13. 并发：命令里的写都走各 controller 的 `serialize`；撤销在途再点卡 ⇒ busy、静默。
14. mac / Windows：卡片按钮文案相同；撤销后胶囊里的重做键按平台（⇧⌘Z / Ctrl+Y）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCmdDeleteNodes | {count, plural, one{Delete {count} node} other{Delete {count} nodes}} | {count, plural, other{删除 {count} 个节点}} |
| canvasCmdDeleteEdge | Delete link | 删除连线 |
| canvasCmdMoveNodes | {count, plural, one{Move {count} node} other{Move {count} nodes}} | {count, plural, other{移动 {count} 个节点}} |
| canvasCmdMoveIntoLane | Move into lane “{lane}” | 移入泳道「{lane}」 |
| canvasCmdMoveOutOfLane | Move out of lane “{lane}” | 移出泳道「{lane}」 |
（复用 `nodeDeleted`、`nodesDeleted`、`edgeDeleted`、`edgeDeleteFailed`、`nodeMoveFailed`、`canvasNodeJoinedLane`、`canvasNodeLeftLane`、`undoFailed`、`commonUndo`、`laneUntitled`、`canvasUndoStepGone`。）

## 测试
`test/features/canvas/widgets/canvas_node_delete_undo_test.dart`（新；触发按钮调 `deleteNodesWithUndo`，照 canvas_snackbars_test 的 `_pumpTrigger`；节点 controller 覆盖为记录 `restoreAll` / `removeNodes` 调用的 FakeNodesController 子类；`RecordingToastService`；先 `openCanvas('c1')`）：
- `单删 ⇒ 一张卡 + 栈里一步「Delete 1 node」`。
- `卡片收起后 Ctrl Z（runCanvasUndo）仍复原，且卡被 dismiss`。
- `删 A、再删 B，点 A 的卡 ⇒ 只复原 A；B 那步仍在栈顶；重做栈为空`（Q1-A）。
- `关掉画布（openCanvas('c2')）⇒ 卡 dismissed；再调卡上的 onPressed ⇒ restoreAll 调用 0 次、不出任何新卡`。
- `restoreAll 返回 0 ⇒ 胶囊 This step can no longer be undone，栈里这步没了`。
- `restoreAll 抛 InkError ⇒ Couldn't undo 错误卡，步仍在栈顶`。
- `多删失败 ⇒ 栈为空、没有撤销卡`。
`test/features/canvas/models/commands/delete_edge_command_test.dart`：`revert 同两端已有在世边 ⇒ done 且不调 restore`；`revert 端点节点已删 ⇒ gone`；`apply 按两端找边：边被重连换了 id 仍删中`；`apply 找不到 ⇒ gone`。
`…/delete_nodes_command_test.dart`：`revert 走一次 restoreAll`；`apply 换新令牌，再 revert 用新令牌`；`apply 节点都不在 ⇒ gone`；`label：1 / 3 个节点（en / zh）`。
`…/move_nodes_command_test.dart`：`revert 期间被别处挪过 ⇒ 仍回到 before 位置与原道`（一次 moveNodes）；`节点已删 ⇒ gone`；`label：移入 / 移出泳道，名字空写 Untitled lane`。
`test/features/canvas/widgets/canvas_lane_drag_test.dart`：改「真拖进 Dusk…Undo 挪回原位置、原泳道」——本文件 `_Nodes` fake 补 `moveNodes`（记成同一 `_Moved` 结构），断言不变；新增 `换道后卡片收起，Ctrl Z 仍挪回原位置、原泳道`；`误拖几个像素` 两条再断言栈为空。
`test/features/canvas/util/canvas_snackbars_test.dart`：改两条 showCanvasUndoSnack 用例为按步 id——按下按钮 ⇒ 脚本命令日志 `revert:<id>`；新增 `步被撤掉 ⇒ 卡 dismissed`。
`test/features/canvas/widgets/node_inputs_section_test.dart`：改「点移除 → 边被删除」再断言出「Link deleted」卡；新增 `移除失败 ⇒ Failed to delete link`。

## 变异点
- 删掉 canvas_node_delete.dart 单选分支的 `record` → 「卡片收起后 Ctrl Z 仍复原」红。
- 把 `showCanvasUndoSnackWith` 的按钮改成调 `runCanvasUndo`（撤栈顶）→ 「删 A、再删 B，点 A 的卡」红。
- 删掉 `bindCard` 调用 → 「关掉画布 ⇒ 卡 dismissed」红。
- 把 `DeleteNodesCommand.revert` 的「返回 0 ⇒ gone」删掉 → 「restoreAll 返回 0 ⇒ 胶囊…」红。
- 把 `DeleteEdgeCommand.apply` 改成按快照 id `removeEdge` → 「边被重连换了 id 仍删中」红。
- 删掉 `DeleteEdgeCommand.revert` 的在世边预检 → 「同两端已有在世边 ⇒ 不调 restore」红。
- 把 `MoveNodesCommand.revert` 的 delta 改成 `before − after` → 「期间被别处挪过 ⇒ 仍回到 before」红。
- 删掉 node_card_slot.dart `_commitDrag` 里的 `record` → 「换道后卡片收起，Ctrl Z 仍挪回」红。
- 把 node_inputs_section.dart 改回 `removeEdge(...).catchError` → 「移除失败 ⇒ Failed to delete link」红。

## 验收
主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/features/shell`、逐条变异；重点看 canvas_view_test / canvas_node_menu_test / canvas_shortcuts_test 原有撤销用例只改 fake 仍绿。
截图（`CanvasView` + 两节点一线 + Rain / Dusk 两道，en / zh）：① 多选删 2 张后的单张卡「2 nodes deleted · Undo」；② 卡收起后按 Ctrl+Z 的胶囊「已撤销 · 删除 2 个节点 | 重做 Ctrl+Y」；③ 拖进 Dusk 的卡「已移入泳道「Dusk」」；④ 空白处右键菜单顶行「撤销 移入泳道「Dusk」」。

## 风险与不确定
- 偏离约定：新建 `util/canvas_edge_delete.dart`（contract §3 未列）——删线入口有舞台与检查器两处，不抽出来就要各写一份记步逻辑。
- canvas_view_test.dart 同波可能被 marquee-select 改：本片只动其中 fake 类，冲突由主 Agent 合并。
- `restoreAll` 复原的级联边若已被同两端重连，整批 23505 ⇒ `undoFailed`（nodes-batch-ops 风险同条）；本片只对单条删线做了在世边预检。
- `DeleteNodesCommand` 持可变令牌（重做后替换），与「命令只持快照」的字面略有出入；令牌本身仍是快照。
