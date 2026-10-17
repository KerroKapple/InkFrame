# create-menu-pick-recent · 新建菜单：「最近用过」「模型」两组 + 带载荷的 CreateMenuPick
- 波次：W13 / lane：D / 基底：origin/main（前序波已合入，含 W10 next-shot、W0 menu-split）
- 依赖切片：next-shot（W10：`util/next_shot.dart`、`providers/next_shot_controller.dart`；`create_menu_entries.dart` 的 nextShot 项已改走 `createNextShot`）、menu-split（W0：`canvas_menu/create_menu_entries.dart` 的 `createMenuEntry` / `buildCreateMenuGroups` / `runCreateMenuPick`、`theme/components/ink_menu_panel.dart`）、cm-edge-menu（W6：`InkMenuEntry` 已有可选 `String? note`——行尾常显小字，排在键位前）、help-actions（W3：`InkMenuEntry` 已有可选 `tooltip`）、duration-format（W0：`formatDurationLabel`）
- 阻塞决定：无（KM-Q1 / GC-N3 已在 W10 按 GC-N3 的 A 落地，本片不改「下一镜」行为）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/create-menu-pick-recent`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加（docs/CLAUDE.md 的新文件登记也由主 Agent 加）。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片不新增菜单类别，不碰注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法。**不给 JobRepository 加任何方法**（9 个实现 / fake + `job_repository_reachability_test` 闸）：读路径走新的窄接口。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. `addNodeFromMenu` 新增的 `typeConfig` 参数名固定为 `typeConfig`——W14 note-variant 依赖它建便签。

## 目标
- 双击空白 / Tab / 空白处右键「新建…」开的新建菜单（不带连线上下文时）多一组「最近用过」：本项目最近 3 种「模型 + 参数」，点一下就建好一个带这些参数的配置节点；没配 Key 的照样能建，行尾标「无 Key」。
- 在菜单搜索框里打字时多出「模型」组：按 Provider 名或 id 匹配，选「图像配置 · 万相 图像」直接建一个已选好该模型的配置节点。
- 菜单项从枚举 `CreateMenuAction` 改成带载荷的 `CreateMenuPick`，后续片（便签、角色、模板）按同一形状加项。

## 设计依据
- 画板 `b2/project/GapsCanvas.dc.html` ›「新建菜单补项」：
  - 「最近用过」组头 15 高、10px fg5；行 20 高：图标 + 名称（11px）+ 右侧参数摘要（10px，如「5 秒 · 720p」「16:9」）；无 Key 的在名称后挂 14 高描边小标「无 Key」。
  - 原文要点：「最近用过：本项目 jobs 里最近 3 种 provider_id + 参数（不含提示词、种子），去重；点了建节点写这些参数；没 Key 照建」「模型组只在打字时出，按 Provider 名和 id 匹配」「带连线上下文的菜单不加新组」「与左栏节点库共用 recentPresetsProvider；CreateMenuAction 改成带载荷的 CreateMenuPick」。
  - 「模型 · 打字时才出」示例行：「图像配置 · 万相 图像」「视频配置 · 万相 图生视频」。
- 同板「便签」「角色 · 建图像配置并挂上」两组不是本片：便签归 W14 note-variant，角色组归 W18 create-menu-notes-characters（GC-N4）。本片只把 `CreateMenuPick` 做成能让它们追加子类的形状。
- 设计缺口：哪些 job 算「用过」——画板没说状态。本片只取 `status = success` 的 job（失败的参数组合不推荐给用户）。
- 设计缺口：预设的 Provider 已被删（自定义接口删了）或不再支持该类型——画板没画。本片直接不出这一行。

## 允许改的文件
- `lib/features/canvas/util/create_menu_model.dart`：新增 `sealed class CreateMenuPick` 与子类；`createMenuGroups` 改出 `List<List<CreateMenuPick>>`，不带上下文时追加「最近用过」组；新增 `modelPickCandidates`（纯函数，供「模型」组）。原 `CreateMenuAction` 枚举保留为 `CreateMenuActionPick` 的载荷。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（menu-split 新建，名字以合入后为准）：三类 pick 的呈现（文案 / 图标 / 右侧摘要 / 「无 Key」小标 / 组头 / searchOnly）与派发。
- `lib/theme/components/ink_menu_panel.dart`（menu-split 新建）：**偏离归属表，仅在缺功能时才改**——右侧参数摘要（「5 秒 · 720p」）直接用 W6 已加的 `InkMenuEntry.note`，不新建字段；其余若还没有，追加可选字段 `searchOnly`（查询为空时不出）、`searchTerms`（除 label 外参与匹配的词）、`badge`（名称后的描边小标）、组头 `title`；默认值保持现有渲染不变。W13 无人占用。W18 create-menu-notes-characters 会复用这里加的组头。
- `lib/features/canvas/util/canvas_tool_actions.dart`（W13 归本片）：`addNodeFromMenu` 与 `addNodeAtViewportCenter` 各加 `Map<String, Object?> typeConfig = const <String, Object?>{}`，透传给 `CanvasNodesController.addNode`。
- `lib/features/canvas/models/recent_preset.dart`（新建）：`RecentPreset` 手写不可变值对象（同 character.dart 写法）。
- `lib/features/canvas/util/recent_presets.dart`（新建）：纯函数——job 行 → 预设、去重、截 3 条、参数白名单与键名换算。
- `lib/features/canvas/providers/recent_presets_provider.dart`（新建）：`recentPresetsProvider`（按 projectId 分族，autoDispose）。
- `lib/core/interfaces/recent_job_preset_source.dart`（新建）：窄接口 `RecentJobPresetSource` + `RecentJobRow`。
- `lib/storage/repositories/postgres_recent_job_preset_source.dart`（新建）：联表查询实现。
- `lib/core/di/recent_job_presets.dart`（新建，一个服务一个 di 文件）：`recentJobPresetSourceProvider`。
- 测试：`test/features/canvas/util/create_menu_model_test.dart`（改 + 追加）、`test/features/canvas/util/recent_presets_test.dart`（新建）、`test/features/canvas/providers/recent_presets_provider_test.dart`（新建）、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`（新建，`@Tags(['pg'])`）、`test/features/canvas/widgets/create_node_menu_test.dart`（追加）、`test/features/canvas/widgets/canvas_create_menu_test.dart`（随 pick 类型改编译）。
- 不需要改：`providers/canvas_nodes_controller.dart`——`addNode` 已有 `Map<String, Object?> typeConfig` 参数（约第 78 行），slices notes 那条已过时。

## 不许碰的文件
- W13 其他片：`util/node_menu_model.dart`、`widgets/canvas_view.dart`、`canvas_menu/canvas_menu_host.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`（selection-toolbar）；`left_rail/outline_panel.dart`、`util/outline_model.dart`（outline-drag-reorder）；`storyboard/**`、`util/canvas_shot_notes_actions.dart`、`core/interfaces/script_repository.dart`（script-import-characters / script-panel-repair-actions）；`sequence/**`、`left_rail/left_rail_actions.dart`（sequence-locate-regenerate）。
- `core/interfaces/job_repository.dart`、`storage/repositories/postgres_job_repository.dart` 以及所有 `implements JobRepository` 的 fake；`util/next_shot.dart`、`providers/next_shot_controller.dart`（W10 定型，只调用）。
- `create_node_menu.dart`（barrel）、`models/canvas_node.dart`、四张注册表、ARB / generated / docs/CLAUDE.md。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- selection-toolbar：`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/util/selection_toolbar_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/selection_toolbar.dart`、`lib/features/canvas/widgets/stage/stage_overlays.dart`（可能）、`lib/features/settings/providers/selection_toolbar_pref_controller.dart`、`lib/features/settings/widgets/canvas_appearance_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/selection_toolbar_model_test.dart`、`test/features/canvas/widgets/selection_toolbar_test.dart`、`test/features/settings/canvas_appearance_section_test.dart`
- outline-drag-reorder：`lib/features/canvas/models/canvas_command.dart`（只追加一行）、`lib/features/canvas/models/commands/outline_reorder_command.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`test/features/canvas/models/outline_reorder_command_test.dart`、`test/features/canvas/util/outline_drop_plan_test.dart`、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`
- script-import-characters：`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
- script-panel-repair-actions：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`
- sequence-locate-regenerate：`lib/features/canvas/widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/util/sequence_shot_actions.dart`、`lib/features/sequence/widgets/sequence_screen.dart`、`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`、`test/features/sequence/util/sequence_shot_actions_test.dart`、`test/features/sequence/widgets/sequence_context_menu_test.dart`

## 具体改动
```dart
// util/create_menu_model.dart
sealed class CreateMenuPick { const CreateMenuPick(); }
final class CreateMenuActionPick extends CreateMenuPick { const CreateMenuActionPick(this.action); final CreateMenuAction action; }
final class CreateMenuPresetPick extends CreateMenuPick { const CreateMenuPresetPick(this.preset); final RecentPreset preset; }
final class CreateMenuModelPick extends CreateMenuPick {
  const CreateMenuModelPick({required this.type, required this.providerId}); final CanvasNodeType type; final String providerId; }
List<List<CreateMenuPick>> createMenuGroups({CanvasNode? source, List<CanvasNode> nodes = const <CanvasNode>[],
    List<RecentPreset> recent = const <RecentPreset>[]});   // 带 source ⇒ 不加新组
List<CreateMenuModelPick> modelPickCandidates(List<ProviderCapabilities> all); // image：全部；video：configProviderCandidates(video, all)
CanvasNodeType? createdNodeTypeOf(CreateMenuPick pick, {CanvasNode? source, List<CanvasNode> nodes});
Map<String, Object?> createdTypeConfigOf(CreateMenuPick pick); // action ⇒ {}；preset ⇒ preset.typeConfig；model ⇒ {'provider_id': id}

// models/recent_preset.dart
@immutable class RecentPreset { final String providerId; final CanvasNodeType type; final Map<String, Object?> typeConfig; final DateTime usedAt; }

// util/recent_presets.dart
const Set<String> kPresetParamKeys = {'resolution', 'aspect_ratio', 'duration_seconds', 'camera', 'batch_size'};
RecentPreset? presetFromJobRow(RecentJobRow row);   // job_type 不是 image / video ⇒ null；duration_seconds → duration_ms(×1000)
List<RecentPreset> distinctRecentPresets(List<RecentJobRow> rowsNewestFirst, {int limit = 3}); // 去重键 = providerId + type + 排序后的 typeConfig

// core/interfaces/recent_job_preset_source.dart
@immutable class RecentJobRow { final String providerId; final String jobType; final Map<String, Object?> parameters; final DateTime createdAt; }
abstract class RecentJobPresetSource { Future<List<RecentJobRow>> recentSucceededJobs(String projectId, {int scanLimit = 50}); }

// providers/recent_presets_provider.dart
final recentPresetsProvider = FutureProvider.autoDispose.family<List<RecentPreset>, String>(...); // 过滤掉 providerCapabilitiesListProvider 里没有 / 不支持该类型的
```
- SQL（只读，不迁移；jobs 无 project_id，经 canvases 联表；按画布走现有 `idx_jobs_canvas_created`，v5）：
  `SELECT j.provider_id, j.job_type, j.parameters, j.created_at FROM jobs j JOIN canvases c ON c.id = j.canvas_id AND c.deleted_at IS NULL JOIN projects p ON p.id = c.project_id AND p.deleted_at IS NULL WHERE c.project_id = @pid AND j.status = @success ORDER BY j.created_at DESC LIMIT @n`（状态常量用 `JobStatuses.success`，列名用 `JobCol` / `CanvasCol`）。
- 现有签名（照抄，canvas_tool_actions.dart 约第 343 行）：`Future<void> addNodeFromMenu(BuildContext context, WidgetRef ref, {required String canvasId, required CanvasNodeType type, required NodePlacement placement, String? sourceNodeId, CreateMenuEdge? edge})` → 末尾加 `Map<String, Object?> typeConfig = const <String, Object?>{}`；`addNodeAtViewportCenter`（约第 110 行）同样加并透传。`CanvasNodesController.addNode({…, Map<String, Object?> typeConfig = const <String, Object?>{}})` 已存在。
- 派发：`CreateMenuActionPick` 走现有分支不变（`nextShot` 仍走 W10 的 createNextShot，`lane` 仍开对话框）；preset / model pick 一律无连线、无 source，走 `addNodeFromMenu(..., typeConfig: createdTypeConfigOf(pick))`，Tab 开在视口中心的走 `addNodeAtViewportCenter(..., typeConfig: …)`。
- 「无 Key」：读 `inspectorHasApiKeyProvider(providerId)`（inspector_submit_controller.dart 约第 40 行）；未就绪按「有 Key」处理（不闪小标）。名称读 `providerDisplayNamesProvider`；摘要用 duration_format + 画幅 / 分辨率现有 ARB 标签。
- projectId 取 `activeProjectProvider`；为 null（单测里常见）⇒ 「最近用过」组不出。

## 行为规则与边界情况
- R1 不带连线上下文时组序：建节点组 → 「最近用过」（有才出）→ 「模型」（只在查询非空时出）。带连线上下文（从端口拖出）菜单不出这两组。
- R2 「最近用过」最多 3 行；按 job 时间倒序；同 provider + 同类型 + 同参数只留最新一条；不同参数算不同预设。
- R3 预设 typeConfig 只含白名单键（provider_id、resolution、aspect_ratio、duration_ms、camera、batch_size）；**绝不含** prompt、seed、negative_prompt、ref_image_paths、first/last_frame_path、run_group。
- R4 只统计本项目、未软删画布、`status = success` 的 job；别的项目、已删画布的 job 不出现。
- R5 预设的 provider 已不在 `providerCapabilitiesListProvider` 里，或视频预设的 provider 不再能出视频 ⇒ 这一行不出。
- R6 没配 Key ⇒ 照样可点，建出来的节点带这些参数；行上挂「无 Key」。
- R7 「模型」组：查询（去首尾空白、不区分大小写）命中 Provider 显示名或 id 才出；每个 provider 按能力出「图像配置 · X」/「视频配置 · X」；一项都没命中 ⇒ 整组不出（不留分隔线）。
- R8 选中预设 / 模型项：新节点落在菜单锚点（Tab ⇒ 视口中心 + 散布），判泳道写 laneId、只单选不挪相机——与现有建节点同一条路；写库失败弹「添加节点失败」。
- R9 读最近预设失败（仓储抛 InkError）⇒ 「最近用过」组不出，菜单其余照常；不弹错误卡（菜单不是报错的地方），记日志。
- R10 菜单每次打开重新读（provider autoDispose，菜单关掉即回收），刚生成成功的组合下次开菜单就在。
- R11 撤销：走 addNodeFromMenu 的既有撤销登记（W4 undo-node-create-move）；撤销删掉节点，重做恢复的节点必须带同一份 typeConfig。
- R12 平台差异：无（纯菜单数据与派发，键位沿用现有菜单）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCreateMenuRecentGroup | Recently used | 最近用过 |
| canvasCreateMenuModelGroup | Models | 模型 |
| canvasCreateMenuNoKey | No key | 无 Key |
| canvasCreateMenuModelImage | Image config · {provider} | 图像配置 · {provider} |
| canvasCreateMenuModelVideo | Video config · {provider} | 视频配置 · {provider} |

## 测试
- `test/features/canvas/util/recent_presets_test.dart`
  - `'dedupes by provider, type and params keeping newest'`；`'limits to three'`；
  - `'drops prompt, seed, negative prompt and reference paths'`（R3，行里塞满这些键，断言 typeConfig 键集 ⊆ 白名单）；
  - `'converts duration_seconds to duration_ms'`；`'skips rows whose job type is not image or video'`。
- `test/features/canvas/util/create_menu_model_test.dart`
  - 现有用例改成断言 `CreateMenuActionPick`；新增 `'plain menu appends recent group after create group'`、`'wired menu never shows recent group'`、`'createdTypeConfigOf model pick sets provider_id only'`、`'modelPickCandidates lists video only for video-capable providers'`。
- `test/features/canvas/providers/recent_presets_provider_test.dart`（fake RecentJobPresetSource）
  - `'filters presets whose provider is no longer registered'`；`'source error yields empty list'`（R9）。
- `test/storage/repositories/postgres_recent_job_preset_source_test.dart`（pg）
  - `'returns succeeded jobs of the project newest first across canvases'`；`'excludes other projects and soft-deleted canvases'`；`'excludes non-success statuses'`。
- `test/features/canvas/widgets/create_node_menu_test.dart`
  - `'model group appears only while typing and matches provider id'`；`'picking a recent preset creates a node with its type config'`（fake NodeRepository 收到的 typeConfig）；`'preset without api key shows no-key badge and still creates'`。

## 变异点
- M1 `distinctRecentPresets` 的去重键去掉参数部分 → `'dedupes by provider, type and params…'` 红。
- M2 `kPresetParamKeys` 加进 `'seed'` → `'drops prompt, seed…'` 红。
- M3 SQL 去掉 `c.deleted_at IS NULL` → `'excludes other projects and soft-deleted canvases'` 红。
- M4 SQL 去掉 status 条件 → `'excludes non-success statuses'` 红。
- M5 `createMenuGroups` 在带 source 时也追加最近组 → `'wired menu never shows recent group'` 红。
- M6 「模型」组项去掉 `searchOnly` → `'model group appears only while typing…'` 红。
- M7 `addNodeFromMenu` 不透传 typeConfig → `'picking a recent preset creates a node with its type config'` 红。
- M8 provider 过滤删掉 → `'filters presets whose provider is no longer registered'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util test/features/canvas/providers test/features/canvas/widgets test/quality --exclude-tags golden`；pg 测试在 CI 跑 `test/storage/repositories/postgres_recent_job_preset_source_test.dart`；逐条做 M1–M8。
- `test/quality/job_repository_reachability_test.dart` 必须不改就绿（证明没动 JobRepository）。
- 截图场景：`CanvasMenuHost` 开新建菜单（不带上下文），ProviderScope 覆写 `recentPresetsProvider` 为 [万相图生视频 5s·720p、Gemini 图像 16:9（无 Key）]、`inspectorHasApiKeyProvider`：①空查询；②查询「万相」出「模型」组；③从端口拖出的菜单（无新组）。

## 风险与不确定
- 按前序派工单，W3 / W4 / W6 只给 `InkMenuEntry` 加过 `disabledReason` / `note` 与 `InkMenuPanel.rowHeight` / `onArrowOut`，没有组头 / 小标 / 仅搜索时出现 / 额外匹配词；这四样由本片在 ink_menu_panel.dart 追加可选字段（不在归属表，W13 无人占用，回报说明）。右侧摘要用 `note`。
- W10 next-shot 可能已改动 `addNodeFromMenu` 与「下一镜」派发；本片只加参数，不改它的事务结构。
- W4 undo-node-create-move 的重做若按节点字段重建，必须带上 typeConfig——需在合入时核对。
- jobs.parameters 的键名来自 generation_controller（约第 327 行：resolution / aspect_ratio / duration_seconds / camera / seed / negative_prompt / batch_size / ref_image_paths …）；W10 batch-run-executor 会加 run_group，白名单天然排除。
- W18 node-library-drag-recents 复用 `recentPresetsProvider(projectId)`，签名一旦合入就不要再改。
