# undo-lanes · 泳道操作进栈：新建 / 改名 / 改风格 / 排序 / 改厚 + 解散（节点留下）/ 删除泳道和内容
- 波次 W6 / lane D / 基底 origin/main〔W0–W5 已合入〕
- 依赖切片：lane-ops-core（W2，dissolveLane / deleteLaneWithContents + 令牌）、undo-adopt-existing（W3，showCanvasUndoSnack 登记栈步 id）、undo-stack（W0）、undo-shortcuts-ui（W2）、canvas-view-split（W0，stage_lane_layer.dart）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

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
- lib/features/canvas/models/commands/lane_edit_command.dart（新建，`part of '../canvas_command.dart';`）：CreateLaneCommand / UpdateLaneCommand / ReorderLanesCommand / DissolveLaneCommand / DeleteLaneWithContentsCommand。
- lib/features/canvas/models/canvas_command.dart（由 undo-stack 新建）：追加一行 part + 枚举值 `CanvasCommandLabel.laneEdit`。
- lib/features/canvas/providers/canvas_lanes_controller.dart：
  - updateLane（main 第 75–119 行）返回值 `Future<void>` → `Future<StyleLane?>`：改之前那份快照；没找到 / patch 为空返回 null。
  - reorderLanes（第 123–151 行）返回值 → `Future<List<String>?>`：改之前的 id 顺序；顺序不完整跳过（第 134 行）或顺序没变返回 null。
  - dissolveLane / deleteLaneWithContents 与它们的复原操作由 lane-ops-core 提供，直接用；只在令牌缺字段时补（例如令牌里要有道的 label 给步名）。
- lib/features/canvas/util/canvas_lane_actions.dart（新建）：`dissolveLaneWithUndo`、`deleteLaneWithContentsWithUndo`（见下），给 stage_lane_layer 与 W7 菜单共用。
- lib/features/canvas/util/canvas_tool_actions.dart：addLaneViaDialog（main 第 135–154 行）createLane 成功后 push CreateLaneCommand。
- lib/features/canvas/widgets/lane_toolbar.dart：_onAdd（第 92–113 行）是 addLaneViaDialog 的一份重复，改成直接调 addLaneViaDialog（这样两个入口都进栈）；方向切换不动。
- lib/features/canvas/widgets/stage_lane_layer.dart（由 canvas-view-split 新建；main 上是 canvas_view.dart）：
  - 标题栏拖动排序 onPanEnd（main 第 1084–1099 行）：await reorderLanes 拿旧顺序 → push；补 try/on InkError → laneUpdateFailed 卡（现在没 catch）。
  - 分界线改厚 commit（第 1150–1160 行）：拿旧快照，size 真变了才 push（kind: resize）。
  - _onEditLane（第 1187–1210 行）：拿旧快照 → push（只改了 label ⇒ kind: rename；动了风格或色 ⇒ kind: restyle）；三项都没变不 push。
  - _onDeleteLane（第 1212–1250 行；W2 已改成解散）：改成调 dissolveLaneWithUndo；若 W2 还留着 AlertDialog（第 1217–1236 行），删掉。
- lib/features/canvas/widgets/lane_title_bar.dart：只在 W2 没改时把垃圾桶 tooltip 从 laneDelete 换成解散文案（第 112 行）；其余不动（右键菜单归 W7）。
- lib/features/canvas/widgets/lane_edit_dialog.dart：预计不改（LaneEditResult 已带 label / stylePrompt / tintColor）。
- 测试：test/features/canvas/canvas_lanes_controller_test.dart、test/features/canvas/widgets/canvas_lane_integration_test.dart、test/features/canvas/util/canvas_lane_actions_test.dart（新建）、test/features/canvas/widgets/lane_toolbar_test.dart。

## 不许碰的文件
- 同波：util/drag_snap.dart、snap_guides_layer.dart、node_card.dart、node_card_slot.dart、stage_overlays.dart、canvas_menu/blank_menu_entries.dart、app_preferences.dart、file_preferences_service.dart、设置外观页（snapping）；canvas_view.dart 骨架、stage_edge_layer.dart、canvas_menu/canvas_menu_host.dart、edge_menu_*、selected_edge_controller.dart、canvas_shortcuts.dart（cm-edge-menu）；canvas_nodes_controller.dart、canvas_node_delete.dart、canvas_menu/node_menu_entries.dart、canvas_snackbars.dart（cm-delete-bridge）；export/*、shell/widgets/tabs/export_tab.dart（export-records）。
- lane_collapse_controller.dart（折叠不进栈）；canvas_menu/*（W7 cm-lane-menu 接菜单行）。
- W6 lane E 导出两片的文件：`lib/features/export/**`（含 open_export_dialog.dart、run_delivery.dart、widgets/export_video_dialog.dart、models/delivery_writer_registry.dart）、`lib/features/shell/widgets/tabs/export_tab.dart`。

## 具体改动
```dart
// models/commands/lane_edit_command.dart
enum LaneEditKind { create, rename, restyle, resize, reorder, dissolve, deleteWithContents }

final class CreateLaneCommand extends CanvasCommand {
  CreateLaneCommand({required String canvasId, required StyleLane lane});
}
final class UpdateLaneCommand extends CanvasCommand {
  UpdateLaneCommand({required String canvasId, required LaneEditKind kind, // rename / restyle / resize
      required StyleLane before, required StyleLane after});
}
final class ReorderLanesCommand extends CanvasCommand {
  ReorderLanesCommand({required String canvasId, required List<String> before, required List<String> after});
}
final class DissolveLaneCommand extends CanvasCommand {
  DissolveLaneCommand({required String canvasId, required /* lane-ops-core 的解散令牌 */ Object token});
}
final class DeleteLaneWithContentsCommand extends CanvasCommand {
  DeleteLaneWithContentsCommand({required String canvasId, required /* lane-ops-core 的删除令牌 */ Object token});
}
// 上面 Object 换成 lane-ops-core 实际令牌类型；label 全是 laneEdit，按 kind 出步名。
// affectedNodeIds：解散 / 删除 = 令牌里的节点 id；其余为空（undo-shortcuts-ui 对空集不移相机）。

// util/canvas_lane_actions.dart
Future<void> dissolveLaneWithUndo(BuildContext context, WidgetRef ref,
    {required String canvasId, required StyleLane lane});
Future<void> deleteLaneWithContentsWithUndo(BuildContext context, WidgetRef ref,
    {required String canvasId, required StyleLane lane});
```
- CreateLaneCommand：revert = dissolveLane(lane.id)（保险：道里若被系统放进了节点，节点留下、位置不动），保存令牌；apply（重做）= 用 lane-ops-core 的「撤销解散」把道和归属复原（同 id）。
- UpdateLaneCommand：只回这一步动过的字段——rename 只回 label；restyle 回 label / stylePrompt / tintColor（tintColor 为 null ⇒ clearTint: true）；resize 只回 size。apply 同理用 after。道已不在 ⇒ 对象已消失。
- ReorderLanesCommand：revert 目标顺序 = before 里此刻还在的 id（保持 before 次序）+ 此刻有、before 里没有的 id（保持此刻次序）接在后面，再 reorderLanes；apply 同理用 after。
- DissolveLaneCommand / DeleteLaneWithContentsCommand：revert = lane-ops-core 的复原操作（一个事务）；apply = 再执行一次 dissolveLane / deleteLaneWithContents，换上新令牌。
- dissolveLaneWithUndo：dissolveLane → push → `showCanvasUndoSnack`（W3 版，登记这一步的 id，「撤销」= undoSpecific）文案「已解散泳道「X」」；失败 ⇒ laneDeleteFailed 卡、不 push。
- deleteLaneWithContentsWithUndo：道内节点（lane_id == lane.id）有在途任务（`nodeActiveJobProvider(id)` 非 null，node_active_job.dart:11）⇒ 先弹确认框，取消 ⇒ 什么都不做；确认 ⇒ 用 JobQueueService.cancel（同 shell_task_popover.dart:290–293 的取法）取消这些任务，再 deleteLaneWithContents → push → 卡「已删除泳道「X」和 N 个节点」。没有在途任务 ⇒ 不确认直接做。
- 步名：create「新建泳道「X」」、rename「重命名泳道「X」」、restyle「修改泳道「X」风格」、resize「调整泳道「X」厚度」、reorder「调整泳道顺序」、dissolve「解散泳道「X」」、deleteWithContents「删除泳道「X」和 {count} 个节点」。X 为空用 laneUntitled。

## 行为规则与边界情况
1. 新建泳道成功 ⇒ 一步；对话框取消 / 写失败 ⇒ 不进栈。工具栏「添加泳道」与浮动工具条泳道键走同一个 addLaneViaDialog，两边都进栈。
2. 撤销新建 ⇒ 道消失（软删）；重做 ⇒ 同 id 回来、排序位置不变。
3. 编辑框只改名 ⇒「重命名泳道」一步；改风格 / 改色（可连带改名）⇒「修改泳道风格」一步；什么都没改点保存 ⇒ 不进栈。
4. 撤销改风格只回 label / 风格 / 色，不动这期间被拖过的厚度。
5. 拖分界线改厚 ⇒ 一步，撤销只回 size；拖了但 clampLaneSize 后厚度没变 ⇒ 不进栈。
6. 拖标题栏排序 ⇒ 一步；拖动不到 12px（现有阈值）或顺序没变 ⇒ 不进栈；reorderLanes 失败 ⇒ 回滚 + 「更新泳道失败」卡（新增）、不进栈。
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
| laneDissolvedToast | Lane “{lane}” dissolved | 已解散泳道「{lane}」 |
| laneDeletedWithContentsToast | Deleted lane “{lane}” and {count} nodes | 已删除泳道「{lane}」和 {count} 个节点 |
| laneDeleteRunningConfirmTitle | Delete this lane and its contents? | 删除泳道和内容？ |
| laneDeleteRunningConfirmBody | {count} tasks in this lane are still generating. They will be cancelled, and cancelling can't be undone. | 道内有 {count} 个任务正在生成，删除会取消它们，取消无法撤销。 |
| laneDeleteRunningConfirmAction | Cancel tasks and delete | 取消任务并删除 |
（lane-ops-core 若已加过同义的「解散 / 已解散」键就复用、不重复加。现有 laneDeleteConfirmTitle / laneDeleteConfirmBody 若 W2 后已无引用，回报里请主 Agent 删掉。）

## 测试
test/features/canvas/canvas_lanes_controller_test.dart（追加；InMemoryStyleLaneRepository + FakeUnitOfWork）
- 「updateLane 返回改前快照」；「patch 为空返回 null」。
- 「reorderLanes 返回旧顺序；顺序没变返回 null」。
test/features/canvas/util/canvas_lane_actions_test.dart（新建；pumpInkApp + Consumer；InMemory 仓储 + 真的 CanvasLanesController / CanvasNodesController / CanvasHistoryController；RecordingToastService）
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
- lane-ops-core 的令牌类型、复原函数名以 W2 合入为准；令牌里若没有道的 label / 节点数，本片在 canvas_lanes_controller 补字段（本片在 W6 拥有该文件）。
- 「删除泳道和内容」确认后取消任务：若 W2 的 deleteLaneWithContents 已经自己取消任务，本片不要再取消一次（JobQueueService.cancel 幂等，但测试断言要按实际改）。
- 本片动 stage_lane_layer 的回调；W7 cm-lane-menu 接右键菜单时调 canvas_lane_actions.dart 的两个函数，不要再写一份。
- updateLane / reorderLanes 改返回类型：调用方只有 stage_lane_layer（main canvas_view.dart:1098 / 1155 / 1198）和测试。
- 设计缺口②（方向切换不进栈）请设计确认。
