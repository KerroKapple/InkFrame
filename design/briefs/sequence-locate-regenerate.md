# sequence-locate-regenerate · 序列里右键「在画布中定位」/「在画布中定位并重生成」
- 波次：W13 / lane：E / 基底：origin/main（W0–W12 已合入）
- 依赖切片：menu-split（W0：`CanvasMenuPopover<T>({required Offset? anchor, required groups, required onSelected, required onDismiss, required emptyText, double width, Key? panelKey, required Widget child})`、`InkMenuEntry`）、help-actions（W3：`InkMenuEntry.disabledReason`，置灰原因走它）、current-take（W1：`currentResultFor`，序列的 artifactNodeId 已按当前 take 取）、node-cost（W2：`estimateNodeCost({required node, required capabilities, lastUsedProviderId, pending}) → NodeCostEstimate?`、`formatNodeCost(e)`（未知 ⇒ '—'）、键 `costApprox`）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W12 已合入）起新分支 `feat/sequence-locate-regenerate`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行。本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法。本片不写库。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. `canvas_tool_actions.dart` 在 W13 归 create-menu-pick-recent：本片只**调用** `generateNode`，一行都不改。
10. `focusNodeAcrossCanvas` 是 W15 character-usage-links 要复用的公共函数：签名按下文一字不差，注释写全。

## 目标
序列标签里，叙事链行（左栏）和 V1 轨片段都能右键，出两项：「在画布中定位」——切到画布标签、单选这一镜的生成节点并居中；
「在画布中定位并重生成  约 $0.75」——定位后立刻按 Ctrl ↵ 同一道闸提交生成。这一镜只有镜头节点（还没有配置节点）时第二项置灰，悬停说原因。

## 设计依据
- `b2/project/GapsPanels.dc.html` ›「序列：回画布定位并重生成」（抽文：SCRATCH/boards/GapsPanels.txt 第 47–72 行）：
  - 「右键 002（叙事链行 / V1 轨片段都行）」；菜单：「在画布中定位」「在画布中定位并重生成　约 $0.75」「从这一镜播放」；
  - 「定位 = 切到画布、单选这一镜的生成节点、居中（『在序列中定位』的反向）」；
  - 「生成节点 = 当前 take 的来源配置；本身是配置就用它；只有镜头节点时『并重生成』灰：『还没有配置节点』」；
  - 「并重生成 = 定位后走 submitWithPending，与 Ctrl ↵ 同一道闸；不过只定位，检查器写原因」；
  - 「单个不确认（≥2 个才确认，见 TakesCost）；新 take 按 TakesCost Q2 成为当前，播放头不动」。
- 「从这一镜播放」本片不做：要让监视器开始播放需要 `sequence_monitor.dart` 暴露播放入口（`_play` 是私有态），不在本片归属；slices notes 也只列两项。见风险。
- 设计缺口：右键时播放头 / 选中行要不要跟着动没画。本片定为：右键不动播放头、不改选中行（「播放头不动」的同一口径）。
- 设计缺口：价格算不出时的写法没画。按 node-cost 的统一口径写「约 —」。

## 允许改的文件
- `lib/features/sequence/util/sequence_shot_actions.dart`（新建）：纯判据 + 两个动作。
- `lib/features/sequence/widgets/sequence_screen.dart`：`_ChainRow` 与 `_Clip` 加 `onSecondaryTapUp`，开 `CanvasMenuPopover`；菜单行构建放一个私有 `_ShotMenu` 小部件或私有函数。
- `lib/features/canvas/widgets/left_rail/left_rail_actions.dart`：新增 `focusNodeAcrossCanvas`（现有 `focusNodeOnCanvas` 不改）。
- 测试：`test/features/sequence/util/sequence_shot_actions_test.dart`（新建）、`test/features/sequence/widgets/sequence_context_menu_test.dart`（新建）、
  `test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`（新建）。

## 不许碰的文件
- W13 selection-toolbar：`util/node_menu_model.dart`、`widgets/canvas_view.dart`（及 W0 拆出的 stage_* 文件）、`canvas_menu/canvas_menu_host.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`。
- W13 create-menu-pick-recent：`util/canvas_tool_actions.dart`（只调用）、`providers/canvas_nodes_controller.dart`、`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`。
- W13 outline-drag-reorder：`left_rail/outline_panel.dart`、`util/outline_model.dart`；W13 script-*：`storyboard/**`、`script_panel.dart`、`canvas_shot_notes_actions.dart`。
- `sequence_monitor.dart`、`sequence_playhead.dart`、`view_in_sequence.dart`、`shot_index.dart`、`shell_task_popover.dart`（只参考其跨画布写法）、
  `canvas_focus_request.dart`、`inspector_submit_controller.dart`、`create_node_menu.dart`（barrel）、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- selection-toolbar：`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/util/selection_toolbar_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/selection_toolbar.dart`、`lib/features/canvas/widgets/stage/stage_overlays.dart`（可能）、`lib/features/settings/providers/selection_toolbar_pref_controller.dart`、`lib/features/settings/widgets/canvas_appearance_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/selection_toolbar_model_test.dart`、`test/features/canvas/widgets/selection_toolbar_test.dart`、`test/features/settings/canvas_appearance_section_test.dart`
- outline-drag-reorder：`lib/features/canvas/models/canvas_command.dart`（只追加一行）、`lib/features/canvas/models/commands/outline_reorder_command.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`test/features/canvas/models/outline_reorder_command_test.dart`、`test/features/canvas/util/outline_drop_plan_test.dart`、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`
- script-import-characters：`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
- script-panel-repair-actions：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`
- create-menu-pick-recent：`lib/core/di/recent_job_presets.dart`、`lib/core/interfaces/recent_job_preset_source.dart`、`lib/features/canvas/models/recent_preset.dart`、`lib/features/canvas/providers/recent_presets_provider.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/recent_presets.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/storage/repositories/postgres_recent_job_preset_source.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/providers/recent_presets_provider_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/recent_presets_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`

## 具体改动
现有 API（已核对）：
- `SequenceShot`（storyboard/models/sequence_shot.dart）：`nodeId`（链上贡献这一镜的 shot 或 config 节点）、`artifactNodeId`（贡献产物的 result 节点，可能是借来的后继 config 的产物）、`canvasId`。
- `CanvasFocusRequestController.request({required String canvasId, required String nodeId, bool center = true})`（canvas_focus_request.dart 约第 50 行）。
- `ShellNavigator.goTab(ShellTab t)` / `openCanvas(String id, {ProjectRef? withProject})`（shell_controller.dart 约第 54–56 行）；`ShellState.canvasId` / `.project`。
- 跨画布写法参考 `shell_task_popover.dart` 约第 250–273 行 `_locateAction`：同一画布 `goTab(ShellTab.canvas)`，别的画布 `openCanvas(id, withProject: project)`，然后 `canvasFocusRequestProvider.request(...)`；拿不到 ProjectRef 就不做。
- `void generateNode(WidgetRef ref, {required String nodeId})`（canvas_tool_actions.dart 约第 424 行；在忙直接 return，否则 `submitWithPending()`）。
- `bool isGenerableNode(CanvasNode node)`（node_menu_model.dart 约第 78 行：config + image/video + 提示词非空）——只调用。
- `sequencePlayheadProvider(canvasId)`、`sequenceLensProvider(canvasId)`、`canvasNodesControllerProvider(canvasId)`。
- `estimateNodeCost` / `formatNodeCost`（W2 node-cost，`generation/services/node_cost.dart`）；价格文案 = `l.costApprox(formatNodeCost(e))`（未知时 formatNodeCost 给「—」，即「约 —」）。
- `CanvasMenuPopover`（menu-split 新建，按全局坐标定位的 OverlayPortal，`canvas_menu/canvas_menu_popover.dart`）。

新增签名：
```dart
// canvas/widgets/left_rail/left_rail_actions.dart（追加）
/// 在 [canvasId] 上单选 [nodeId] 并移到视口中心，不管外壳此刻停在哪个标签 / 哪张画布：
///   - 外壳正指着 [canvasId] ⇒ goTab(ShellTab.canvas)；
///   - 否则 ⇒ openCanvas(canvasId, withProject: project ?? 外壳当前项目)；
/// 然后挂起 canvasFocusRequest(center: true)，由画布挂着 / 挂上来后落地（不直接写 autoDispose 的选中）。
/// 返回 false = 要换画布但拿不到 ProjectRef（[project] 与外壳当前项目都为 null），什么都没做。
bool focusNodeAcrossCanvas(WidgetRef ref, {required String canvasId, required String nodeId, ProjectRef? project});

// sequence/util/sequence_shot_actions.dart
/// 这一镜的生成节点：artifactNodeId 对应 result 的 sourceNodeId 指向的 image/video 配置节点；
/// 否则 shot.nodeId 本身是 image/video 配置节点就用它；否则 null（只有镜头节点 / 来源已删）。
CanvasNode? shotGenerationNode(SequenceShot shot, List<CanvasNode> nodes);
/// 「定位」落在哪：生成节点；没有 ⇒ shot.nodeId。
String shotLocateNodeId(SequenceShot shot, List<CanvasNode> nodes);

enum ShotRegenerateOutcome { generated, locatedOnly, unavailable }

void locateShotOnCanvas(WidgetRef ref, {required String canvasId, required SequenceShot shot});
/// 定位；生成节点存在且 isGenerableNode ⇒ generateNode；不过闸 ⇒ 只定位（检查器状态区自己写原因）。
ShotRegenerateOutcome locateAndRegenerateShot(WidgetRef ref, {required String canvasId, required SequenceShot shot});
```
sequence_screen：`_ChainRow` / `_Clip` 构造多收 `ValueChanged<Offset> onSecondaryTap`（全局坐标）；`_Clip` 现在没有手势，外包一层
`GestureDetector(behavior: opaque, onSecondaryTapUp: ...)`，不加 onTap（左键仍由轨道的 seekGlobal 处理）。菜单两项：
`sequenceMenuLocateOnCanvas` 与 `sequenceMenuLocateAndRegenerate`，后者右侧放 `l.costApprox(formatNodeCost(e))`（用 W6 的 `InkMenuEntry.note` 行尾小字；没有 note 字段时放 keyHint 位），置灰时 `disabledReason: l.sequenceMenuNoConfigNode`。
菜单 Key：`SequenceScreen.shotMenuLocateKey` / `shotMenuRegenerateKey`（静态常量，供测试）。

## 行为规则与边界情况
- R1 叙事链行与 V1 片段右键都开同一份菜单，作用于该行 / 片段的那一镜（下标 i）。
- R2 右键不改播放头（index / seekToken 不变），不改链表选中行。
- R3 生成节点：有 artifactNodeId ⇒ 其 result 的 sourceNodeId（即当前 take 的来源配置；借来的产物归后继 config）；无产物且 shot.nodeId 是 image/video 配置 ⇒ 它；镜头节点无产物 ⇒ null。
- R4 生成节点为 null：「并重生成」置灰 + 悬停「还没有配置节点」；「定位」仍可点，落到 shot.nodeId。
- R5 定位 = focusNodeAcrossCanvas：外壳 canvasId 等于序列的 canvasId ⇒ 只 goTab(canvas)，不 openCanvas；请求 center: true。
- R6 并重生成：先定位，再 isGenerableNode ⇒ generateNode（在忙时 generateNode 自己不动 ⇒ 结果等同只定位）。提示词空 ⇒ outcome = locatedOnly，不提交。
- R7 单个不弹确认对话框（≥2 才确认的规则不适用）。
- R8 价格：`l.costApprox(formatNodeCost(e))` ⇒「约 $0.75」/ 算不出「约 —」；`estimateNodeCost` 返回 null 或生成节点为 null ⇒ 不显示价格。
- R9 新 take 成为当前由 current-take / set-current 负责；本片不动播放头、不刷新 lens（lens 跟着节点控制器自己变）。
- R10 序列为空（lens.isEmpty）：没有行 / 片段，不出菜单。
- R11 菜单开着时序列数据变化（节点被删）：执行时按**执行那一刻**的 nodes 重新算生成节点；已不存在 ⇒ 仅定位 shot.nodeId（画布落地时找不到节点则请求被丢弃，现有行为）。
- R12 focusNodeAcrossCanvas 跨画布且无 ProjectRef ⇒ 返回 false、不切标签、不挂请求。
- R13 撤销：本片不写画布；生成产生的新 take 是否进撤销栈与 Ctrl ↵ 一致（不进）。
- R14 无平台差异：右键在 macOS 触控板双指点 / Ctrl+点都会触发 Flutter 的 secondaryTap，与画布右键同一机制。

## 新文案键
| key | en | zh |
|---|---|---|
| sequenceMenuLocateOnCanvas | Locate on canvas | 在画布中定位 |
| sequenceMenuLocateAndRegenerate | Locate on canvas and regenerate | 在画布中定位并重生成 |
| sequenceMenuNoConfigNode | No config node yet | 还没有配置节点 |

价格复用 W2 node-cost 的 `costApprox(amount: String)`，不新建 `sequenceMenuCostApprox`。

## 测试
`test/features/sequence/util/sequence_shot_actions_test.dart`
- `'generation node is source config of current take'`：shot 节点 + 借来的后继 config 产物 → 返回那个 config。
- `'config shot without artifact uses itself'`、`'shot-only without artifact has no generation node'`。
- `'locate falls back to shot node id'`。
- `'regenerate submits when generable'`：覆写 inspectorSubmitControllerProvider 为 fake，断言 submitWithPending 被调一次、outcome == generated。
- `'regenerate with empty prompt only locates'`：outcome == locatedOnly，未提交；canvasFocusRequestProvider 已挂请求。
`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`
- `'same canvas switches tab without reopening'`：外壳 project 为 null、canvasId == c1 → 返回 true，shell.tab == canvas，请求 (c1, n1, center: true)。
- `'other canvas opens it with current project'`：shell.canvasId == c2。
- `'other canvas without project does nothing'`：返回 false，shell 与请求都不变。
`test/features/sequence/widgets/sequence_context_menu_test.dart`（SequenceScreen，覆写 canvasNodesController / canvasEdgesController 为 3 镜）
- `'right click chain row opens menu with cost'`：出现两项与「约 $」文本。
- `'right click clip opens same menu'`。
- `'right click does not move playhead'`：seekToken 不变。
- `'regenerate disabled for shot-only and shows reason'`。
- `'locate switches to canvas tab'`。

## 变异点
- M1 `shotGenerationNode` 去掉 artifactNodeId → sourceNodeId 分支 → `'generation node is source config of current take'` 红。
- M2 去掉 `isGenerableNode` 闸（直接 generateNode）→ `'regenerate with empty prompt only locates'` 红。
- M3 `locateAndRegenerateShot` 不调 generateNode → `'regenerate submits when generable'` 红。
- M4 去掉 focusNodeAcrossCanvas 的同画布分支（一律走「要 ProjectRef 的换画布」路径）→ `'same canvas switches tab without reopening'` 红（无项目时返回 false）。
- M5 去掉「无 ProjectRef 返回 false」→ `'other canvas without project does nothing'` 红。
- M6 右键 handler 里顺手 selectShot → `'right click does not move playhead'` 红。
- M7 `_Clip` 不包 onSecondaryTapUp → `'right click clip opens same menu'` 红。
- M8 置灰判据改成恒可点 → `'regenerate disabled for shot-only and shows reason'` 红。

## 验收
- `flutter analyze lib test`；`flutter test --exclude-tags golden test/features/sequence test/features/canvas/widgets/left_rail`；变异 M1–M8 逐条红。
- 截图场景：`SequenceScreen(canvasId: 'c1', projectId: 'p1', isVisible: true)`，覆写节点 / 边为 3 镜（002 有图像 take、003 只有镜头节点）；
  ① 右键 002 链表行菜单（带「约 $0.04」）；② 右键 003 的 V1 片段（「并重生成」置灰 + 悬停原因）。

## 风险与不确定
- 置灰原因字段已统一为 `InkMenuEntry.disabledReason`（W3 help-actions 加（主 Agent 跨批核对补充））；行尾小字用 W6 cm-edge-menu 加的 `note`。
- `estimateNodeCost` / `formatNodeCost` 按 W2 派工单；合入后有出入以代码为准。
- 「从这一镜播放」未做：需要监视器暴露「开始播放」入口（sequence_monitor 的 `_play` 私有）。建议后续单开一片，或由主 Agent 决定是否只做「跳到这一镜」（selectShot）。
- 镜头节点无产物、但其叙事后继有尚未出图的 config 时，按画板规则仍判「还没有配置节点」（那个 config 在序列里自己成一镜）；与用户直觉可能不一致。
- 若 W13 create-menu-pick-recent 改了 `generateNode` 的签名，以合入后为准，只调用不改。
