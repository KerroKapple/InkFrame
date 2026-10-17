# outline-drag-reorder · 大纲拖行改叙事顺序（只在本组内放，越组回弹）
- 波次：W13 / lane：B / 基底：origin/main（W0–W12 已合入，含 narrative-splice、outline-rename-menu）
- 依赖切片：narrative-splice（W1，`util/narrative_splice.dart`：`SplicePlan`、`movePlan({nodeId, afterId, edges})`、`siblingReorderPlan({parentId, orderedChildIds, edges})`、`insertPlan`、`bridgePlan`、`invertSplice`、`SpliceUndoToken`；`CanvasEdgesController.applySplice(SplicePlan) → SpliceApplied{removed, added, token}` 一个事务写完、失败回滚内存并 rethrow，**不自己进撤销栈**）、outline-rename-menu（W9，同一个 outline_panel.dart 已加双击改名 / 右键菜单）、undo-stack（W0：`CanvasCommand` / `canvasHistoryControllerProvider(canvasId).notifier.record`）、batch-run-dialog（W11，`_GroupHeader` 已加 `onRun`）
- 阻塞决定：O1 → A（不能跨泳道组；换道走画布拖卡）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/outline-drag-reorder`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片不碰。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片只改边，不改节点。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：边的增删改**只能**经 narrative-splice 的 `applySplice(SplicePlan)` 一次事务写完；不在 widget 里逐条调 `addEdge / removeEdge`，不改 `canvas_edges_controller.dart`。

## 目标
左栏「大纲」里，链上的镜头行可以按住拖动、在同一组（同一泳道 / 「未分泳道」）里换位置，松手即改叙事顺序（序列、导出顺序跟着变）。
拖到别的组上显示禁止并在松手后滑回原处；「未入链」行、产物子行、「生成中…」子行拿不起来。整次拖动一步撤销。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` 小节「大纲行：改名 · 右键 · 拖动排序」（b2_gaps_panels.js 约第 120–155 行）：
  - 原文：「拖行改叙事序（图中 02 在改名、03 正拖到 01 后）：只能在本组里放，越组禁止并回弹（O1）；未入链、产物、生成中的行不能拖」。
  - 原文：「落下改的是叙事边：摘出、前后接上、插进新位置——与「拖到线上插入」同一套边操作，一个事务；只有同一分叉下兄弟换序才改 sortOrder」。
  - 视觉：落点指示 = 行间 2px accent 横线（左右各留 12），左端 6×6 圆点（accent，圆角 3）；被拖的原行留在原位，变虚线框（1px dashed control、圆角 3、左右缩 6）+ 透明度 0.45；跟手的幽灵 = surface5 底、1px overlayBorder、圆角 4、`InkShadow.overlay`，高 34、宽 = 面板宽 − 44，内含镜号（等宽 10 号 fg5）+ 34×19 缩略 + 名称（fg1）。
- O1 建议 A「不能，只在组内排；换道走画布拖卡」。
- 设计缺口：①筛选框有内容时能不能拖（画板没画）——本片定为**不能拖**（隐藏行的位置无法表达）；②列表比面板长时拖到边缘要不要自动滚动——不做；③拖动中按 Esc——不处理（Draggable 不收键盘），松手到组外即取消。

## 允许改的文件
- `lib/features/canvas/util/outline_model.dart`：新增可拖判据与落点 → 拼接计划的纯函数（见具体改动）。现有 `narrativeChainMembers`（约第 34 行）、`narrativeSequenceIndex`（约第 53 行）、`buildCanvasOutline`（约第 149 行）不改语义。
- `lib/features/canvas/widgets/left_rail/outline_panel.dart`：`_ShotBlock`（约第 224 行）里的 `_ShotRow` 包一层可拖；ListView（约第 117 行）按组插入落点区；新增测试锚点 `OutlinePanel.dropSlotKey(String groupKey, int index)`、`OutlinePanel.dragGhostKey`。
- `lib/theme/tokens.dart`：只追加 `InkOutlineDrag { ghostHeight = 34; indicatorHeight = 2; indicatorDot = 6; sourceOpacity = 0.45; }`（若已有可复用常量就不加）。
- `lib/features/canvas/models/commands/outline_reorder_command.dart`（新）：`OutlineReorderCommand extends CanvasCommand`——持 `SplicePlan`（重做用）与 `SpliceUndoToken`（撤销用）；revert = `invertSplice(token, 当前边)` → `applySplice`（null ⇒ gone）；apply = 再 `applySplice(plan)` 并换新 token。独立文件（undo-stack 约定：`CanvasCommand` 不 sealed、不用 part，`label(l)` 是方法，canvasId 从 `CanvasCommandEnv` 取）。
- （`lib/features/canvas/models/canvas_command.dart` 不改：命令独立成文件，不登记（主 Agent 跨批核对补充）。）
- （`canvas_edges_controller.dart` 不改：`applySplice` 已是「删边集 + 加边集 + sortOrder」一事务入口。）
- 测试：`test/features/canvas/util/outline_drop_plan_test.dart`（新建）、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`（新建）、`test/features/canvas/models/outline_reorder_command_test.dart`（新建）。

## 不许碰的文件
- W13 其他片：`util/node_menu_model.dart`、`widgets/canvas_view.dart`、`canvas_menu/canvas_menu_host.dart`、`widgets/selection_toolbar.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`（selection-toolbar）；`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`util/canvas_tool_actions.dart`、`providers/canvas_nodes_controller.dart`（create-menu-pick-recent）；`widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/**`（sequence-locate-regenerate）；`lib/features/storyboard/**`、`util/canvas_shot_notes_actions.dart`、`widgets/left_rail/script_panel.dart`（script-import-characters → script-panel-repair-actions）。
- `util/narrative_splice.dart`（narrative-splice 建，只调用不改）、`providers/canvas_edges_controller.dart`（只调 `applySplice`）、`util/narrative_order.dart`、`canvas_menu/*`、`create_node_menu.dart`（barrel）、`models/canvas_node.dart`、`models/canvas_edge.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- selection-toolbar：`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/util/selection_toolbar_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/selection_toolbar.dart`、`lib/features/canvas/widgets/stage/stage_overlays.dart`（可能）、`lib/features/settings/providers/selection_toolbar_pref_controller.dart`、`lib/features/settings/widgets/canvas_appearance_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/selection_toolbar_model_test.dart`、`test/features/canvas/widgets/selection_toolbar_test.dart`、`test/features/settings/canvas_appearance_section_test.dart`
- script-import-characters：`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
- script-panel-repair-actions：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`
- create-menu-pick-recent：`lib/core/di/recent_job_presets.dart`、`lib/core/interfaces/recent_job_preset_source.dart`、`lib/features/canvas/models/recent_preset.dart`、`lib/features/canvas/providers/recent_presets_provider.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/recent_presets.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/storage/repositories/postgres_recent_job_preset_source.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/providers/recent_presets_provider_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/recent_presets_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`
- sequence-locate-regenerate：`lib/features/canvas/widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/util/sequence_shot_actions.dart`、`lib/features/sequence/widgets/sequence_screen.dart`、`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`、`test/features/sequence/util/sequence_shot_actions_test.dart`、`test/features/sequence/widgets/sequence_context_menu_test.dart`

## 具体改动
```dart
// outline_model.dart —— 纯函数，零 widget
/// 这一行能不能拿起来：链上配置节点、所在组是 lane / unassigned、且 query 为空。
bool canDragOutlineShot(OutlineGroup group, OutlineShot shot, {required String query});

/// 组身份：lane 组用 laneId，未分泳道用固定串；越组判据只比它。
String outlineGroupKey(OutlineGroup group);

/// 落点合法：拖的行与落点同组、落点不是它自己上下两个缝（原位）。
bool canDropWithinGroup({required OutlineGroup group, required String draggedId, required int slot});

/// 落点（组内第 slot 个缝，0..shots.length）→ 拼接计划。
sealed class OutlineDropPlan {}
final class OutlineDropNoop extends OutlineDropPlan {}
final class OutlineSiblingReorder extends OutlineDropPlan { // 同一分叉下兄弟换序：只改 sortOrder
  final String parentId; final List<String> orderedChildIds; final SplicePlan plan; } // plan = siblingReorderPlan(parentId:, orderedChildIds:, edges:)
final class OutlineRelink extends OutlineDropPlan {         // 摘出 + 前后接上 + 插进新位置
  final SplicePlan plan; }                                  // plan = movePlan(nodeId: X, afterId: A, edges:)；组顶（A 为空）见下
OutlineDropPlan outlineDropPlan({required OutlineGroup group, required String draggedId,
    required int slot, required List<CanvasNode> nodes, required List<CanvasEdge> edges});
```
落点换算（`outlineDropPlan`，设 A = 缝上方那行，B = 缝下方那行，X = 被拖行）：
1. 原位（A == X 或 B == X）⇒ Noop。
2. 兄弟换序：X 与 B 的唯一叙事入边来自同一父 P ⇒ `OutlineSiblingReorder`（`siblingReorderPlan(parentId: P, orderedChildIds: 新顺序, edges:)`，P 的叙事出边重排 sortOrder 0..n）；或 X 与 A 同父且 A 没有叙事出边 ⇒ 同上，X 排在 A 之后。
3. 其余 ⇒ `OutlineRelink`：A 非空 ⇒ `movePlan(nodeId: X, afterId: A, edges:)`（narrative-splice 定义的「摘出 + 接上 + 插到 A 之后」一份计划；`null` ⇒ 视为不合法、回弹）。A 为空（组顶）⇒ 若 B 有叙事入边 P→B，取 `movePlan(nodeId: X, afterId: P, …)`；B 是链头 ⇒ 本片自拼 `SplicePlan`：先 `bridgePlan(deletedIds: {X}, edges:)` 的边改动，再加 X→B（sortOrder 0），合并成一份 SplicePlan。A 没有出边时的 sortOrder 规则由 movePlan 内部决定（与 `nextNarrativeSortOrder` 同口径，见 narrative-splice 派工单）。
4. 不改 `laneId`、不改节点位置（O1=A：一次拖动只改一件事）；非叙事边（data / reference / 首尾帧）一律不动。

outline_panel.dart：
- 行用 `Draggable<String>(axis: Axis.vertical, affinity: Axis.vertical, data: nodeId)`——过了拖动阈值才起拖，单击 / 双击改名 / 右键菜单（W9）照旧。
- 每组 shots 之间（含首尾）放落点区 `DragTarget<String>`，`onWillAcceptWithDetails` 走 `canDropWithinGroup`；组外悬停 ⇒ 光标 `SystemMouseCursors.forbidden`、不画指示线。
- 松手合法 ⇒ `outlineDropPlan` → `ref.read(canvasEdgesControllerProvider(canvasId).notifier).applySplice(plan)` → 成功后 `record(OutlineReorderCommand(plan, applied.token))` 进撤销栈；写入期间 `_applying = true`，所有行不可拖。
- 松手不合法 / 拖出列表 ⇒ 幽灵在 `InkMotion.normal` 内滑回原行（OverlayEntry + AnimationController；`MediaQuery.disableAnimations` 时直接消失）。

## 行为规则与边界情况
- R1 只有 lane / unassigned 组里的镜头行可拖；unchained 组的行、产物子行（`_ArtifactRow`）、生成中子行（`_GeneratingRow`）没有 Draggable。
- R2 筛选框非空时所有行不可拖（设计缺口①的决定）。
- R3 拖到别的组（含未入链组）：不接受、松手回弹、边集不变、不发任何写。
- R4 原位松手：Noop，不写库、不进撤销栈。
- R5 兄弟换序只改 P 的叙事出边 sortOrder，不删不加边。
- R6 Relink 在一个事务里完成；写失败 ⇒ 边控制器回滚到写前状态，`showCanvasSnack(context, context.l10n.outlineReorderFailed)`（canvas_snackbars.dart，只调用），大纲回到原顺序。
- R7 一次拖动 = 撤销栈一步：`applySplice` 不进栈，由本片在成功后 record 一条 `OutlineReorderCommand`；撤销后顺序与边集完全复原（含 sortOrder，经 `invertSplice`）。
- R8 写入进行中再拖：不可拖（`_applying`）。节点在拖动中被删 / 画布换了 ⇒ 松手时 `draggedId` 不在当前节点集 ⇒ 视为不合法、回弹。
- R9 拖动不改选中集、不移动相机；松手后行跟着新顺序重排，镜号按序列口径（`sequenceShotNumbers`）重算。
- R10 无平台差异：鼠标拖动与光标在 macOS / Windows 一致；不涉及修饰键。

## 新文案键
| key | en | zh |
|---|---|---|
| outlineReorderFailed | Couldn't reorder shots. Nothing was changed. | 没能调整镜头顺序，什么都没改。 |
| canvasCommandReorderShots | Reorder shots | 调整镜头顺序 |
（后者是 `OutlineReorderCommand.label`，命名照 W9 outline-rename-menu 的 `canvasCommandRenameNode`。）

## 测试
- `test/features/canvas/util/outline_drop_plan_test.dart`：
  - `only chained rows in lane or unassigned groups are draggable` —— unchained 组行 false；query 非空 false。
  - `dropping onto own slots is a noop` —— slot 为 X 上下两缝 ⇒ OutlineDropNoop。
  - `cross-group drop is rejected` —— canDropWithinGroup 对另一组 false。
  - `moving C after A in A→B→C relinks to A→C→B` —— 断言 `OutlineRelink.plan` 的 `removeEdgeIds` / `addEdges`（`SplicePlan` 字段）：删 A→B、B→C，加 A→C、C→B。
  - `moving to top of group inserts on the incoming edge of the first row`。
  - `moving to top of a chain head builds bridge plus head edge` —— B 是链头时自拼计划：摘出 X 的边改动 + 加 X→B。
  - `siblings under the same fork only change sortOrder` —— P→X(0)、P→Y(1)，把 Y 拖到 X 前 ⇒ OutlineSiblingReorder，`plan.sortOrders` 只含两条边、`removeEdgeIds` / `addEdges` 为空。
- `test/features/canvas/models/outline_reorder_command_test.dart`（新）：`undo restores edges and sort orders; redo reapplies`。
  - `relink never touches non-narrative edges or laneId`。
- `test/features/canvas/widgets/left_rail/outline_drag_test.dart`（ProviderScope 覆写节点 / 边 / 泳道控制器为 fake_canvas 数据，边控制器用 fake 记录调用）：
  - `drag within group calls the splice write once and records one undo step`（fake 边控制器记录 `applySplice` 调用；历史栈深 +1）。
  - `drag into another group shows forbidden and writes nothing`。
  - `artifact and generating sub-rows cannot be dragged`。
  - `filter text disables dragging`。
  - `write failure shows the failure toast and restores order`。

## 变异点
- M1 `canDragOutlineShot` 去掉 `group.kind != unchained` 判据 → `only chained rows ... are draggable` 红。
- M2 `canDropWithinGroup` 不比 `outlineGroupKey` → `cross-group drop is rejected` 与 `drag into another group ... writes nothing` 红。
- M3 原位判断删掉（A==X / B==X）→ `dropping onto own slots is a noop` 红。
- M4 兄弟分支走 Relink 而不是 SiblingReorder → `siblings under the same fork only change sortOrder` 红。
- M5 Relink 改为直接 `insertPlan`（不先摘出 X）→ `moving C after A in A→B→C relinks to A→C→B` 红。
- M6 链头分支漏掉加 X→B → `moving to top of a chain head builds bridge plus head edge` 红。
- M9 成功后不 record 命令 → `drag within group … records one undo step` 红；命令 revert 不走 `invertSplice` → `undo restores edges and sort orders` 红。
- M7 去掉 query 判据 → `filter text disables dragging` 红。
- M8 失败分支不 toast → `write failure shows the failure toast and restores order` 红。

## 验收
- `flutter analyze lib test`。
- `flutter test test/features/canvas/util test/features/canvas/widgets/left_rail test/features/canvas/providers --exclude-tags golden`。
- 变异 M1–M9。
- 截图：`OutlinePanel(canvasId)`，覆写一个泳道组 3 镜 + 未分泳道 1 镜 + 未入链 1 镜；截①静止、②拖动中（幽灵 + 指示线 + 原行虚线）、③拖到别组（禁止光标、无指示线）。

## 风险与不确定
1. narrative-splice 的 W1 派工单已定：纯函数 `movePlan` / `siblingReorderPlan` / `bridgePlan` / `insertPlan` 产出 `SplicePlan`，写入口只有 `CanvasEdgesController.applySplice`（W1 另有便捷入口 `spliceInsert(edgeId, newNodeId)`，只管插入，本片用不上）。合入后名字若有出入以代码为准；`applySplice` 不进撤销栈，所以本片要自建 `OutlineReorderCommand`（按 undo-stack 约定独立成文件，不碰 canvas_command.dart）。
2. `movePlan` 对「X 有多个后继（分叉点）」怎么接——以 narrative-splice 的语义为准（`bridgePlan` 遇分叉 / 汇合返回「不接」），本片不另定。
3. 「借出产物」的配置与镜头同号（outline_model 头注释）：只拖其中一行会把两者拆开，序列里可能变成两镜；画板未讨论，照做并在回报里提示。
4. 组内行序是 DFS 链序（`narrativeSequenceIndex`），组可能不连续（链跨泳道交错）；落在组内某缝的含义按 A / B 两邻居定义，跨组的链段不受影响。
5. outline-rename-menu（W9）若把 `_ShotRow` 包了 GestureDetector（双击 / 右键），Draggable 要包在它外层，避免手势竞争。
