# selection-toolbar · 选中后浮出的工具条
- 波次：W13 / lane：A / 基底：origin/main（W0–W12 已合入，含 cm-multi-select-menu）
- 依赖切片：multi-select-core（W0）、canvas-view-split（W0）、menu-split（W0）、node-cost（W2）、marquee-select（W3）、group-drag（W5）、node-disabled-flag（W8）、align-distribute-arrange（W8）、wrap-in-lane（W8）、tc-next-shot-first-frame（W10）、batch-run-dialog（W11）、cm-multi-select-menu（W12）
- 阻塞决定：无。Selection Q3 按建议 B：单选配置节点出精简条，不放「生成」（生成留在提示词条，共用 generate_gate.dart）

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W12 已合入）起新分支 `feat/selection-toolbar`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行（本片不需要追加）。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法，用现有 patchTypeConfig / update。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 按钮的可用性判据一律调用 `node_menu_model.dart`（W12 已加的 kind / 可生成 / 花费 / 对齐判据），工具条不另写判据；执行一律调用右键菜单同一个动作函数。

## 目标
- 选中节点后，在选区上方居中浮出一条小工具条，按选区类型变：单选配置 = 加入泳道 · 复制一份 · ⋯；单选产物 = 存为角色 · 当下一镜的首帧 · ⋯；多选 = 「N 个 · 约 $x」· 生成 M 个 · 对齐 ▾ · 包成泳道 · ⋯。
- ⋯ 打开这一选区的右键菜单；拖动 / 平移 / 缩放 / 连线中不出，手停 150ms 后淡入。
- 设置 › 节点布局加开关「选中时显示浮动工具条」，默认开。

## 设计依据
- `b2/project/Selection.dc.html` ›「选中后浮出的工具条 · 跟着选区类型变」：
  - 三种样稿：「单选 · 配置节点（生成在提示词条上，这里不重复）：加入泳道 / 复制一份」「单选 · 产物：存为角色 / 当下一镜的首帧」「多选：4 个 · 约 $2.10 | 生成 3 个 | 对齐 | 包成泳道」，末尾都是 ⋯。
  - 「有选中、且不在拖动 / 平移 / 缩放 / 连线中才出；手停 150ms 后淡入」。
  - 「选区上方居中隔 8，顶到舞台顶部工具条就翻到下方；不进 Tab 序」。
  - 「按钮取自动作表、与右键同源；⋯ = 这一选区的右键菜单」。
  - 「『生成 N 个』只数配置节点（停用的不算），一个都没有就不出；不放颜色（节点无此字段）」。
  - 「『生成 N 个』与多选 Ctrl ↵ 都打开 TakesCost 的运行对话框……规则只在那张板」。
  - 「需：设置 › 节点布局『选中时显示浮动工具条』默认开，AppPreferences 新字段」。
  - 样稿尺寸：条内边距 3、按钮间隙 1、圆角 6（`InkRadius.bentoBtn`）、按钮高 26、按钮横向内边距 7、字号 11、浮层阴影；多选计数用等宽 10 号；「生成」为主色按钮。
  - Q3：「建议 B，提示词条与检查器已共用同一道生成闸（S1 已修），浮动条再放一个生成只是重复」。
- 设计缺口：单选文本 / 镜头 / 便签按「单选配置」处理（加入泳道 · 复制一份 · ⋯），画板没单独画。
- 设计缺口：选区整个在视口外、工具条翻到下方后压到底部提示词条、左右顶出视口时怎么办，画板没画。本片：选区与视口无交集 ⇒ 不出；左右夹在视口内留 `InkSpacing.md`；下方不避让提示词条（风险里记）。
- 设计缺口：右键菜单开着时工具条是否留着没画。本片：任一画布菜单开着 ⇒ 隐藏。

## 允许改的文件
- `lib/features/canvas/util/selection_toolbar_model.dart`（新建）：选区类型 → 按钮集；摆放纯函数。
- `lib/features/canvas/widgets/selection_toolbar.dart`（新建）：浮层 widget、显隐计时、按钮渲染与派发。
- `lib/features/canvas/util/node_menu_model.dart`（W13 归本片）：只在缺判据时追加（如 `selectionKindOf`）；不改 W12 已有函数的语义。
- `lib/features/canvas/widgets/canvas_view.dart`（canvas-view-split 后的骨架；W13 归本片）：在舞台浮层里挂 `SelectionToolbar(canvasId:)`。若 W0 拆分后舞台浮层在 `stage_overlays.dart` 里，挂载点改在那里，并在回报说明（stage_overlays.dart W13 无人占用）。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（menu-split 新建；W13 归本片）：`CanvasMenuController` 加 `openForSelection(Offset anchor)`。
- `lib/core/models/app_preferences.dart`（W13 归本片）：新字段 `selectionToolbarEnabled`。
- `lib/services/file_preferences_service.dart`（W13 归本片）：核对是否需改（现状走 `toMap/fromMap`，多半不用改）；不改就不动。
- `lib/features/settings/providers/selection_toolbar_pref_controller.dart`（新建，**不在归属表**，新文件无冲突）：仿 `shell_keep_last_canvas_controller.dart`。
- `lib/features/settings/widgets/canvas_appearance_section.dart`：加开关行。
- 测试：`test/features/canvas/util/selection_toolbar_model_test.dart`（新建）、`test/features/canvas/widgets/selection_toolbar_test.dart`（新建）、`test/core/models/app_preferences_test.dart`（追加）、`test/features/settings/canvas_appearance_section_test.dart`（追加）。

## 不许碰的文件
- W13 其他切片：`left_rail/outline_panel.dart`、`util/outline_model.dart`（outline-drag-reorder）；`storyboard/*`、`script_*`、`left_rail/script_panel.dart`、`canvas_shot_notes_actions.dart`（script-import-characters → script-panel-repair-actions）；`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`util/canvas_tool_actions.dart`、`providers/canvas_nodes_controller.dart`、`providers/recent_presets_provider.dart`（create-menu-pick-recent）；`sequence/*`、`left_rail/left_rail_actions.dart`（sequence-locate-regenerate）。
- `canvas_menu/multi_menu_entries.dart`、`node_menu_entries.dart`（只调用其公开函数）、`create_node_menu.dart`（barrel）、`canvas_node.dart`、`generate_gate.dart`、`canvas_prompt_bar.dart`。
- ARB、`lib/l10n/generated/`、`docs/CLAUDE.md`。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- outline-drag-reorder：`lib/features/canvas/providers/canvas_edges_controller.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`test/features/canvas/util/outline_drop_plan_test.dart`、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`
- script-import-characters：`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
- script-panel-repair-actions：`lib/core/interfaces/script_repository.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/storage/repositories/postgres_script_repository.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/storage/postgres_script_repository_test.dart`
- create-menu-pick-recent：`lib/core/di/recent_job_presets.dart`、`lib/core/interfaces/recent_job_preset_source.dart`、`lib/features/canvas/models/recent_preset.dart`、`lib/features/canvas/providers/recent_presets_provider.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/recent_presets.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/storage/repositories/postgres_recent_job_preset_source.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/providers/recent_presets_provider_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/recent_presets_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`
- sequence-locate-regenerate：`lib/features/canvas/widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/util/sequence_shot_actions.dart`、`lib/features/sequence/widgets/sequence_screen.dart`、`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`、`test/features/sequence/util/sequence_shot_actions_test.dart`、`test/features/sequence/widgets/sequence_context_menu_test.dart`

## 具体改动
selection_toolbar_model.dart：
```dart
enum SelectionToolbarKind { none, singleConfig, singleResult, multi }
enum SelectionToolbarAction { addToLane, duplicate, saveAsCharacter, asNextShotFirstFrame, generate, align, wrapInLane, more }
@immutable class SelectionToolbarButton { final SelectionToolbarAction action; final bool enabled; final bool primary; }
@immutable class SelectionToolbarSpec { final SelectionToolbarKind kind; final int selectedCount; final BatchCostSummary? cost; final List<SelectionToolbarButton> buttons; }
SelectionToolbarSpec buildSelectionToolbarSpec({required List<CanvasNode> targets, required List<StyleLane> lanes, required bool hasProject, required bool canUseAsNextShotFirstFrame, required double? Function(CanvasNode) costOf});
@immutable class ToolbarPlacement { final Offset topLeft; final bool below; }
ToolbarPlacement? placeSelectionToolbar({required Rect selectionViewport, required Size toolbar, required Size viewport, double gap = InkSpacing.sm, double topInset = InkToolbarSize.stageTopInset, double sideMargin = InkSpacing.md});
```
- kind：0 张 none；1 张 role == result ⇒ singleResult；1 张其余 ⇒ singleConfig；≥2 ⇒ multi（用 `nodeMenuKindOf`）。
- singleConfig：addToLane（enabled = lanes 非空）、duplicate（`duplicateSources(targets).isNotEmpty`）、more。**不出 generate**（Q3-B）。
- singleResult：saveAsCharacter（`hasProject && characterSource(targets) != null`）、asNextShotFirstFrame（enabled 由调用方按 tc-next-shot-first-frame 的判据算好传进来）、more。
- multi：cost = `summarizeBatchCost(batchGenerableNodes(targets), costOf)`；generate 仅在 `generableCount > 0` 时出（primary）；align（enabled = `canAlongAxisAlign || canAlignCrossAxis`）、wrapInLane（≥2 恒可点）、more。
- 摆放：`selectionViewport` 与视口无交集 ⇒ null；默认 top = rect.top − gap − h；若 < topInset ⇒ below = true、top = rect.bottom + gap；left = rect.center.dx − w/2，夹在 [sideMargin, viewport.width − sideMargin − w]。
selection_toolbar.dart：
```dart
class SelectionToolbar extends ConsumerStatefulWidget { const SelectionToolbar({super.key, required this.canvasId}); static const Key toolbarKey = ValueKey<String>('canvas.selectionToolbar'); static Key buttonKey(SelectionToolbarAction a); }
```
- 选区矩形：multi-select-core 的 `selectionBounds`（`util/selection_geometry.dart`，签名以合入后为准）在舞台坐标里取包围盒，经 `canvasTransformControllerProvider(canvasId)` 的矩阵换到视口坐标；单张用 `nodeStageRect`（viewport_focus.dart 第 21 行，现有）。折叠道里的卡不参与包围盒；全折叠 ⇒ 不出。
- 「忙」信号（任一为真 ⇒ 立刻隐藏，并在全部转假后起 150ms 计时再淡入，淡入时长 `InkMotion.fast`）：`nodeDragDeltaProvider != null`（node_drag_delta.dart 第 12 行；group-drag 后形状以合入后为准）、`canvasPanActiveProvider(canvasId)`（canvas_tool_mode.dart 第 72 行）、相机矩阵变化（监听 transform controller，每次变化重置计时）、`linkModeControllerProvider(canvasId) != null`、`canvasWireDragProvider(canvasId) != null`、框选进行中（marquee-select 提供，名字以合入后为准）、`canvasMenuRequestProvider(canvasId) != null`、偏好关。
- 整条包 `ExcludeFocus`（不进 Tab 序）；按钮用 theme 层已有按钮组件 + `InkIcon`，tooltip 带键位（`canvasShortcutLabel`）。
- 派发：addToLane ⇒ 用 `CanvasMenuPopover`（menu-split 新建）贴在按钮下方开 `buildLaneSubmenuGroups`，选中走 `moveNodesToLane`；duplicate ⇒ `duplicateNodes`；saveAsCharacter ⇒ 与节点菜单同一条（`saveNodeAsCharacter`，canvas_tool_actions.dart 约第 498 行）；asNextShotFirstFrame ⇒ tc-next-shot-first-frame 的节点菜单动作；generate ⇒ batch-run-dialog 入口（与多选 Ctrl ↵ / 多选菜单同一个函数）；align ⇒ `CanvasMenuPopover` 开 multi_menu_entries 的对齐 + 分布两块（与右键「对齐 ›」「分布 ›」同一份分组）；wrapInLane ⇒ wrap-in-lane 的 Ctrl G 动作；more ⇒ `openForSelection(按钮下沿中点的视口坐标)`。
canvas_menu_host.dart：`void openForSelection(Offset anchor)`：取当前选中集里任一 id（按节点表顺序第一张）调 `openNode(anchor, id)`；选中为空不动。单选出节点菜单、多选出多选菜单（W12 的 kind 分流自然生效）。
app_preferences.dart：字段 `final bool selectionToolbarEnabled;`（默认 true）；copyWith 参数；`toMap` 键 `'selection_toolbar_enabled'`；`fromMap` 非 bool ⇒ true；`==` / hashCode 纳入。
selection_toolbar_pref_controller.dart：`class SelectionToolbarPrefController extends Notifier<bool>`（build 读 `preferencesServiceProvider.current.selectionToolbarEnabled`，`setEnabled(bool)` 即时改态 + fire-and-forget `update(copyWith)`）；`final selectionToolbarPrefControllerProvider`。
canvas_appearance_section.dart：在两组色板之后加一行「标签 + Switch」，样式照 `startup_section.dart` 约第 37–47 行那一行。

## 行为规则与边界情况
- R1：选中为空 ⇒ 不出；偏好关 ⇒ 永远不出（含有选中时）。
- R2：单选配置节点不出「生成」按钮（Q3-B）；单选文本 / 镜头 / 便签同单选配置。
- R3：多选「生成 N 个」只数可生成且未停用的；N = 0 ⇒ 按钮不出（不是置灰），计数 chip 仍在。
- R4：计数 chip 写总选中数「4 个」，花费只算可生成那部分；有算不出价的追加「另 N 个价格未知」；一个已知价都没有 ⇒ 不写「约 $…」。
- R5：任一忙信号为真 ⇒ 立刻隐藏（不淡出等待）；全部转假后 150ms 再淡入；150ms 内又忙 ⇒ 计时作废。
- R6：滚轮缩放 / 拖画布期间不出，停手 150ms 后在新位置出现。
- R7：顶部空间不足（工具条顶 < `InkToolbarSize.stageTopInset`）⇒ 翻到选区下方，同样隔 8。
- R8：左右夹在视口内留 16；选区与视口无交集 ⇒ 不出。
- R9：工具条按钮不可获得键盘焦点；点击后焦点回画布（与菜单选中后 `reclaimFocus` 同做法）。
- R10：⋯ 打开的菜单与在选区里右键打开的菜单是同一个（同 Key：单选 `CanvasMenuKeys.nodeMenu`，多选 `CanvasMenuKeys.multiMenu`）。
- R11：撤销：各按钮只调用已有动作函数，撤销步数与右键同一入口一致；工具条自身无状态写库。
- R12：选中的卡被删（含撤销删除）⇒ 下一帧按新选中重算，选中空 ⇒ 消失。
- R13：偏好写盘失败不回滚开关（与 ShellKeepLastCanvasController 同口径，fire-and-forget）。
- R14：mac / Windows：键位提示走 `canvasShortcutLabel(isMac:)`；无其他平台差异（全部是画布内控件，不涉及系统菜单）。

## 新文案键
（W12 的 canvasMultiCostApprox / canvasMultiCostUnknown / canvasMultiMenuGenerate / canvasMultiMenuAlign / canvasMultiMenuWrapInLane 与节点菜单现有 canvasNodeMenuAddToLane / canvasNodeMenuDuplicate / canvasNodeMenuSaveAsCharacter 直接复用；「当下一镜的首帧」复用 tc-next-shot-first-frame 的键。）
| key | en | zh |
|---|---|---|
| selectionToolbarCount | `{count, plural, =1{1 selected} other{{count} selected}}` | `{count} 个` |
| selectionToolbarMore | More actions | 更多操作 |
| settingsSelectionToolbarTitle | Show floating toolbar on selection | 选中时显示浮动工具条 |

## 测试
先写、先红。
- `test/features/canvas/util/selection_toolbar_model_test.dart`（新建）：
  - `'single config selection has no generate button'`（Q3-B）：image 配置单选 ⇒ 按钮为 addToLane、duplicate、more。
  - `'single result selection offers save as character and next shot first frame'`。
  - `'multi selection generate counts only enabled generable nodes'`：3 配置（1 停用）+ 1 产物 ⇒ generate 存在，cost.generableCount = 2，selectedCount = 4。
  - `'multi selection without generable nodes hides generate'`。
  - `'add to lane is disabled when the canvas has no lanes'`。
  - `'placement sits above the selection with an 8px gap'`。
  - `'placement flips below when it would cross the top toolbar'`。
  - `'placement is clamped horizontally and null when offscreen'`。
- `test/features/canvas/widgets/selection_toolbar_test.dart`（新建；ProviderScope 覆写 InMemory 仓储与选中集）：
  - `'toolbar fades in 150ms after selection settles'`：pump(149ms) 找不到可见条，pump(1ms+fast) 找到。
  - `'toolbar hides while a card is being dragged'`：设 `nodeDragDeltaProvider` 非空 ⇒ 不在。
  - `'toolbar hides while link mode is active'`。
  - `'more button opens the multi menu for a multi selection'`：点 ⋯ ⇒ 找到 `CanvasMenuKeys.multiMenu`。
  - `'toolbar buttons are excluded from focus traversal'`：Tab 遍历不落到任何工具条按钮。
  - `'toolbar is not shown when the preference is off'`。
- `test/core/models/app_preferences_test.dart`（追加）：`'selectionToolbarEnabled defaults to true and round-trips'`、`'selectionToolbarEnabled falls back to true on bad value'`。
- `test/features/settings/canvas_appearance_section_test.dart`（追加）：`'selection toolbar switch persists through preferences service'`。

## 变异点
- M1：在 singleConfig 分支加回 generate → `'single config selection has no generate button'` 变红。
- M2：generate 计数去掉停用过滤（不经 `batchGenerableNodes`）→ `'multi selection generate counts only enabled generable nodes'` 变红。
- M3：N = 0 时仍出 generate（置灰）→ `'multi selection without generable nodes hides generate'` 变红。
- M4：`placeSelectionToolbar` 去掉翻转分支 → `'placement flips below…'` 变红。
- M5：把 150ms 计时改成 0 → `'toolbar fades in 150ms after selection settles'` 变红。
- M6：忙信号里去掉 `nodeDragDeltaProvider` → `'toolbar hides while a card is being dragged'` 变红。
- M7：去掉 `ExcludeFocus` → `'toolbar buttons are excluded from focus traversal'` 变红。
- M8：`fromMap` 缺省改成 false → `'selectionToolbarEnabled defaults to true and round-trips'` 变红。
- M9：`openForSelection` 改为固定开节点菜单（绕过 kind 分流）→ `'more button opens the multi menu…'` 变红。

## 验收
- `flutter analyze lib test`。
- `flutter test --exclude-tags golden test/features/canvas/util/selection_toolbar_model_test.dart test/features/canvas/widgets/selection_toolbar_test.dart test/core/models/app_preferences_test.dart test/features/settings/canvas_appearance_section_test.dart`，再跑 `test/features/canvas/` 与 `test/features/settings/` 全目录。
- 变异 M1–M9 逐条。
- 截图：`CanvasScreen` + ProviderScope 覆写 InMemory 节点 / 泳道仓储（一道两张视频配置、一张图像产物、一张停用配置；node-cost 覆写为两张有价一张无价），截：①单选配置（精简条）；②单选产物；③多选 4 张（「4 个 · 约 $… · 另 1 个价格未知 | 生成 2 个 | 对齐 | 包成泳道 | ⋯」）；④选区贴近顶部时翻到下方；⑤⋯ 打开的多选菜单。另截设置 › 节点布局的新开关。

## 风险与不确定
- marquee-select 的「框选进行中」provider 名、group-drag 后 `nodeDragDeltaProvider` 的形状、`selectionBounds` 签名、`CanvasMenuPopover` 的入参，都以合入后为准。
- tc-next-shot-first-frame 的可用性判据 / 动作函数名以合入后为准；若它只做在节点菜单内部、没有公开判据，本片只能在 widget 层调用其分组构建函数取 enabled，回报说明。
- 翻到下方时可能压到底部提示词条（画板未定），本片不避让。
- 选中卡跨多条折叠 / 展开道时包围盒跨度很大，工具条可能离卡较远；按画板「选区上方居中」照做。
- 挂载点可能需要落在 `stage_overlays.dart` 而不是 `canvas_view.dart`（看 W0 拆分结果），两者 W13 都无他人占用。
- `selection_toolbar_pref_controller.dart` 是归属表外的新文件。
