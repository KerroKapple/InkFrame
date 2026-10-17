# undo-lanes · 泳道操作进栈：新建 / 改名 / 改风格 / 排序 / 改厚 + 解散（节点留下）/ 删除泳道和内容
- 波次 W6 / lane D / 基底 origin/main〔W0–W5 已合入〕
- 依赖切片：lane-ops-core（W2，dissolveLane / deleteLaneWithContents + 令牌）、undo-adopt-existing（W3，showCanvasUndoSnack 登记栈步 id）、undo-stack（W0）、undo-shortcuts-ui（W2）、canvas-view-split（W0，stage_lane_layer.dart）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 新建泳道（泳道工具栏「添加泳道」/ 浮动工具条泳道键 / ⌘K）、在编辑框里改名 / 改风格 / 改色、拖标题栏排序、拖分界线改厚：每次一步，Ctrl Z 回去。
- 标题栏垃圾桶 = 「解散（节点留下）」：不确认，直接解散 + 撤销卡，也进栈。
- 「删除泳道和内容」作为独立动作（函数）交付：道内有生成中任务先确认，否则直接删 + 卡；进栈。菜单行由 W7 cm-lane-menu 接，本片不加菜单。
- 泳道折叠不进栈。

## 设计依据
- 画板 UndoClipboard.dc.html（b2_history.js）「什么进栈」：「泳道新建 / 改名 / 改风格 / 排序 → 修改泳道「水墨」风格」「解散（节点留下）→ 解散泳道「水墨」」「删除泳道和内容 → 删除泳道「水墨」和 4 个节点」；不进栈清单含「泳道折叠」。
- 「和撤销卡的关系」：「解散（节点留下）不确认：清掉道内节点的 lane_id、位置不动，直接解散 + 卡」「删除泳道和内容：一个事务软删道和道内节点；道内有生成中任务先确认，否则直接删 + 卡。和解散是两个动作、两步」「删除节点 / 解散泳道 / 删除泳道和内容 / …：进栈之外再弹卡；卡上「撤销」撤卡上这一步」（UndoClipboard-Q1 建议 A：卡上写哪步撤哪步）。
- revise-summary：解散与删除泳道和内容是两个独立撤销步、各自命名、永不合并；唯一需要确认的是道内有在生成的任务，因为取消任务撤不回。
- 设计缺口：①「改厚」画板进栈表没单列（slices.json 标题有），按「调整泳道「X」厚度」一步写；②切换泳道方向（lane_toolbar 的方向键）画板没提，按「不进栈」处理并在回报里列出；③「删除泳道和内容」确认框文案画板没画，按下表写；④排序期间泳道被删的合并规则没画，按规则 7 写。

## 允许改的文件
- lib/features/canvas/models/commands/lane_edit_command.dart（新建，独立文件，不是 part）：CreateLaneCommand / UpdateLaneCommand / ReorderLanesCommand / DissolveLaneCommand / DeleteLaneWithContentsCommand。
- （不改 canvas_command.dart；命令在上面的独立文件里，各自实现 label(l)。）
- lib/features/canvas/providers/canvas_lanes_controller.dart：
  - updateLane（main 第 75–119 行）返回值 `Future<void>` → `Future<StyleLane?>`：改之前那份快照；没找到 / patch 为空返回 null。
  - reorderLanes（第 123–151 行）返回值 → `Future<List<String>?>`：改之前的 id 顺序；顺序不完整跳过（第 134 行）或顺序没变返回 null。
  - W2 lane-ops-core 已提供（直接用、不改）：`dissolveLane(String laneId, {required Map<String, Offset> positions}) → Future<LaneDissolution?>`、`restoreDissolved(LaneDissolution)`、`deleteLaneWithContents(String laneId) → Future<LaneContentsDeletion?>`、`restoreLaneContents(LaneContentsDeletion)`；令牌类型在 `util/lane_dissolve.dart`（`LaneDissolution{lane, nodes: List<({nodeId, position})>}`、`LaneContentsDeletion{lane, nodeIds, edgeIds}`），已带 `lane`（步名用 lane.label）与节点 id，不用补字段。
- lib/features/canvas/util/canvas_lane_actions.dart（**W2 lane-ops-core 已新建**，里面已有 `dissolveLaneWithUndo` / `deleteLaneWithContentsWithUndo`：算 `dissolvedPositions`、解散后去掉折叠标记、删前判 `activeJobsInLane` 弹确认、确认后逐个 `jobQueueService.cancel`、清选中、出撤销卡；W6 归本片）：两个函数成功后改为 `record(DissolveLaneCommand(token))` / `record(DeleteLaneWithContentsCommand(token))` 拿步 id，再用 W3 的 `showCanvasUndoSnack(context, message:, canvasId:, stepId:)` 出卡（W3 只为这两处保留了 `onUndo` 旧式回调分支，并写明「W6 改成进栈后删掉」；本片只改调用处，不碰 canvas_snackbars.dart——那个文件 W6 归 cm-delete-bridge；分支在 W6 两片都合入后由主 Agent 删）；确认框、取消任务、清选中等其余逻辑原样保留。
- lib/features/canvas/util/canvas_tool_actions.dart：addLaneViaDialog（main 第 135–154 行）createLane 成功后 record CreateLaneCommand。
- lib/features/canvas/widgets/lane_toolbar.dart：_onAdd（第 92–113 行）是 addLaneViaDialog 的一份重复，改成直接调 addLaneViaDialog（这样两个入口都进栈）；方向切换不动。
- lib/features/canvas/widgets/stage/stage_lane_layer.dart（由 canvas-view-split 新建；W2 lane-ops-core 已删掉 `_onDeleteLane`、标题栏 `onDissolve` 改调 `dissolveLaneWithUndo`；W4 stage-drop-target 动过 `StageLaneBackgroundLayer`）：
  - 标题栏拖动排序 onPanEnd（main 第 1084–1099 行）：await reorderLanes 拿旧顺序 → record；补 try/on InkError → laneUpdateFailed 卡（现在没 catch）。
  - 分界线改厚 commit（第 1150–1160 行）：拿旧快照，size 真变了才 record（kind: resize）。
  - _onEditLane（第 1187–1210 行）：拿旧快照 → record（只改了 label ⇒ kind: rename；动了风格或色 ⇒ kind: restyle）；三项都没变不 record。
- lane_title_bar.dart：**不改**（W2 已把垃圾桶 tooltip 换成 `laneDissolve`、参数改 `onDissolve`；右键菜单归 W7）。
- lib/features/canvas/widgets/lane_edit_dialog.dart：预计不改（LaneEditResult 已带 label / stylePrompt / tintColor）。
- 测试：test/features/canvas/canvas_lanes_controller_test.dart、test/features/canvas/widgets/canvas_lane_integration_test.dart、test/features/canvas/util/canvas_lane_actions_test.dart（W2 lane-ops-core 已新建，本片追加用例；W2 原有「撤销卡点撤销 = restoreDissolved」类断言按栈步改写）、test/features/canvas/widgets/lane_toolbar_test.dart。

## 不许碰的文件
- 同波：util/drag_snap.dart、snap_guides_layer.dart、node_card.dart、widgets/stage/node_card_slot.dart、widgets/stage/stage_overlays.dart、node_drag_delta.dart、canvas_menu/snap_menu_items.dart、core/di/canvas_snap.dart、app_preferences.dart、file_preferences_service.dart、设置外观页（snapping）；canvas_view.dart 骨架、widgets/stage/stage_edge_layer.dart、canvas_menu/canvas_menu_host.dart、canvas_menu/canvas_menu_request.dart、edge_menu_*、edge_toolbar.dart、util/canvas_edge_actions.dart、selected_edge_controller.dart、widgets/shortcuts/core_canvas_keys.dart、theme/components/ink_menu_panel.dart（cm-edge-menu）；canvas_nodes_controller.dart、canvas_node_delete.dart、util/delete_bridge_preview.dart、models/commands/delete_nodes_command.dart、canvas_menu/delete_no_bridge_menu_items.dart、canvas_snackbars.dart（cm-delete-bridge；它只给 showCanvasUndoSnack 加可选 body，本片照旧调用）；export/*、shell/widgets/tabs/export_tab.dart（export-records）。
- lane_title_bar.dart（W2 已改好；W7 cm-lane-menu 再改）。
- lane_collapse_controller.dart（折叠不进栈）；canvas_menu/*（W7 cm-lane-menu 接菜单行）。
- W6 lane E 导出两片的文件：`lib/features/export/**`（含 open_export_dialog.dart、run_delivery.dart、widgets/export_video_dialog.dart、models/delivery_writer_registry.dart）、`lib/features/shell/widgets/tabs/export_tab.dart`。

## 具体改动
```dart
// models/commands/lane_edit_command.dart
enum LaneEditKind { create, rename, restyle, resize, reorder, dissolve, deleteWithContents }

// 全部 canvasId 从 CanvasCommandEnv 取；label(l) 按 kind 出步名（见下）；revert / apply(CanvasCommandEnv) → CanvasCommandOutcome
class CreateLaneCommand extends CanvasCommand { CreateLaneCommand({required StyleLane lane}); }
class UpdateLaneCommand extends CanvasCommand {
  const UpdateLaneCommand({required LaneEditKind kind, // rename / restyle / resize
      required StyleLane before, required StyleLane after});
}
class ReorderLanesCommand extends CanvasCommand { const ReorderLanesCommand({required List<String> before, required List<String> after}); }
class DissolveLaneCommand extends CanvasCommand { DissolveLaneCommand(LaneDissolution token); }               // W2 util/lane_dissolve.dart
class DeleteLaneWithContentsCommand extends CanvasCommand { DeleteLaneWithContentsCommand(LaneContentsDeletion token); }
// affectedNodeIds：解散 = token.nodes 的 nodeId；删除 = token.nodeIds；其余为空（undo-shortcuts-ui 对空集不移相机）。

// util/canvas_lane_actions.dart（W2 已有这两个函数，签名不变，本片只改「成功之后」那段）
Future<void> dissolveLaneWithUndo(BuildContext context, WidgetRef ref,
    {required String canvasId, required StyleLane lane});
Future<void> deleteLaneWithContentsWithUndo(BuildContext context, WidgetRef ref,
    {required String canvasId, required StyleLane lane});
```
- CreateLaneCommand：revert = 用 W2 的 `dissolvedPositions(...)` 算位置后 `dissolveLane(lane.id, positions:)`（保险：道里若被系统放进了节点，节点留下、屏幕位置不动），保存 `LaneDissolution`；返回 null（道已不在）⇒ `gone`。apply（重做）= `restoreDissolved(token)`（同 id、原下标）。
- UpdateLaneCommand：只回这一步动过的字段——rename 只回 label；restyle 回 label / stylePrompt / tintColor（tintColor 为 null ⇒ clearTint: true）；resize 只回 size。apply 同理用 after。道已不在 ⇒ `gone`。
- ReorderLanesCommand：revert 目标顺序 = before 里此刻还在的 id（保持 before 次序）+ 此刻有、before 里没有的 id（保持此刻次序）接在后面，再 reorderLanes；apply 同理用 after。
- DissolveLaneCommand / DeleteLaneWithContentsCommand：revert = `restoreDissolved(token)` / `restoreLaneContents(token)`（W2，一个事务）；apply = 再执行一次 `dissolveLane`（位置重算）/ `deleteLaneWithContents`，换上新令牌（返回 null ⇒ `gone`）。
- dissolveLaneWithUndo（W2 版本改尾段）：dissolveLane 成功 → `record(DissolveLaneCommand(token))` → W3 `showCanvasUndoSnack(context, message: l.laneDissolved(name), canvasId:, stepId:)`（「撤销」= undoSpecific）；失败 ⇒ W2 现有的 `laneDissolveFailed` 卡、不 record。
- deleteLaneWithContentsWithUndo（W2 版本改尾段）：在途任务判据（`activeJobsInLane`）、确认框（`laneDeleteRunningTitle` / `Body` / `Confirm`）、确认后逐个 `jobQueueService.cancel`、清选中，全部是 W2 已写好的，**不重做一份**；只把 deleteLaneWithContents 成功后的撤销卡改成 `record(DeleteLaneWithContentsCommand(token))` + `showCanvasUndoSnack(..., message: l.laneDeletedWithContents(count, name), stepId:)`。
- 步名：create「新建泳道「X」」、rename「重命名泳道「X」」、restyle「修改泳道「X」风格」、resize「调整泳道「X」厚度」、reorder「调整泳道顺序」、dissolve「解散泳道「X」」、deleteWithContents「删除泳道「X」和 {count} 个节点」。X 为空用 laneUntitled。

## 行为规则与边界情况
1. 新建泳道成功 ⇒ 一步；对话框取消 / 写失败 ⇒ 不进栈。工具栏「添加泳道」与浮动工具条泳道键走同一个 addLaneViaDialog，两边都进栈。
2. 撤销新建 ⇒ 道消失（软删）；重做 ⇒ 同 id 回来、排序位置不变。
3. 编辑框只改名 ⇒「重命名泳道」一步；改风格 / 改色（可连带改名）⇒「修改泳道风格」一步；什么都没改点保存 ⇒ 不进栈。
4. 撤销改风格只回 label / 风格 / 色，不动这期间被拖过的厚度。
5. 拖分界线改厚 ⇒ 一步，撤销只回 size；拖了但 clampLaneSize 后厚度没变 ⇒ 不进栈。
6. 拖标题栏排序 ⇒ 一步；拖动不到 12px（现有阈值）或顺序没变 ⇒ 不进栈；reorderLanes 失败 ⇒ 回滚 + 「更新泳道失败」卡（现有键 laneUpdateFailed）、不进栈。
7. 排序之后新建了一条道再撤销排序 ⇒ 原有道回到旧次序，新道接在末尾；被删的道从目标顺序里剔除。
8. 垃圾桶 = 解散：不确认；节点 lane_id 清空、屏幕位置不动；一张卡 + 一步；卡收起后 Ctrl Z 仍可撤；卡上「撤销」撤的是卡上这一步（中间做了别的也一样）。
9. 删除泳道和内容：道内无在途任务 ⇒ 直接删 + 卡 + 一步；有 ⇒ 先确认，确认后取消这些任务再删（取消不随撤销回来）；撤销 ⇒ 道、节点、边一个事务复原。
10. 解散和删除泳道和内容是两个独立步，永不合并。
11. 折叠 / 展开、切换泳道方向不进栈。
12. 撤销任一泳道步时道已不在（例如被另一步删了）⇒ 对象已消失、丢步、提示，不连带撤下一步。
13. 关掉画布 ⇒ 栈与卡一起收（undo-stack / W3 已实现，本片测试覆盖解散卡）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCommandLaneCreate | Create lane “{lane}” | 新建泳道「{lane}」 |
| canvasCommandLaneRename | Rename lane “{lane}” | 重命名泳道「{lane}」 |
| canvasCommandLaneRestyle | Edit style of lane “{lane}” | 修改泳道「{lane}」风格 |
| canvasCommandLaneResize | Resize lane “{lane}” | 调整泳道「{lane}」厚度 |
| canvasCommandLaneReorder | Reorder lanes | 调整泳道顺序 |
| canvasCommandLaneDissolve | Dissolve lane “{lane}” | 解散泳道「{lane}」 |
| canvasCommandLaneDeleteWithContents | Delete lane “{lane}” and {count} nodes | 删除泳道「{lane}」和 {count} 个节点 |
（撤销卡与确认框文案**全部复用 W2 lane-ops-core 已加的键**：`laneDissolved(name)`、`laneDeletedWithContents(count, name)`、`laneDeleteRunningTitle(name)` / `laneDeleteRunningBody(count)` / `laneDeleteRunningConfirm`、`laneDissolveFailed`，本片不再新加 toast / 确认框键；`laneUpdateFailed` 是现有键。`laneDelete` / `laneDeleteConfirmTitle` / `laneDeleteConfirmBody` 由 W2 回报删除。）

## 测试
test/features/canvas/canvas_lanes_controller_test.dart（追加；InMemoryStyleLaneRepository + FakeUnitOfWork）
- 「updateLane 返回改前快照」；「patch 为空返回 null」。
- 「reorderLanes 返回旧顺序；顺序没变返回 null」。
test/features/canvas/util/canvas_lane_actions_test.dart（W2 已建，追加；pumpInkApp + Consumer；InMemory 仓储 + 真的 CanvasLanesController / CanvasNodesController / CanvasHistoryController；RecordingToastService）
- 「解散不确认：一步 + 一张卡」：调 dissolveLaneWithUndo 后无 AlertDialog、栈深 1、录到一张 ToastKind.undo 卡。
- 「解散后撤销：道回来、节点 lane_id 回来、位置不变」。
- 「删除泳道和内容：无在途任务直接删」：栈深 1，道和 2 个节点 deleted_at 非空。
- 「删除泳道和内容：有在途任务先确认，取消则什么都不做」：override jobsRegistryProvider；出 AlertDialog；点取消 ⇒ 栈深 0、道仍在。
- 「确认后取消任务再删」：fake JobQueueService 录到 cancel(jobId)；栈深 1。
- 「解散与删除是两步」：先解散 A 再删除 B ⇒ 栈深 2，undo 一次只回 B。
test/features/canvas/widgets/canvas_lane_integration_test.dart（追加）
- 「编辑框只改名 = 重命名一步；撤销回旧名」。
- 「撤销改风格不动厚度」：改风格 → 拖分界线 → 撤两步中的第一步用 undoSpecific(风格那步) ⇒ size 仍是新值、风格回旧。
- 「拖分界线 = 一步；撤销回旧厚度」。
- 「拖标题栏排序 = 一步；撤销回旧顺序」；「排序后新建道再撤销：新道在末尾」。
- 「新建泳道撤销后消失，重做同 id 回来」。
test/features/canvas/widgets/lane_toolbar_test.dart（追加）
- 「工具栏添加泳道也进栈」。

## 变异点
1. dissolveLaneWithUndo 里加回确认框 ⇒「解散不确认」红。
2. deleteLaneWithContentsWithUndo 不判在途任务 ⇒「有在途任务先确认…」红；判了但取消分支仍删 ⇒ 同一条红。
3. 确认后不调 cancel ⇒「确认后取消任务再删」红。
4. UpdateLaneCommand.revert 整份写回 before（含 size）⇒「撤销改风格不动厚度」红。
5. _onEditLane 不区分 rename / restyle（全记 restyle）⇒「编辑框只改名 = 重命名一步」的步名断言红。
6. ReorderLanesCommand.revert 直接 reorderLanes(before) ⇒「排序后新建道再撤销：新道在末尾」红（顺序不完整被第 134 行跳过，顺序不回）。
7. lane_toolbar._onAdd 保留自己那份 createLane ⇒「工具栏添加泳道也进栈」红。
8. CreateLaneCommand.apply 用 createLane 重建 ⇒「重做同 id 回来」红。
9. reorderLanes 返回值恒非 null（顺序没变也返回）⇒「顺序没变返回 null」红。

## 验收
- flutter analyze lib test；flutter test test/features/canvas --exclude-tags golden；逐条变异。
- 截图：CanvasScreen，横向两条道「水墨」（3 个节点）/「赛博」；①点「水墨」垃圾桶 → 截撤销卡「已解散泳道「水墨」」与节点原位；②Ctrl Z → 截道与节点归位；③给「赛博」里一个节点挂在途 JobState，调 deleteLaneWithContentsWithUndo → 截确认框；④改「赛博」风格后截空白处右键「撤销 修改泳道「赛博」风格」。

## 风险与不确定
- （复核已定）W2 的令牌 `LaneDissolution` / `LaneContentsDeletion` 已带 `lane`（含 label）与节点 id，复原函数是 `restoreDissolved` / `restoreLaneContents`；不用补字段。
- （复核已定）取消任务在 W2 的 `deleteLaneWithContentsWithUndo` 动作层里（确认后逐个 `jobQueueService.cancel`），控制器的 `deleteLaneWithContents` 不取消；本片不改这段、不再取消第二次。
- 本片动 stage_lane_layer 的回调；W7 cm-lane-menu 接右键菜单时调 canvas_lane_actions.dart 的两个函数，不要再写一份。
- updateLane / reorderLanes 改返回类型：调用方只有 stage_lane_layer（main canvas_view.dart:1098 / 1155 / 1198）和测试。
- 设计缺口②（方向切换不进栈）请设计确认。
