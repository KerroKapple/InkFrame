# cm-lane-menu · 泳道标题栏右键菜单

- 波次 W7 / lane D / 基底 origin/main〔W0–W6 已合入〕（同 lane 前一片是 W6 undo-lanes）
- 依赖切片：canvas-view-split（W0）、menu-split（W0）、multi-select-core（W0）、lane-ops-core（W2，dissolveLane / deleteLaneWithContents）、undo-lanes（W6，UpdateLaneCommand；并把 W2 lane-ops-core 建的 util/canvas_lane_actions.dart 里 `dissolveLaneWithUndo` / `deleteLaneWithContentsWithUndo` 改成进栈——后者「道内有在途任务先确认、确认后取消任务」是 W2 就做好的）、cm-edge-menu（W6，`CanvasMenuHost.viewportPointOf` 与 `InkMenuEntry.note`）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 在泳道标题栏上右键，开「泳道菜单」：改名 · 改风格… ｜ 选中内容（N 个）· 折叠（双击标题）｜ 解散（节点留下）｜ 删除泳道和内容。
- 「改名」让标题栏原地变成输入框：↵ 保存、Esc 退出；一次改名是一步撤销。
- 「删除泳道和内容」平时直接删 + 撤销卡；道内有节点正在生成时先确认（取消任务撤不回）。
- 带内空白处右键不变，仍是空白处菜单。

## 设计依据
画板 ContextMenus.dc.html（生成脚本 /home/user/plan/design/b2_wires.js 第 2 栏「泳道 · 标题栏右键」）：
- 菜单宽 208：`改名`、`改风格…`（lane 图标）｜`选中内容`（select 图标，行尾「3 个」）、`折叠`（键位位写「双击标题」）｜`解散（节点留下）`｜`删除泳道和内容`（danger）。示例标题栏带 accent 描边（被右键的那条）。
- 规则：只认标题栏右键，带内空白处右键仍出空白处菜单；改名 = 标题栏原地变输入框，↵ 存 Esc 退（updateLane）；改风格… 开现有编辑框；选中内容 = lane_id 是这条道的全部节点；解散（节点留下）= 清节点 lane_id、屏幕位置不动；删除泳道和内容 = 一个事务软删道 + 道内节点及其边；两项分开进撤销栈、分开命名「解散泳道」「删除泳道和内容」；都不弹确认、走撤销卡，唯一例外：道内有生成中的任务——取消任务撤不回来，先确认。
- 「包成泳道」不在本菜单（Selection Ctrl G）。
- 设计缺口（按下列默认实现，见回报）：①已折叠的道第四行写什么——写「展开」，键位位同样「双击标题」；②已折叠道上「选中内容」——先展开再选中（选中看不见的卡没有意义）；③空道——「选中内容」置灰、行尾「0 个」；④输入框失焦——等同 ↵ 保存；名字去空白后为空或没变——不写库，直接退出；⑤被右键的标题栏 accent 描边——菜单开着时描边，关菜单即去掉。

## 允许改的文件
- `lib/features/canvas/widgets/lane_title_bar.dart`：新增参数 `editing`、`onRenameSubmit(String)`、`onRenameCancel`、`onSecondaryClick(Offset global)`、`highlighted`；编辑态把名称那块换成内部 `_LaneNameEditor`（单行输入框，走 theme 层现有输入组件；自动聚焦、原名全选），↵ / 失焦 → `onRenameSubmit`，Esc → `onRenameCancel` 且在输入框自己的 Focus 上 `KeyEventResult.handled`，不冒泡到画布。编辑态下 `onDoubleTap` 传 null（不折叠）。`highlighted` 时外加 accent 描边。
- `lib/features/canvas/widgets/stage/stage_lane_layer.dart`（由 canvas-view-split 新建，W2 / W4 / W6 已改；对应 main canvas_view.dart 第 1020–1112 行 `_buildLaneTitleBars`、第 1187–1210 行 `_onEditLane`；`_onDeleteLane` 已被 W2 删掉）：给每个 `LaneTitleBar` 接右键开菜单（`openLane`）、编辑态（watch `laneRenameProvider`）、改名提交、高亮（菜单请求的 laneId == 本道）；编辑态时外层拖拽重排 `GestureDetector`（main 第 1077–1099 行）的 `onPanUpdate` / `onPanEnd` 传 null；`onEdit` 改调 `editLaneStyleWithUndo`（W6 版 `_onEditLane` 搬走后删掉）。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`（menu-split 新建；`CanvasMenuKind` / `CanvasMenuRequest` / `CanvasMenuController` 在这里；链：W5 rail-drag-assets → W6 cm-edge-menu → W7 本片）：`CanvasMenuKind` 加 `lane`；`CanvasMenuRequest` 加 `laneId`；`CanvasMenuController.openLane(Offset anchor, String laneId)`。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（W5 / W6 已改）：宿主分派 `lane` 种类到 `lane_menu_entries.dart`。
- `lib/features/canvas/widgets/canvas_menu/lane_menu_entries.dart`（新）：分组构造 + 选中后的分派 `_pickLane`。
- `lib/features/canvas/util/lane_menu_model.dart`（新）：纯判据。
- `lib/features/canvas/providers/lane_rename_controller.dart`（新）：哪条道正在原地改名（W8 wrap-in-lane「标题栏进改名」也可复用）。
- `lib/features/canvas/providers/lane_collapse_controller.dart`：加 `expand(String laneId)`（幂等）。
- `lib/features/canvas/util/canvas_lane_actions.dart`（由 **W2 lane-ops-core** 新建、W6 undo-lanes 改成进栈；W7 无他片占用）：追加 `editLaneStyleWithUndo`（把 stage_lane_layer 里 W6 版 `_onEditLane`——拿快照 → showLaneEditDialog → updateLane（W6 起返回改前快照）→ record UpdateLaneCommand——原样搬过来，标题栏编辑键与菜单共用）与 `renameLaneWithUndo`（快照 → `updateLane(label:)` → `record(UpdateLaneCommand(kind: LaneEditKind.rename, before:, after:))`，与 `_onEditLane` 的 rename 分支同一手法）。`dissolveLaneWithUndo` / `deleteLaneWithContentsWithUndo` 只调用、不改。
- 测试：`test/features/canvas/util/lane_menu_model_test.dart`（新）、`test/features/canvas/widgets/lane_title_bar_test.dart`、`test/features/canvas/widgets/canvas_lane_menu_test.dart`（新）、`test/features/canvas/lane_collapse_controller_test.dart`。

## 不许碰的文件
- 同波 tc-stale-marks：`node_card.dart`、`left_rail/outline_panel.dart`、`util/outline_model.dart`、`util/take_staleness.dart`、`providers/stale_takes_provider.dart`。
- 同波 cm-drag-insert-narrative：`widgets/stage/node_card_slot.dart`、`providers/node_drag_delta.dart`、`edge_painter.dart`、`widgets/stage/stage_edge_layer.dart`、`widgets/stage/stage_overlays.dart`、`util/narrative_drop_insert.dart`、`util/canvas_narrative_drop_actions.dart`。
- 同波 clipboard：`providers/canvas_nodes_controller.dart`、`canvas_menu/clipboard_menu_items.dart`、`util/canvas_node_delete.dart`、`providers/canvas_clipboard.dart`、`providers/canvas_pointer.dart`、`util/canvas_paste_actions.dart`、`shortcuts/clipboard_keys.dart`、`canvas_view.dart`（clipboard-paste 加 MouseRegion）。
- 同波菜单栏：`shell/widgets/shell_menu_bar.dart`、`shell/widgets/shell_platform_menu_bar.dart`、`shell/util/*`、`theme/components/ink_menu_bar.dart`、`shell/widgets/ink_shell.dart`、`app.dart`、`main.dart`。
- 只调用、不改：`providers/canvas_lanes_controller.dart`、`providers/canvas_selection_controller.dart`（`replace`）、`lane_edit_dialog.dart`、`models/commands/lane_edit_command.dart`（W6 的）、`widgets/stage/stage_pointer_layer.dart`（只 import 它公开的 `SecondaryClickDetector`）、`theme/components/ink_menu_panel.dart`。

## 具体改动
```dart
// util/lane_menu_model.dart
enum LaneMenuAction { rename, editStyle, selectContents, toggleCollapse, dissolve, deleteWithContents }
Set<String> laneContentIds({required String laneId, required List<CanvasNode> nodes}); // node.laneId == laneId
bool canSelectLaneContents(Set<String> contentIds) => contentIds.isNotEmpty;
bool collapseRowSaysExpand(bool collapsed) => collapsed;                               // 第四行文案：折叠 / 展开
String? renameCommitLabel({required String original, required String input});         // trim 后空或等于原名 ⇒ null（不写库）
// providers/lane_rename_controller.dart
final laneRenameProvider = AutoDisposeNotifierProviderFamily<LaneRenameController, String?, String>(…); // 值 = 正在改名的 laneId
class LaneRenameController { void start(String laneId); void stop([String? laneId]); }
// canvas_menu_request.dart（CanvasMenuController）
void openLane(Offset anchor, String laneId);
// util/canvas_lane_actions.dart（追加）
Future<void> editLaneStyleWithUndo(BuildContext c, WidgetRef ref, {required String canvasId, required StyleLane lane});
Future<void> renameLaneWithUndo(BuildContext c, WidgetRef ref, {required String canvasId, required StyleLane lane, required String label});
```
- 右键判定：「次键按下 → 抬起、没挪出点击容差才算、抬起时报、给按下点」——canvas-view-split 已把它公开为 `stage/stage_pointer_layer.dart` 的 `SecondaryClickDetector({required ValueChanged<PointerDownEvent> onSecondaryClick, required Widget child})`，lane_title_bar.dart 直接用它包住标题栏（只 import，不改 stage_pointer_layer）。锚点 = `CanvasMenuHost.viewportPointOf(context, down.position)`（W6 cm-edge-menu 加的静态方法）。
- `_pickLane` 分派：rename → `laneRenameProvider.start(id)`；editStyle → `editLaneStyleWithUndo`；selectContents → 折叠则 `laneCollapseProvider.expand(id)` 再 `canvasSelectionController.replace(ids)`（multi-select-core W0 已加 `replace`）；toggleCollapse → `laneCollapseProvider.toggle`；dissolve → `dissolveLaneWithUndo`；deleteWithContents → `deleteLaneWithContentsWithUndo`（在途任务确认与取消都在它里面，本片不另做确认框）。
- 改名提交：stage_lane_layer 收 `onRenameSubmit(text)` → `renameCommitLabel` 为 null ⇒ 只 `stop`；否则 `renameLaneWithUndo`，失败弹 `laneUpdateFailed`（现有键），都退出编辑态。

## 行为规则与边界情况
1. 标题栏上右键单击（没拖动）：在按下点开泳道菜单；按住右键拖：不开菜单。
2. 泳道带内空白处右键：仍是空白处菜单；卡片上右键仍是节点菜单。
3. 平移工具（H / 空格）下标题栏层不收指针（StagePanGate 现状），右键不开菜单。
4. 「改名」：菜单关、焦点进标题栏输入框、原名全选；↵ 保存，一步撤销「重命名泳道」；Esc 退出不写库，且不清空画布选中；点画布别处（失焦）= 保存。
5. 名字去空白后为空或与原名相同：不写库、退出编辑态。
6. 编辑态下双击输入框只选词，不折叠；在输入框里拖动只选字，不触发泳道重排。
7. 编辑态下又对另一条道选「改名」：前一条按失焦规则先保存，再进新的一条（`laneRenameProvider` 一次只有一条）。
8. 改名写库失败：控制器回滚内存，弹「泳道更新失败」，退出编辑态（显示旧名）；栈里无新步。
9. 「改风格…」：开现有泳道编辑框，保存走 undo-lanes 已有的进栈路径。
10. 「选中内容」：选中 = lane_id 等于这条道的全部节点（替换原选中）；行尾写数量；空道置灰「0 个」；折叠道先展开再选中。
11. 「折叠 / 展开」：与双击标题、标题栏折叠键同一个 `toggle`；不进撤销栈（undo-lanes 已定）。
12. 「解散（节点留下）」：不确认；节点屏幕位置不动、lane_id 清空、道软删；撤销卡 + 一步「解散泳道」。
13. 「删除泳道和内容」，道内无在途任务：不确认，一个事务软删道 + 道内节点 + 它们的边；撤销卡 + 一步「删除泳道和内容」。
14. 道内有在途任务：菜单项照样可点；由 `deleteLaneWithContentsWithUndo` 先弹确认（undo-lanes 已做），取消 = 什么都不做。
15. 标题栏垃圾桶仍是「解散」（W2 / W6 现状），只有菜单给「删除泳道和内容」。
16. 菜单开着时这条道被删（撤销 / 别处）：菜单不出任何项（emptyText），与节点菜单同款。
17. 菜单开着时被右键的那条标题栏 accent 描边；菜单关即去掉。
18. 「折叠」行尾是文字「双击标题」（ARB），不是快捷键；其余行无键位。
19. mac / Windows 无差异（右键 = 次键；mac 触控板双指点按同样是次键事件）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasLaneMenuRename | Rename | 改名 |
| canvasLaneMenuEditStyle | Edit style… | 改风格… |
| canvasLaneMenuSelectContents | Select contents | 选中内容 |
| canvasLaneMenuCount | {count, plural, one{1 node} other{{count} nodes}} | {count} 个 |
| canvasLaneMenuCollapse | Collapse | 折叠 |
| canvasLaneMenuExpand | Expand | 展开 |
| canvasLaneMenuCollapseHint | Double-click title | 双击标题 |
| canvasLaneMenuDissolve | Dissolve (keep nodes) | 解散（节点留下） |
| canvasLaneMenuDeleteWithContents | Delete lane and contents | 删除泳道和内容 |
（输入框占位复用 laneNameHint；确认框、撤销卡文案与步名「解散泳道」「删除泳道和内容」「重命名泳道」都由 undo-lanes 定义，本片不加。）

## 测试
`test/features/canvas/util/lane_menu_model_test.dart`（新）
- `laneContentIds 只含 lane_id 相等的节点`（另一条道的、无道的都不在）。
- `canSelectLaneContents：空道 false`；`collapseRowSaysExpand：折叠态 true`。
- `renameCommitLabel：空白 / 同名 ⇒ null，前后空白被去掉`。
`test/features/canvas/widgets/lane_title_bar_test.dart`（追加）
- `editing=true 显示输入框且原名全选`；`↵ → onRenameSubmit(新名)`；`Esc → onRenameCancel，不调 onRenameSubmit`；`失焦 → onRenameSubmit`。
- `editing=true 时双击不触发 onToggleCollapse`。
- `右键单击 → onSecondaryClick(按下点)`；`按住右键拖出容差 → 不调用`。
`test/features/canvas/widgets/canvas_lane_menu_test.dart`（新，CanvasView + 真 CanvasNodes / CanvasLanes / CanvasHistory 控制器 + test/_harness/fake_repositories.dart 的 InMemory 仓储 + FakeUnitOfWork，两条泳道；RecordingToastService 断言撤销卡）
- `标题栏右键开泳道菜单，六项按稿的顺序`；`带内空白处右键开空白处菜单`。
- `选中内容：选中集 == 道内节点，行尾「2 个」`；`空道：选中内容置灰`；`折叠道：先展开再选中`。
- `改名：输入新名 ↵ → 道名变了`；`名字没变 ↵ → 不写库`；`Esc → 不写库，画布选中不变`；`改名 ↵ 后 Ctrl Z：回旧名`。
- `解散：不弹对话框，道没了、节点留下且 lane_id 为 null`。
- `删除泳道和内容：道与道内节点都软删，撤销栈多一步`（无在途任务）。
- `菜单开着时被右键的标题栏有 accent 描边`；`菜单折叠态第四行是「展开」`。
`test/features/canvas/lane_collapse_controller_test.dart`（追加）：`expand 幂等：已展开不变，已折叠变展开`。

## 变异点
1. `laneContentIds` 改成「laneId 相等或为 null」→ `只含 lane_id 相等的节点` 红。
2. 菜单「删除泳道和内容」误接成 `dissolveLaneWithUndo` → `删除泳道和内容：道与道内节点都软删` 红。
3. 标题栏 Esc 改成也调 onRenameSubmit → `Esc → onRenameCancel，不调 onRenameSubmit` 红。
4. 带内空白处右键也开泳道菜单 → `带内空白处右键开空白处菜单` 红。
5. `renameCommitLabel` 同名也返回原名 → `名字没变 ↵ → 不写库` / model 用例 红。
6. `renameLaneWithUndo` 不 record → `改名 ↵ 后 Ctrl Z：回旧名` 红。
7. 折叠道「选中内容」不先 expand → `折叠道：先展开再选中` 红。
8. 第四行文案不随折叠态变 → `菜单折叠态第四行是「展开」` 红。
9. 编辑态仍响应双击折叠 → `editing=true 时双击不触发 onToggleCollapse` 红。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条做变异。
- 截图场景（widget = CanvasView，两条横向泳道「水墨风格」（3 个节点）、「夜景」（空））：①右键「水墨风格」标题栏的菜单（「选中内容 · 3 个」，标题栏 accent 描边）；②改名编辑态；③右键「夜景」：选中内容置灰「0 个」；④折叠后的菜单（第四行「展开」）。

## 风险与不确定
- slices.json 原注把「道内有生成中任务」判据放在 lane_menu_model；W2 lane-ops-core 已把确认 + 取消做进 `deleteLaneWithContentsWithUndo`（W6 undo-lanes 只改了它的撤销卡），本片不再重复一份判据，避免两处口径漂移。
- `canvas_lane_actions.dart`（W2 lane-ops-core 新建、W6 undo-lanes 改过）W7 无他片占用，本片追加两个函数。
- （复核已定）入口名：`dissolveLaneWithUndo` / `deleteLaneWithContentsWithUndo`（W2 建、签名 `(context, ref, {canvasId, lane})`），`UpdateLaneCommand({kind, before, after})`（W6）。
- 输入框在视口层（标题栏层不随缩放）；Esc 必须在输入框的 Focus 上拦下，否则 esc-ladder 的画布 Esc 会清选中。
- 依赖 W6 cm-edge-menu 的 `viewportPointOf` 与 `InkMenuEntry.note`；若 W6 没落成，本片在 canvas_menu_host.dart 自己补 `viewportPointOf`，「3 个」退为拼进 label。
