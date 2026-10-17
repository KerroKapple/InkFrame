# cm-multi-select-menu · 多选右键菜单（选中 ≥2）
- 波次：W12 / lane：A / 基底：origin/main（W0–W11 已合入）
- 依赖切片：menu-split（W0）、multi-select-core（W0）、node-cost（W2）、node-disabled-flag（W8）、align-distribute-arrange（W8）、wrap-in-lane（W8）、batch-run-dialog（W11）、cm-delete-bridge（W6，删除走它改过的 deleteNodesWithUndo）
- 阻塞决定：无（ContextMenus W5「多选时 Ctrl ↵」按建议 A：生成全部能生成的，确认规则归 TakesCost 运行对话框）

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W11 已合入）起新分支 `feat/cm-multi-select-menu`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法，用现有 patchTypeConfig / update。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片只「接菜单」：对齐 / 分布 / 包成泳道 / 运行对话框的实现全部调用前序切片已有的入口，不在这里重写任何几何或提交逻辑。
10. `node_menu_model.dart` 在 W12 只归本片：共享的 targets / kind 判据写在这里，W13 selection-toolbar 直接复用，不另写一份。

## 目标
- 在选中集里任一张卡上右键、且选中 ≥2 张时，弹出「多选菜单」取代原来的节点菜单；单张仍是节点菜单。
- 菜单三组：生成 N 个 · 约 $x（Ctrl ↵）、复制一份（Ctrl D）| 对齐 ›、分布 ›、包成泳道（Ctrl G）、加入泳道 › | 删除（Del）。
- 不可用的项置灰不隐藏；花费算不出价的写「另 N 个价格未知」。

## 设计依据
- `b2/project/ContextMenus.dc.html` ›「多选 · 右键选中集里任一张，且选中 ≥ 2」：
  - 「取代节点菜单（nodeMenuTargets 已给出选中集）；单张仍出节点菜单」。
  - 「生成 N 个：只算 isGenerableNode 且没停用的；花费 = 各节点 estimateCostUsd 之和，无计费模型记『另 N 个价格未知』」。
  - 「何时确认、单次上限、入队顺序（按 data 边依赖）都以 TakesCost 的运行对话框为准，这里不另定」。
  - 「对齐按选区包围盒；横截轴对齐只在目标同属一条道时可点（位置决定泳道归属）」。
  - 「分布：等距要 ≥ 3 张；对齐 / 分布整批一个事务」（moveNodes，align-distribute-arrange 已实现）。
  - 「包成泳道（Ctrl G）：整批移入，标题栏进改名；新道插在哪见 Selection Q5」（wrap-in-lane 已实现）。
  - 对齐子菜单：左对齐 · 水平居中 · 右对齐 | 顶对齐 · 垂直居中 · 底对齐（画板在第二组旁标「跨泳道」）；分布子菜单：水平等距 · 垂直等距。
  - 顶部总则：「排序沿用节点菜单：动作 | 编排 | 删除。不可用的置灰不隐藏，键位都从快捷键表取」。
- `b2/project/Selection.dc.html` ›「对齐 · 分布 · 排布 · 吸附」：「多选右键『对齐 ›』与浮动条同一块」；对齐键 Alt A D W S H V、分布 Alt Shift H V。
- plan.md 第 3 节：「multi-menu：『另 N 个价格未知』文案统一」。
- 设计缺口：画板菜单顶上画了一行「已选 3 · 约 $0.42」，没说是标题行还是可点项；本片不画这一行（价格已在「生成 N 个」行尾），见风险。
- 设计缺口：N = 0（选中里没有可生成的）时该行写什么没画。本片：标签退回现有 `canvasNodeMenuGenerate`（「生成」），置灰。

## 允许改的文件
- `lib/features/canvas/util/node_menu_model.dart`：新增 kind 判据、可生成集合、花费汇总、横截轴对齐判据、分布判据（纯函数）。
- `lib/features/canvas/widgets/canvas_menu/multi_menu_entries.dart`（新建）：多选菜单分组构建 + 执行派发。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（menu-split 新建，名字以合入后为准；W12 归本片）：`CanvasMenuKind.node` 且目标 ≥2 ⇒ 改出多选面板；`CanvasMenuKeys` 加 `multiMenu`；派发到 `runMultiMenuPick`。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（menu-split 新建）：追加一行，登记多选菜单分组。
- `lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`（menu-split 新建）：仅把「加入泳道 ›」子菜单的构建函数改成公开（`buildLaneSubmenuGroups`），供多选菜单复用；不改其行为。**不在归属表里，W12 无人占用，回报里说明。**
- `test/features/canvas/util/node_menu_model_test.dart`：追加用例。
- `test/features/canvas/widgets/canvas_multi_menu_test.dart`（新建）。

## 不许碰的文件
- W12 其他切片：toast_service / toast_center / notification_* / export_video_dialog / canvas_snackbars / app_preferences / file_preferences_service / notifications_section（toast-category-mute）；left_rail_state / canvas_left_rail / left_rail_panel / script_panel / shot_config_inspector / canvas_shot_notes_actions（rail-script-panel）；canvas_prompt_bar / mention_* / inspector_submit_controller / escape_ladder（prompt-bar-mention-ui）；gallery/* 与 `canvas_menu/node_locate_gallery_entry.dart`（locate-in-gallery）。
- W13 selection-toolbar 的 `selection_toolbar*.dart`（后序，本片不预建）。
- `lib/features/canvas/widgets/create_node_menu.dart`（barrel）、`lib/features/canvas/models/canvas_node.dart`、`canvas_tool_actions.dart`、`canvas_node_flags.dart`、align / wrap / batch-run 各自的实现文件（只调用）。
- ARB、`lib/l10n/generated/`、`docs/CLAUDE.md`。

**同波（W12）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- toast-category-mute：`lib/core/interfaces/toast_service.dart`、`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/canvas_snackbars.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/notifications/providers/toast_center.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/features/notifications/widgets/notification_bell.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/_harness/fake_toast_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/canvas_snackbars_test.dart`、`test/features/notifications/providers/toast_center_test.dart`、`test/features/notifications/widgets/job_notification_listener_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
- rail-script-panel：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/canvas/widgets/shot_config_inspector.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`
- prompt-bar-mention-ui：`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/canvas_prompt_bar.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/characters_section.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/features/canvas/widgets/mention_text_controller.dart`、`test/features/canvas/providers/inspector_submit_mention_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/characters_section_mounted_guard_test.dart`、`test/features/canvas/widgets/mention_text_controller_test.dart`、`test/features/canvas/widgets/prompt_bar_mention_test.dart`
- locate-in-gallery：`lib/features/canvas/widgets/canvas_menu/node_locate_gallery_entry.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/providers/gallery_selection.dart`、`lib/features/gallery/util/locate_in_gallery.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_grid.dart`、`test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`、`test/features/gallery/util/locate_in_gallery_test.dart`、`test/features/gallery/widgets/gallery_locate_test.dart`

## 具体改动
node_menu_model.dart（追加；现有 `nodeMenuTargets` 约第 74 行、`isGenerableNode` 约第 78 行、`duplicateSources` 约第 89 行保持不变）：
```dart
enum NodeMenuKind { single, multi }
NodeMenuKind nodeMenuKindOf(Set<String> targets);              // ≥2 ⇒ multi
List<CanvasNode> batchGenerableNodes(List<CanvasNode> targets); // isGenerableNode && !isDisabled，顺序照旧
@immutable class BatchCostSummary { final int generableCount; final double knownUsd; final int unknownCount; }
BatchCostSummary summarizeBatchCost(List<CanvasNode> generable, double? Function(CanvasNode) costOf); // null = 算不出价
bool sameLaneTargets(List<CanvasNode> targets);                 // 全部 laneId 相同（全为 null 也算同一条）
bool canAlignCrossAxis(List<CanvasNode> targets);               // = targets.length >= 2 && sameLaneTargets
bool canAlongAxisAlign(List<CanvasNode> targets);               // targets.length >= 2
bool canDistribute(List<CanvasNode> targets);                   // targets.length >= 3
bool isCrossAxisAlign(AlignOp op, LaneDirection direction);     // horizontal 道：顶/垂直居中/底是横截轴；vertical 道反之
```
- `isDisabled` 来自 `models/canvas_node_flags.dart`（node-disabled-flag 新建，名字以合入后为准）。
- `AlignOp` / 分布轴枚举来自 align-distribute-arrange（提供，签名以合入后为准）；若它们没导出枚举，本文件新建 `enum MultiAlign { left, hCenter, right, top, vCenter, bottom }` 与 `enum MultiDistribute { horizontal, vertical }`，在 multi_menu_entries 里映射。
- `LaneDirection` 现有：`lib/features/canvas/util/lane_geometry.dart` 第 5 行 `enum LaneDirection { horizontal, vertical }`；方向 provider 现有 `canvasLaneDirectionProvider`（canvas_lanes_controller.dart 约第 170 行）。

multi_menu_entries.dart（新建）：
```dart
enum MultiMenuAction { generate, duplicate, alignSubmenu, align, distributeSubmenu, distribute, wrapInLane, laneSubmenu, moveToLane, removeFromLane, delete }
@immutable class MultiMenuPick { /* action + MultiAlign? + MultiDistribute? + String? laneId；值相等 = 同一项（菜单行 ValueKey 靠它） */ }
List<List<InkMenuEntry<MultiMenuPick>>> buildMultiMenuGroups(BuildContext context, WidgetRef ref, AppLocalizations l, {required String canvasId, required Set<String> targetIds});
void runMultiMenuPick(BuildContext context, WidgetRef ref, {required String canvasId, required Set<String> targetIds, required MultiMenuPick pick});
```
- 生成行：`batchGenerableNodes` + `summarizeBatchCost(costOf: node-cost 的 estimateNodeCost 取 usd)`（node-cost 提供，签名以合入后为准）；keyHint 取 `canvasShortcutLabel((i) => i is CanvasGenerateIntent, isMac: ...)`（shortcut_catalog.dart 约第 127 行，现有）；执行 = batch-run-dialog 的运行对话框入口，**与多选 Ctrl ↵ 同一个函数、同一份入参（targetIds）**（batch-run-dialog 提供，签名以合入后为准）。
- 复制一份：`duplicateNodes(context, ref, canvasId:, nodeIds:)`（canvas_tool_actions.dart 约第 440 行，现有）；enabled = `duplicateSources(targets).isNotEmpty`。
- 对齐 › / 分布 ›：子菜单两组 / 一组；横截轴三项 enabled = `canAlignCrossAxis`，主轴三项 enabled = `canAlongAxisAlign`；分布两项 enabled = `canDistribute`；keyHint 取 align-distribute-arrange 登记的 Intent。执行调 align-distribute-arrange 的动作函数（一次 moveNodes，一步撤销）。
- 包成泳道：执行调 wrap-in-lane 的 Ctrl G 动作（同一个函数）；keyHint 取它的 Intent。
- 加入泳道 ›：复用 `buildLaneSubmenuGroups`（原 `_laneGroups`，create_node_menu.dart 约第 684 行，拆分后在 node_menu_entries）；执行 `moveNodesToLane(context, ref, canvasId:, nodeIds:, laneId:)`（canvas_tool_actions.dart 约第 554 行）。
- 删除：`deleteNodesWithUndo(context, ref, canvasId:, nodeIds:)`（canvas_node_delete.dart 约第 48 行），danger 样式，keyHint 取 `DeleteSelectionIntent`。
canvas_menu_host.dart：节点菜单分支先算 `nodeMenuKindOf(nodeMenuTargets(selection, request.nodeId))`；multi ⇒ `InkMenuPanel<MultiMenuPick>(key: CanvasMenuKeys.multiMenu, ...)`，选中交给 `runMultiMenuPick`，焦点交还画布与节点菜单同一做法（`_MenuFocusHandoff.toCanvas`）。

## 行为规则与边界情况
- R1：右键的卡在选中集里且选中 ≥2 ⇒ 多选菜单；右键的卡不在选中集 ⇒ 画布先单选它 ⇒ 节点菜单（现状不变）。
- R2：生成行只数 isGenerableNode 且未停用的；N = 0 ⇒ 标签「生成」、置灰。停用的不进 N、不计价。
- R3：花费 = 已知价之和；有算不出价的追加「另 N 个价格未知」；全部算不出 ⇒ 只写「生成 N 个 · 另 N 个价格未知」，不写 $0.00。
- R4：生成行点了打开运行对话框，传入整个选中集（对话框自己列「跳过 · 已停用」）；本片不弹任何确认。
- R5：横截轴对齐（horizontal 道：顶 / 垂直居中 / 底；vertical 道：左 / 水平居中 / 右）只在全部目标 laneId 相同时可点；主轴三项 ≥2 即可点。
- R6：分布 < 3 张整组置灰（子菜单行本身仍可展开，项置灰）。
- R7：复制一份只复制配置节点；全是产物 ⇒ 置灰。
- R8：加入泳道子菜单与节点菜单完全同款（全在某道则那一道打勾不可点；「移出泳道」至少一张在道里才可点）；画布无泳道 ⇒ 「加入泳道 ›」置灰。
- R9：删除走 deleteNodesWithUndo（cm-delete-bridge 的「连续被删的一段」接上规则照旧），一张撤销卡。
- R10：菜单开着时选中集里的卡被删光到 <2 ⇒ 下一帧菜单重建为空组即关闭（与节点菜单「右键的卡已不在」同口径）。
- R11：对齐 / 分布 / 包成泳道 / 复制 / 删除 都只经各自动作函数进撤销栈；本片不直接 push 撤销命令。
- R12：mac 显示 ⌘ 前缀，其余 Ctrl（`canvasShortcutLabel(isMac:)` 已处理）；无其他平台差异。

## 新文案键
（align-distribute-arrange / wrap-in-lane / batch-run-dialog / multi-select-inspector 若已建同义键，复用、不重复建，回报里写明复用了哪些。）
| key | en | zh |
|---|---|---|
| canvasMultiMenuGenerate | `{count, plural, =1{Generate 1} other{Generate {count}}}` | `生成 {count} 个` |
| canvasMultiCostApprox | `≈ {cost}` | `约 {cost}` |
| canvasMultiCostUnknown | `{count, plural, =1{1 more unpriced} other{{count} more unpriced}}` | `另 {count} 个价格未知` |
| canvasMultiMenuAlign | Align | 对齐 |
| canvasMultiMenuDistribute | Distribute | 分布 |
| canvasMultiMenuWrapInLane | Wrap in lane | 包成泳道 |
| canvasAlignLeft / canvasAlignHCenter / canvasAlignRight | Align left / Align horizontal centers / Align right | 左对齐 / 水平居中 / 右对齐 |
| canvasAlignTop / canvasAlignVCenter / canvasAlignBottom | Align top / Align vertical centers / Align bottom | 顶对齐 / 垂直居中 / 底对齐 |
| canvasDistributeHorizontal / canvasDistributeVertical | Distribute horizontally / Distribute vertically | 水平等距 / 垂直等距 |

## 测试
先写、先红。
- `test/features/canvas/util/node_menu_model_test.dart`（追加）：
  - `'nodeMenuKindOf returns multi only for two or more targets'`：1 张 single，2 张 multi。
  - `'batchGenerableNodes skips disabled and non-generable nodes'`：停用的 image 配置、空提示词、产物、文本都不进。
  - `'summarizeBatchCost sums known prices and counts unknown ones'`：costOf 返回 0.2 / null / 0.3 ⇒ knownUsd 0.5、unknownCount 1。
  - `'summarizeBatchCost never reports zero for all-unknown'`：全 null ⇒ knownUsd 0、unknownCount = N（UI 据此不写 $0.00）。
  - `'canAlignCrossAxis requires all targets in the same lane'`：两道混选 false；同道 true；全无道 true。
  - `'isCrossAxisAlign follows lane direction'`：horizontal 下 top 为真、left 为假；vertical 反之。
  - `'canDistribute requires at least three targets'`。
- `test/features/canvas/widgets/canvas_multi_menu_test.dart`（新建；ProviderScope 覆写 fake 仓储 + 选中集，与 `canvas_node_menu_test.dart` 同一套 harness）：
  - `'right-click inside a multi selection opens the multi menu'`：找到 `CanvasMenuKeys.multiMenu`，找不到 `nodeMenu`。
  - `'right-click on an unselected card still opens the node menu'`。
  - `'generate row shows count and unknown-price suffix'`：3 张配置其中 1 张无计费模型 ⇒ 文案含「生成 2 个」与「另 1 个价格未知」（按 en 断言）。
  - `'generate row opens the batch run dialog with the selection'`：覆写运行对话框入口为 spy，断言收到的 id 集合 = 选中集。
  - `'cross-axis align items are disabled across lanes'`：两道各一张 ⇒ 顶对齐行 disabled，左对齐行 enabled（horizontal）。
  - `'distribute items are disabled below three targets'`。
  - `'delete removes all targets with one undo toast'`。

## 变异点
- M1：把 `nodeMenuKindOf` 的 `>= 2` 改成 `>= 1` → `'right-click on an unselected card still opens the node menu'`、`'nodeMenuKindOf returns multi only…'` 变红。
- M2：`batchGenerableNodes` 去掉 `!isDisabled` → `'batchGenerableNodes skips disabled…'` 变红。
- M3：`summarizeBatchCost` 把 null 当 0 计入 → `'summarizeBatchCost sums known prices and counts unknown ones'` 变红。
- M4：`canAlignCrossAxis` 去掉 sameLaneTargets → `'canAlignCrossAxis requires…'` 与 `'cross-axis align items are disabled across lanes'` 变红。
- M5：`isCrossAxisAlign` 把方向判反 → `'isCrossAxisAlign follows lane direction'` 变红。
- M6：`canDistribute` 改成 `>= 2` → `'canDistribute requires…'`、`'distribute items are disabled below three targets'` 变红。
- M7：生成行改为只传 `batchGenerableNodes` 的 id → `'generate row opens the batch run dialog with the selection'` 变红。

## 验收
- `flutter analyze lib test`。
- `flutter test --exclude-tags golden test/features/canvas/util/node_menu_model_test.dart test/features/canvas/widgets/canvas_multi_menu_test.dart test/features/canvas/widgets/canvas_node_menu_test.dart test/features/canvas/widgets/create_node_menu_test.dart`，再跑整个 `test/features/canvas/`。
- 变异 M1–M7 逐条。
- 截图：`CanvasScreen`（或 menu-split 后的舞台宿主）+ ProviderScope 覆写 InMemory 节点 / 泳道仓储（两道、各 2 张配置 + 1 张产物，其中一张停用、一张自定义接口无价），选中 4 张后在其中一张上右键：①多选菜单全貌；②「对齐 ›」子菜单（顶对齐组置灰）；③「加入泳道 ›」子菜单。

## 风险与不确定
- node-cost 的 `estimateNodeCost` 返回形状（usd 可空 + 明细）以合入后为准；本片只要 `double?`。
- batch-run-dialog 的入口函数名 / 参数、align-distribute-arrange 的动作函数与 Intent 名、wrap-in-lane 的 Ctrl G 函数名都以合入后为准。
- 画板与 Selection 板不一致：ContextMenus 写「横截轴对齐只在同属一条道时可点」，Selection 写「跨轴对齐不把卡挤出原道：夹在各自的带里」。按 plan（slices notes：判据放进 node_menu_model）取 ContextMenus 的置灰规则；W8 的夹带实现保留不动。
- 「已选 3 · 约 $0.42」标题行未实现（InkMenuPanel 是否支持标题行以 menu-split 为准）；若主 Agent 要加，另开小片。
- `buildLaneSubmenuGroups` 公开化需要改 node_menu_entries.dart（不在归属表，W12 无人占用）。
