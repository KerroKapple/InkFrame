# node-library-drag-recents · 节点库拖进画布 +「最近用过 · 本项目」+ 提示词预设组
- 波次：W18；lane：D；基底：叠在 node-library-section 之后（同 lane 串行，那一片先合）
- 依赖切片：
  - 硬依赖 node-library-section（W18，本 lane 前一片）：`node_library_section.dart`、`node_library_model.dart`、`canvas_library_actions.dart`——执行本片时已合入。
  - 硬依赖 stage-drop-target（W4）：`lib/features/canvas/models/canvas_drag_payload.dart`（sealed `CanvasDragPayload`，W4 只定义了 `AssetDragPayload` / `CharacterDragPayload`；其余载荷由各片「追加一行 `part 'drag_payloads/<x>_payload.dart';` + 新 part 文件」）、`widgets/stage_drop/stage_drop_target.dart`（`StageDropHandler<P>`：`acceptsCard` / `acceptsBlank` / `onDrop(StageDropContext, P, {required StageDrop drop, CanvasNode? card})`，载荷源统一用 `CanvasPayloadDraggable`）、`widgets/stage_drop/stage_drop_registry.dart`（分派表 `kStageDropHandlers`，新载荷 = 追加一行处理器）、`canvas_drop_hover.dart`、`drop_placement.dart` 的 `StageDrop = ({Offset viewportPoint, NodePlacement placement, String? cardId})`——已在 main。舞台 DragTarget 的分派**不在** canvas_view.dart 里。
  - 硬依赖 create-menu-pick-recent（W13）：`lib/features/canvas/providers/recent_presets_provider.dart` 的 `recentPresetsProvider`（jobs 联 canvases 去重的本项目最近参数）、`addNodeFromMenu` 可收 `typeConfig`、新建菜单「最近用过」项的建节点函数——已在 main。**不另加仓库方法**（不碰 job_repository）。
  - 已在 main：undo-params（W5，参数改动进栈）、note-variant（W14：`createdNodeType(CreateMenuAction.note) = text`、`createdTypeConfig(action)`〔便签 ⇒ `noteTypeConfig()`〕）。
- 阻塞决定：无（RailScript-R7 按建议 B）

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
节点库六项可以直接拖到画布上：松手处建节点（落进哪条泳道照拖卡片的判定），拖「泳道」松手开「新建泳道」框。
节点组下面多两组：「最近用过 · 本项目」（本项目用过的模型 + 比例 / 时长 / 分辨率，没 Key 的标「无 Key」；拖出或点击 = 建一个预填好的配置节点）和「预设」（项目的提示词预设；拖到图像 / 视频配置上 = 套用，与检查器「预设」同一次写入）。

## 设计依据
画板 `RailScript.dc.html`「节点库」（b2_rail.js 第 102–145 行）：
- 「最近用过 · 本项目」组头带计数；行 36 高、左右 12、间距 8；图标 16 fg4（视频类用 videoConfig 图标，图像类 imageConfig）；标题 fg2 单行省略（「Kling v3 · 16:9 · 5 秒」「万相 图生视频 · 720P」）；第二行 10 号 fg6 时间（「2 小时前」）；行尾「无 Key」10 号 accent 色。
- 拖动时的跟手卡：104×28、圆角 4、surface4 底、1px accent 边、阴影、不透明度 0.92；内含 14 号 accent 图标 + 11 号 fg1 名称，间距 6、左右内边距 8。
- 规则：拖进画布 = 落在松手点，泳道归属走 `resolveLaneDrop`；泳道拖出 = 在落点开框；最近用过：jobs 按 provider_id + 比例 / 时长 / 分辨率去重，本项目最近 5 条，拖出 = 建配置节点并预填；`prompt_presets`（已有表）可作第三组：拖到配置节点上 = 套用，与检查器预设同一写入；没 Key 的预设照列并标出，提交时由现有闸拦。
`GapsCanvas.dc.html`「新建菜单补项」：最近用过不含提示词、种子；点了建节点写这些参数；没 Key 照建；与左栏节点库共用 `recentPresetsProvider`。
`ImportSearch.dc.html`「从左栏拖进画布」：左栏包 Draggable、舞台加 DragTarget，不用新依赖；拖到配置节点时目标卡高亮（stage-drop-target 的琥珀虚线框）。
设计缺口：①「在落点开框」——泳道是整条带、`createLane` 只追加，落点无法决定泳道位置；本单定为松手后开同一个「新建泳道」框，结果与 F 相同；②预设行单击做什么——本单定：恰好选中一个图像 / 视频配置节点时 = 套用到它，否则置灰并悬停说原因；③最近用过条数——画板写 5，GapsCanvas 写 3，`recentPresetsProvider` 只有一份，本单照 provider 返回的条数显示（W13 `distinctRecentPresets` 默认 limit 3，见风险 1）；④最近用过的时间行——W13 的 `RecentPreset.usedAt` 就是时间，第二行画它的相对时间。

## 允许改的文件
- `lib/features/canvas/widgets/left_rail/node_library_section.dart`（由 node-library-section 新建，W18）：六行包 `CanvasPayloadDraggable`（stage-drop-target 的包装件）；加「最近用过」「预设」两组；筛选覆盖三组。
- `lib/features/canvas/util/node_library_model.dart`（由 node-library-section 新建）：最近用过 / 预设的筛选、`canApplyPresetTo` 判据。
- `lib/features/canvas/util/canvas_library_actions.dart`（由 node-library-section 新建）：三个落点处理函数 + 最近用过点击 + 预设点击。
- `lib/features/canvas/util/prompt_preset_apply.dart`（新建）：从检查器抽出的「套用预设」写入。
- `lib/features/canvas/widgets/image_config_inspector.dart`：`_applyPreset`（第 82 行）改调 `applyPromptPreset`，本地 `setState(() => _negCtrl.text = …)` 保留。
- `lib/features/canvas/models/canvas_drag_payload.dart`（由 stage-drop-target 新建，W4）：只追加一行 `part 'drag_payloads/node_library_payloads.dart';`（以及 part 文件要用的类型的 import）。
- `lib/features/canvas/models/drag_payloads/node_library_payloads.dart`（新建，`part of '../canvas_drag_payload.dart'`）：`sealed class NodeLibraryDragPayload extends CanvasDragPayload`，三个子类 `NodeLibraryItemPayload(CreateMenuAction action)`、`RecentPresetPayload(RecentPreset preset)`、`PromptPresetPayload(PromptPreset preset)`。
- `lib/features/canvas/widgets/stage_drop/node_library_drop_handler.dart`（新建）：`NodeLibraryStageDropHandler extends StageDropHandler<NodeLibraryDragPayload>`——`acceptsCard` 只对 `PromptPresetPayload` 且 `canApplyPresetTo(card)` 为真；`acceptsBlank` 对 `PromptPresetPayload` 为 false；`onDrop` 按子类分到下面三个 drop 函数。
- `lib/features/canvas/widgets/stage_drop/stage_drop_registry.dart`（由 stage-drop-target 新建，W4；分派注册表）：`kStageDropHandlers` 只追加一行 `NodeLibraryStageDropHandler(),`。
- `test/features/canvas/widgets/left_rail/node_library_drag_test.dart`（新建）
- `test/features/canvas/widgets/stage_drop/node_library_drop_handler_test.dart`（新建：acceptsCard / acceptsBlank 判据、三种载荷分派）
- `test/features/canvas/util/prompt_preset_apply_test.dart`（新建）
- `test/features/canvas/util/node_library_model_test.dart`（由 node-library-section 新建）：加用例。

## 不许碰的文件
- 同波：`util/create_menu_model.dart`、新建菜单条目文件、`providers/characters_controller.dart`、`models/character.dart`、`theme/components/ink_menu_panel.dart`（create-menu-notes-characters）；`widgets/canvas_toolbar.dart`、`widgets/canvas_more_menu.dart`、`util/more_menu_model.dart`、`command_palette/command_actions.dart`（more-dropdown-panel）；`widgets/back_to_content_chip.dart`、`util/viewport_fit.dart`、`widgets/canvas_screen.dart`（back-to-content-chip）；`pubspec.*`、`export/**`、`core/licenses.dart`、`core/di/video_export.dart`（storyboard-pdf-export）。
- `lib/core/interfaces/job_repository.dart`、`lib/storage/repositories/postgres_job_repository.dart`、`canvas_view.dart` 与 `stage/*`、`stage_drop/stage_drop_target.dart`、`recent_presets_provider.dart`（只读）、`prompt_presets_controller.dart`（只读）、`left_rail_state.dart`、`templates_panel.dart`。
- 只许 import：`canvas_tool_actions.dart` 的 `menuNodePlacement`（:311）、`addNodeFromMenu`（:343）、`addLaneViaDialog`（:135）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - more-dropdown-panel：`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`test/features/canvas/util/more_menu_model_test.dart`、`test/features/canvas/widgets/canvas_more_menu_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`
  - create-menu-notes-characters：`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/theme/components/ink_menu_panel_test.dart`
  - back-to-content-chip：`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`
  - node-library-section：`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/features/canvas/widgets/left_rail/node_library_section_test.dart`（与本片串行共用的文件不列）
  - storyboard-pdf-export：`assets/fonts/NotoSansSC-Regular.ttf`、`assets/fonts/OFL-NotoSansSC.txt`、`lib/core/di/storyboard_pdf.dart`、`lib/core/interfaces/storyboard_pdf_service.dart`、`lib/core/licenses.dart`、`lib/features/export/providers/storyboard_pdf_controller.dart`、`lib/features/export/re_export.dart`、`lib/features/export/util/storyboard_pages.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/storyboard_pdf_dialog.dart`、`lib/services/pdf_storyboard_service.dart`、`lib/services/ui_storyboard_thumbnail_loader.dart`、`pubspec.yaml`、`test/core/licenses_test.dart`、`test/features/export/providers/storyboard_pdf_controller_test.dart`、`test/features/export/util/storyboard_pages_test.dart`、`test/features/export/widgets/storyboard_pdf_dialog_test.dart`、`test/services/pdf_storyboard_service_test.dart`

## 具体改动
```dart
// node_library_model.dart（追加）
bool canApplyPresetTo(CanvasNode node);   // role == config 且 type ∈ {image, video}
List<RecentPreset> filterRecentPresets(List<RecentPreset> items, String query, String Function(RecentPreset) titleOf);
List<PromptPreset> filterPromptPresets(List<PromptPreset> items, String query);   // 按 name 包含匹配，口径同 filterMenuGroups
// RecentPreset = recentPresetsProvider 的条目类型（W13 定名，以实际为准）

// canvas_library_actions.dart（追加）
Future<void> dropNodeLibraryItem(BuildContext context, WidgetRef ref, {required String canvasId, required CreateMenuAction action, required NodePlacement placement});
Future<void> dropRecentPreset(BuildContext context, WidgetRef ref, {required String canvasId, required RecentPreset preset, required NodePlacement placement});
Future<void> createRecentPresetAtCenter(BuildContext context, WidgetRef ref, {required String canvasId, required RecentPreset preset});
Future<void> dropPromptPreset(BuildContext context, WidgetRef ref, {required String canvasId, required String targetNodeId, required PromptPreset preset});
String? presetClickDisabledReason(AppLocalizations l, List<CanvasNode> selected); // null = 可点

// prompt_preset_apply.dart
Future<void> applyPromptPreset(WidgetRef ref, {required CanvasNode node, required PromptPreset preset});
```
- `dropNodeLibraryItem`：建节点类（含便签）= `addNodeFromMenu(context, ref, canvasId: …, type: createdNodeType(action)!, typeConfig: createdTypeConfig(action), placement: drop.placement)`——`drop.placement` 是 stage-drop-target 的 `resolveStageDrop` 算好的（内部即 `createNodePlacement` → `resolveLaneDrop`，与新建菜单同一套），新卡左上角画在松手点；泳道 = `addLaneViaDialog(context, ref, canvasId: …)`（不看选中，不包）。
- 松手点：不自己换算，直接用 `onDrop` 收到的 `StageDrop`（`viewportPoint` / `placement` / `cardId`）。
- `dropRecentPreset` / `createRecentPresetAtCenter`：与新建菜单「最近用过」项同一个建节点函数（W13 落地；只把落点换成松手点 / 视口中心 + 散布），节点类型 = 预设的类型（视频 provider ⇒ video 配置，否则 image 配置，判法以 W13 为准），typeConfig 只含 provider_id + 比例 / 时长 / 分辨率，不含提示词与种子。
- `applyPromptPreset`：取 `inspectorSubmitControllerProvider(node.id).notifier.saveConfig({'prompt': preset.prompt, 'negative_prompt': preset.negative})`，再 `invalidate(canvasNodesControllerProvider(canvasId))`——与 image_config_inspector.dart:82–90 原逻辑逐行相同。撤销：若 undo-params 已在 `saveConfig` 这一层统一进栈，这里不再推；否则按 undo-params 记录 type_config 改动的同一种命令推一步（旧值取写入前 `node.typeConfig` 的 prompt / negative_prompt，原来没有的键撤销时删掉），标签「修改 提示词」用 undo-params 已有的标签。
- `dropPromptPreset`：目标节点从节点控制器现值里按 id 取；取不到或 `!canApplyPresetTo` ⇒ 不写；否则 `applyPromptPreset`，然后单选目标节点（`canvasFocusRequestProvider.request(center: false)`）。
- 预设行单击：`presetClickDisabledReason == null`（恰好选中一个且 `canApplyPresetTo`）⇒ `applyPromptPreset`；否则行置灰（文字 fg6），悬停 tooltip = 原因。
- 跟手卡（`CanvasPayloadDraggable.feedback`）：按画板尺寸 / 颜色，令牌化（`InkRadius.sm`、`context.inkColors.surface4 / accent / fg1`、`InkShadow.overlay`）；`childWhenDragging` = 原行不变；锚点策略由 `CanvasPayloadDraggable` 固定为 `pointerDragAnchorStrategy`；拖动不改选中。`payload` 用上面三个 `NodeLibraryDragPayload` 子类。
- 「最近用过」组：数据 `recentPresetsProvider(projectId)`（W13，`RecentPreset { providerId, type, typeConfig, usedAt }`，`distinctRecentPresets` 截 3 条；没有活动项目整组不画）；第二行时间 = `usedAt` 走 gallery_time 的相对时间；建节点 = `addNodeFromMenu(…, type: preset.type, typeConfig: createdTypeConfigOf(CreateMenuPresetPick(preset)), placement: …)`，点击走 `addNodeAtViewportCenter(…, typeConfig: 同上)`；为空整组不画；标题与「无 Key」判定复用新建菜单「最近用过」项的同一个文案 / Key 状态来源（只 import）。
- 「预设」组：数据 `promptPresetsControllerProvider(projectId)`（prompt_presets_controller.dart:14）；没有活动项目或为空整组不画；行 = 图标 `InkGlyph.text` + 名称（空名回退为提示词前 20 字）。
- 筛选框同时过滤三组，任一组筛空就不画那一组的组头；三组都空 ⇒「没有匹配的节点」。

## 行为规则与边界情况
1. 把「视频配置」拖到空白处松手：在松手点建一个 video 配置，左上角对准松手点，单选，相机不动；拖到某条泳道里松手：新节点 laneId = 该道（与新建菜单落点判定同一函数）。
2. 拖「泳道」松手：弹「新建泳道」框；有选中也不包（拖出 ≠ Ctrl G）。
3. 节点库项拖到某张卡上松手：按落在空白处处理（不连线、不套用），卡片不高亮。
4. 「预设」拖过图像 / 视频配置卡：该卡出 stage-drop-target 的琥珀虚线高亮；拖过文本 / 镜头 / 产物卡或空白：无高亮，松手什么都不做（不出提示）。
5. 预设套用：目标节点 prompt 与 negative_prompt 被整体替换为预设值（预设负向为空也写空串，与检查器一致）；检查器若正开着这张卡，提示词条与负向框随节点重载刷新。
6. 预设套用撤销：一步回到套用前的 prompt / negative_prompt；原来没有 negative_prompt 的，撤销后这个键不存在。
7. 「最近用过」项拖出 / 点击：建出的配置节点 type_config 含 provider_id 与比例 / 时长 / 分辨率中原有的键，**不含** prompt、seed；对应 Provider 没有 Key 时照建，行上标「无 Key」，生成时由现有生成闸（generate_gate.dart）拦。
8. 拖动途中按 Esc：取消拖动，什么都不建（Flutter `Draggable` 默认行为，不另写）。
9. 拖到左栏 / 检查器等舞台以外松手：什么都不建。
10. 写库失败：沿用 `addNodeFromMenu` 的错误卡「添加节点失败」；套用预设失败沿用 inspector_submit_controller 的自动保存失败态。
11. 没有活动项目：节点组照常可拖，「最近用过」「预设」两组不画。
12. 检查器里点预设的行为不变（同一个 `applyPromptPreset`），回归由现有 `image_config_inspector_test.dart` 守。
13. mac / Windows 无差异；拖动用鼠标主键，触控板同。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailNodeLibraryGroupRecent | Recently used · this project | 最近用过 · 本项目 |
| leftRailNodeLibraryGroupPresets | Presets | 预设 |
| leftRailNodeLibraryPresetNeedsTarget | Select one image or video config node first | 先选中一个图像或视频配置节点 |
「无 Key」与最近用过的标题复用 create-menu-pick-recent 加的键；相对时间若要画，复用现有 gallery_time 的格式化（不新增键）。

## 测试
先写会失败的用例。
- `test/features/canvas/util/node_library_model_test.dart`（追加）
  - `canApplyPresetTo：图像 / 视频配置为真，文本 / 镜头 / 产物为假`。
  - `筛选同时作用于最近用过与预设`。
- `test/features/canvas/util/prompt_preset_apply_test.dart`
  - `套用写 prompt 与 negative_prompt 一次 saveConfig`（记录型 InspectorSubmitController 或 InMemoryNodeRepository 断言 type_config）。
  - `套用后撤销回到原值，原来没有的 negative_prompt 被删掉`。
- `test/features/canvas/widgets/left_rail/node_library_drag_test.dart`（外壳级 pump，画布标签 + 模板页；`RecordingNodesController`）
  - `把视频配置拖到舞台空白处：addNode 一次，类型 video，位置 = 松手点换算的世界坐标`（`tester.timedDragFrom` 从行拖到舞台中某点）。
  - `拖进泳道带内：新节点 laneId = 该道`（fake 泳道控制器给一条道）。
  - `拖泳道松手：弹新建泳道框，选中不变`。
  - `拖到左栏松手：不建节点`。
  - `最近用过两条：组头计数 2，无 Key 那条有标`（override `recentPresetsProvider`）。
  - `拖最近用过到舞台：新节点 type_config 含 provider_id、aspect_ratio，不含 prompt / seed`。
  - `预设拖到图像配置卡上：该节点 prompt 被替换并被单选；拖到文本卡上：不写`。
  - `预设行在未选中时置灰，选中一个图像配置后可点`。
  - `没有活动项目：最近用过与预设两组不出现`。

## 变异点
1. `dropNodeLibraryItem` 改成 `addNodeAtViewportCenter`（不用松手点）⇒ `把视频配置拖到舞台空白处…位置 = 松手点` 红。
2. 落点不用 `drop.placement`（改成自己按视口点算、laneId 传 null）⇒ `拖进泳道带内：新节点 laneId = 该道` 红。
3. `canApplyPresetTo` 放开到全部配置节点 ⇒ `canApplyPresetTo…` 与 `拖到文本卡上：不写` 红。
4. 最近用过建节点时把 prompt 一起带上 ⇒ `…不含 prompt / seed` 红。
5. `applyPromptPreset` 不写 negative_prompt ⇒ `套用写 prompt 与 negative_prompt 一次 saveConfig` 红。
6. 撤销不删原本不存在的键 ⇒ `…原来没有的 negative_prompt 被删掉` 红。
7. 预设行去掉置灰判断 ⇒ `预设行在未选中时置灰…` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/widgets/left_rail test/features/canvas/util/node_library_model_test.dart test/features/canvas/util/prompt_preset_apply_test.dart test/features/canvas/image_config_inspector_test.dart test/features/canvas/util/drop_placement_test.dart`；逐条变异。
- 截图（screenshot 标签）：`InkShell` 画布标签、左栏模板页、fake 两节点 + 一条泳道、`recentPresetsProvider` 两条（一条无 Key）、两条预设；截①节点库三组全开；②拖「图像配置」途中（跟手卡悬在舞台上）；③拖预设悬在图像配置卡上（卡片琥珀虚线高亮）。

## 风险与不确定
1. 「最近用过」条数：画板 5、GapsCanvas 3、计划要求只复用 `recentPresetsProvider` 不加仓库方法；本单显示 provider 给多少就多少（W13 写死 3）。要 5 条需 W13 的 provider 支持 limit 参数——请主 Agent 拍板是否接受 3。
2. （已按 stage-drop-target 派工单落定）舞台拖放按 `kStageDropHandlers` 分派，本片只追加一个处理器，不碰 canvas_view.dart / stage_*。三种载荷合成一个 sealed 父类，是为了「注册表每片只追加一行」。
3. `canvas_drag_payload.dart` 只追加 part 行（与 import），不改 `AssetDragPayload` / `CharacterDragPayload`（素材 / 角色拖放在用）。part 文件不能自带 import，`CreateMenuAction` / `RecentPreset` / `PromptPreset` 的 import 加在 canvas_drag_payload.dart 头部。
4. 套用预设的撤销是否已被 undo-params 在 `saveConfig` 层覆盖，以 W5 代码为准，二选一，不得重复推栈（重复会让一次 Ctrl Z 只撤一半）。
