# rail-script-panel · 左栏剧本页（P1）：原文逐段对到镜头
- 波次：W12 / lane：C / 基底：origin/main（前序波已合入，含 W10 script-tables、W11 script-import）
- 依赖切片：script-tables（W10：`ScriptRepository.findDocumentByCanvas(canvasId)` / `listParagraphs(documentId, {includeDeleted})`、`scriptRepositoryProvider`（FutureProvider）、手写模型 `ScriptDocument` / `ScriptParagraph`（`lib/features/storyboard/models/script_document.dart`，带 `fromRow`）；一画布一份文档，`UNIQUE(canvas_id)`）、script-import（W11：`estimateShotDurationMs(String text)` 在 `lib/features/storyboard/util/duration_estimate.dart`；导入时 `shot_notes` = 剥编号后的 `draft.notes`，`source_text` = 剥编号前的 `draft.sourceText`）、duration-format（W0：`formatDurationLabel(l, ms, {estimated})`，「~」前缀走 W0 的 `durationEstimated`）、menu-split（W0，CanvasMenuPopover / InkMenuPanel）
- 阻塞决定：RailScript R4 → 选 A（原文只读，改备注去检查器）。R1 / R2 / R3 不在本片。

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W11 已合入）起新分支 `feat/rail-script-panel`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片不碰任何注册表（段落右键菜单是面板自己的，不进 menu_registry）。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法；本片不写库（只读剧本表）。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. **不碰 `util/canvas_tool_actions.dart`**：slices.json 写的 `generateImageFromShotNotes` 改放新文件 `util/canvas_shot_notes_actions.dart`。`left_rail_actions.dart` 只复用（`focusNodeOnCanvas`），不改。

## 目标
- 左栏导航条在「角色」下面多一个「剧本」键；点开 241 面板，列出这张画布导入过的剧本原文，一段一行，行首是与大纲 / 序列同号的镜号。
- 每行标出：备注已改 / 生成中 / 未生成 / 已删，以及时长（实数「4 秒」或估算「~5 秒」）；底栏汇总段数、已生成 / 未生成镜数、总时长。
- 点段 = 单选那一镜并居中；画布上选中镜头时对应段高亮。右键段：定位 · 用本镜备注生成 · 复制原文。没有剧本时给「导入剧本…」。

## 设计依据
`b2/project/RailScript.dc.html`（文本版 SCRATCH/boards/RailScript.txt），小节「导航条」「剧本 P1 原文逐段对到镜头」：
- 导航条：「LeftRailPage 加 script / templates，声明序 = 从上到下」「没做完的页不画键」「点当前页收起、Ctrl \ 开合、记住停在哪页都不变」。本片只加 `script`（templates 归 W17 rail-templates-page）。
- 「编号 = sequenceShotNumbers，与大纲 / 序列同号；镜里有产物 = 已生成」。
- 「点段 = 单选镜头并居中；画布上选中镜头，段跟着高亮」。
- 「右键段：定位 · 用本镜备注生成 · 复制原文」。
- 「原文只读；改过 shot_notes 的段标「备注已改」；镜头删了标「已删」，可重建」（「重建这一镜」按钮归 W13 script-panel-repair-actions，本片只标「已删」）。
- 「时长：有 duration_ms 用实数，否则按字数估（中文 4 字/秒，英文 2.5 词/秒，最少 2 秒）；显示走统一时长格式：不满 60 秒「N 秒」，满 60 秒 m:ss」。估算前缀「~」（稿：「~5 秒」、底栏「~14 秒」）。
- 底栏样式：「4 段 · 已生成 1 镜 · 未生成 1 · ~14 秒」（已删段的估算时长也计入总时长）。
- 「空态：「导入剧本…」；已有镜头时另给「用镜头备注拼出剧本」」——第二个按钮归 W13 script-panel-repair-actions；头部「追加…」也归 W13；「剧中角色」行归 W15。
- 设计缺口：稿上「已生成」那一行没画标签（只在底栏计数）——本片「已生成」不画标签；「生成中」稿上没画样式——照大纲行 `nodeStatusOf` 的 running 样式画一个小标签。剧本文档读库失败的状态没画——照素材页画 `InkErrorBanner`。

## 允许改的文件
- `lib/features/canvas/providers/left_rail_state.dart`：`enum LeftRailPage { outline, assets, characters, script }`（追加在末尾，声明序 = 导航条序），注释同步。
- `lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`：在角色键下加 `pageKey(LeftRailPage.script, InkGlyph.script, l.leftRailScript)`；头注「剧本不画」那句删掉改成现状。
- `lib/features/canvas/widgets/left_rail/left_rail_panel.dart`：switch 加 `LeftRailPage.script => ScriptPanel(canvasId: canvasId)`。
- `lib/features/canvas/widgets/left_rail/script_panel.dart`（新建）：面板 UI。
- `lib/features/canvas/widgets/left_rail/script_model.dart`（新建，纯函数）：行 / 状态 / 时长 / 底栏汇总。
- `lib/features/canvas/providers/script_document_provider.dart`（新建）：按画布读剧本文档 + 段落。
- `lib/features/canvas/util/canvas_shot_notes_actions.dart`（新建）：「用本镜备注生成」共享动作。
- `lib/features/canvas/widgets/shot_config_inspector.dart`：`_generateFromNotes` 的建节点 + 连边主体搬进上面的共享动作，检查器只调用它（行为不变）。
- 测试：`test/features/canvas/widgets/left_rail/script_model_test.dart`（新建）、`test/features/canvas/widgets/left_rail/script_panel_test.dart`（新建）、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`（新建）、`test/features/canvas/providers/left_rail_state_test.dart`（加用例）、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`（加用例）。

## 不许碰的文件
- W12 其他 lane：`util/node_menu_model.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/canvas_menu_request.dart`、`canvas_menu/multi_menu_entries.dart`、`canvas_menu/menu_registry.dart`（cm-multi-select-menu / locate-in-gallery）；`core/interfaces/toast_service.dart`、`notifications/**`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`（toast-category-mute）；`widgets/canvas_prompt_bar.dart`、`providers/inspector_submit_controller.dart`、`widgets/characters_section.dart`、`widgets/character_library_panel.dart`、`widgets/mention_*.dart`（prompt-bar-mention-ui）；`gallery/**`（locate-in-gallery）。
- 同 lane 后序：`storyboard/**`（含 script_import_dialog / script_import_controller，W13 归 script-import-characters）；`widgets/left_rail/script_panel.dart` 在 W13 由 script-panel-repair-actions 叠改。`core/interfaces/script_repository.dart` / `storage/repositories/postgres_script_repository.dart` 本片与后序都不改（W10 方法已够）。
- `util/canvas_tool_actions.dart`、`widgets/left_rail/left_rail_actions.dart`、`widgets/left_rail/outline_panel.dart`、`util/outline_model.dart`、`create_node_menu.dart`（barrel）、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W12）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- cm-multi-select-menu：`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_menu/multi_menu_entries.dart`、`lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`、`test/features/canvas/util/node_menu_model_test.dart`、`test/features/canvas/widgets/canvas_multi_menu_test.dart`
- toast-category-mute：`lib/core/interfaces/toast_service.dart`、`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/canvas_snackbars.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/notifications/providers/toast_center.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/features/notifications/widgets/notification_bell.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/_harness/fake_toast_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/canvas_snackbars_test.dart`、`test/features/notifications/providers/toast_center_test.dart`、`test/features/notifications/widgets/job_notification_listener_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
- prompt-bar-mention-ui：`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/canvas_prompt_bar.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/characters_section.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/features/canvas/widgets/mention_text_controller.dart`、`test/features/canvas/providers/inspector_submit_mention_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/characters_section_mounted_guard_test.dart`、`test/features/canvas/widgets/mention_text_controller_test.dart`、`test/features/canvas/widgets/prompt_bar_mention_test.dart`
- locate-in-gallery：`lib/features/canvas/widgets/canvas_menu/node_locate_gallery_entry.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/providers/gallery_selection.dart`、`lib/features/gallery/util/locate_in_gallery.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_grid.dart`、`test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`、`test/features/gallery/util/locate_in_gallery_test.dart`、`test/features/gallery/widgets/gallery_locate_test.dart`

## 具体改动
已有签名（照抄，核对过）：
```dart
// widgets/left_rail/left_rail_actions.dart 约第 21 行
void focusNodeOnCanvas(WidgetRef ref, {required String canvasId, required CanvasNode node});
// util/outline_model.dart 约第 75 行
Map<String, int> sequenceShotNumbers(List<CanvasNode> nodes, List<CanvasEdge> edges);
// sequence/util/shot_index.dart 约第 39 行
Map<String, int> shotIndexByNode(SequenceLens lens, {required List<CanvasNode> nodes});
// providers/node_active_job.dart 约第 12 行：nodeActiveJobProvider（family<JobState?, String>）；jobsRegistryProvider 为全表
// storyboard/widgets/script_import_dialog.dart 约第 21 行
Future<void> showScriptImportDialog(BuildContext context, {required String canvasId, Offset origin = Offset.zero});
// providers/canvas_nodes_controller.dart 约第 70 行 addNode({label, type, role, sourceNodeId, laneId, position, typeConfig ...})
// providers/canvas_edges_controller.dart 约第 51 行 addEdge({sourceNodeId, targetNodeId, edgeType, role, roleResolver, sortOrder})
```
前序 API（按前序派工单）：`ScriptRepository.findDocumentByCanvas(String canvasId) → Future<Map<String, Object?>?>`、`listParagraphs(String documentId, {bool includeDeleted = false}) → Future<List<Map<String, Object?>>>`（sort_order, id 升序）、`ScriptDocument.fromRow` / `ScriptParagraph.fromRow`（`storyboard/models/script_document.dart`，字段 `ScriptParagraph { id, documentId, sortOrder, sourceText, nodeId?, deletedAt? }`、`ScriptDocument { id, canvasId, characterCandidates }`）、`ScriptDocumentCol` / `ScriptParagraphCol`（`core/db/columns.dart`）——以上 W10 script-tables；`estimateShotDurationMs(String)`（W11，`storyboard/util/duration_estimate.dart`）；`formatDurationLabel(AppLocalizations l, int ms, {bool estimated = false})`（W0，`lib/l10n/duration_format.dart`）；`CanvasMenuPopover` / `InkMenuEntry`（menu-split）。

新增（**不另建段落模型**，直接用 W10 的 `ScriptParagraph` / `ScriptDocument`）：
```dart
// providers/script_document_provider.dart
@immutable class ScriptDocumentView { final ScriptDocument document; final List<ScriptParagraph> paragraphs; String get documentId => document.id; } // 段落已按 sortOrder 排、已滤掉 deleted_at；document 带 characterCandidates，W15 script-characters-row 直接读它
final scriptDocumentProvider = FutureProvider.autoDispose.family<ScriptDocumentView?, String>(...); // canvasId → 没有文档为 null
// 刷新：watch canvasNodesControllerProvider(canvasId) 的「节点 id 集合」签名（select 成排序后拼接的字符串），
// 导入 / 追加会改节点集 ⇒ 自动重读；单纯拖动节点不重读。

// widgets/left_rail/script_model.dart（纯 Dart，不 import Flutter widgets）
enum ScriptRowStatus { generated, running, pending, deleted }
@immutable class ScriptRow { final ScriptParagraph paragraph; final int? shotNumber; final ScriptRowStatus status;
  final bool notesEdited; final int durationMs; final bool durationEstimated; final bool highlighted; }
@immutable class ScriptFooter { final int paragraphs; final int generated; final int pending; final int totalMs; final bool anyEstimated; }
List<ScriptRow> buildScriptRows({required ScriptDocumentView doc, required List<CanvasNode> nodes,
  required List<CanvasEdge> edges, required Set<String> runningNodeIds, required Set<String> selection});
ScriptFooter scriptFooterOf(List<ScriptRow> rows);
bool shotNotesEdited(CanvasNode shot, String sourceText);

// util/canvas_shot_notes_actions.dart
/// 以 [notes] 为 prompt 在 [shot] 右侧建 [type] 配置节点 + narrative 边 shot→新节点；
/// 建节点失败返回 null 并弹 [addFailedMessage]，连线失败弹 [linkFailedMessage]（节点保留，同现状）。
Future<CanvasNode?> createConfigFromShotNotes(WidgetRef ref, {required CanvasNode shot, required CanvasNodeType type,
  required String notes, Map<String, Object?> extraConfig = const {}, required String label,
  required String addFailedMessage, required String linkFailedMessage});
```
`script_panel.dart`：`ScriptPanel(canvasId)`，结构 = `LeftPanelHeader(title: l.leftRailScript)` → `ListView` 段落行 → 底栏一行。行 = 镜号（两位，`01`；无镜号不画）+ 原文（只读，最多 4 行省略）+ 右侧标签 / 时长。行的测试锚点 `ScriptPanel.rowKey(paragraphId)`。右键（抬起时开，与画布右键同手感）经 `CanvasMenuPopover` 开三项菜单。

## 行为规则与边界情况
- R1 `LeftRailPage.script` 排在 characters 之后；`tapPage(script)` 与其它页同语义（点展开着的当前页 = 收起），Ctrl \ 只开合不换页。
- R2 段落按 `sortOrder` 升序，`deleted_at` 非空的段不出现。
- R3 镜号 = `sequenceShotNumbers(nodes, edges)[paragraph.nodeId]`；不在链上 / 节点不在 = 不画镜号。
- R4 状态判据（按顺序取第一条命中）：`nodeId == null` 或节点不在实时节点表 → `deleted`；该镜（`shotIndexByNode` 同一镜的任一节点）有活跃 job → `running`；序列 lens 里该镜 `kind != SequenceArtifactKind.none` → `generated`；否则 `pending`。
- R5 备注已改 = 节点 `type_config.shot_notes` 与「导入时写进去的那段备注」在「CRLF→LF + trim」后不相等；`deleted` 行不判。导入时写的备注 = `splitScript(sourceText).firstOrNull?.notes ?? sourceText`（W11 存的 `source_text` 是剥编号前的原文、`shot_notes` 是剥编号后的 `draft.notes`，直接比 `sourceText` 会把「1. 拂晓…」这类带编号的段全标成已改）。刚导入、未改过的段必须不标。
- R6 时长：节点 `type_config.duration_ms` 为正整数 → 实数；否则该镜视频产物的 `duration_ms` → 实数；否则 `estimateShotDurationMs(sourceText)` → 估算（`durationEstimated = true`）。显示一律 `formatDurationLabel(l, ms, estimated: durationEstimated)`（「~」前缀由 W0 的 `durationEstimated` 键出，不另建键）。`deleted` 行一律估算。
- R7 底栏：段数 = 行数；已生成 = `generated` 行数；未生成 = `pending` 行数（running / deleted 都不计入两者）；总时长 = 全部行之和；任一行是估算则总时长加「~」。
- R8 点行：非 `deleted` → `focusNodeOnCanvas(ref, canvasId, node)`；`deleted` → 无动作。
- R9 高亮：画布选中集里任一节点与该段的节点在同一镜（`shotIndexByNode` 相同）或就是该段节点 → 高亮。选中变化只重建面板，不重读库。
- R10 右键菜单：「定位」= R8；「用本镜备注生成」= `createConfigFromShotNotes(type: image, notes: 节点当前 shot_notes)`，备注为空或 `deleted` 置灰（不隐藏）；「复制原文」= `Clipboard.setData(sourceText)` + info 卡「已复制原文」，任何状态都可用。
- R11 空态：`scriptDocumentProvider` 为 null 或 0 段 → `LeftPanelNote` 说明 + 按钮「导入剧本…」= `showScriptImportDialog(context, canvasId: canvasId)`。读库失败 → `InkErrorBanner`（不静默成空态）。
- R12 原文只读：行内不出输入框；改备注只能去检查器（R4 A）。
- R13 检查器「用本镜备注生成图像 / 视频」行为不变（仍用输入框里尚未落盘的备注文本、仍是先建节点再连边、失败分两种卡）——抽取是纯搬移。
- R14 撤销：本片不写库、不进撤销栈；「用本镜备注生成」建节点走 `addNode` 现有路径，撤销行为与检查器入口一致。
- R15 平台：无平台差异——Clipboard 与右键在 macOS / Windows 同一套 Flutter API；右键菜单 mac 上 ctrl+单击也按 secondary tap 处理（与画布同）。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailScript | Script | 剧本 |
| scriptPanelEmpty | No script on this canvas yet | 这张画布还没有剧本 |
| scriptPanelNotesEdited | Notes edited | 备注已改 |
| scriptPanelStatusRunning | Generating | 生成中 |
| scriptPanelStatusPending | Not generated | 未生成 |
| scriptPanelStatusDeleted | Deleted | 已删 |
| scriptPanelFooter | {paragraphs} paragraphs · {generated} generated · {pending} not generated | {paragraphs} 段 · 已生成 {generated} 镜 · 未生成 {pending} |
| scriptPanelMenuLocate | Locate | 定位 |
| scriptPanelMenuGenerate | Generate from shot notes | 用本镜备注生成 |
| scriptPanelMenuCopy | Copy original text | 复制原文 |
| scriptPanelCopied | Original text copied | 已复制原文 |
（scriptPanelFooter 的三个占位符都是 int，用 ICU plural 写英文复数；底栏总时长单独接在后面，用 `formatDurationLabel(estimated: anyEstimated)`。导入按钮复用现有 `canvasAddImportScript`（「导入剧本…」；若 W0 naming-shot-unify 改了它的名字，用改后的）；估算「~」复用 W0 `durationEstimated`，不新建。）

## 测试
先写、先红。
- `script_model_test.dart`：
  - `shot number follows sequenceShotNumbers` — 3 段对 3 个链上镜头，号 1/2/3；第二段节点不在链上时无号；再加折叠场景：shot→config 两节点落在同一镜，两段同号（与 sequenceShotNumbers 一致，narrativeSequenceIndex 会给出不同号）。
  - `deleted when node missing or nodeId null` — 两种情况都是 deleted。
  - `running beats generated` — 该镜配置节点有活跃 job 且已有产物 → running。
  - `generated when shot has artifact` / `pending when no artifact`。
  - `fresh import is not notes-edited`（两例：sourceText 不带编号、shot_notes 只差 CRLF；sourceText 为「1. 拂晓，渔夫出港」、shot_notes 为剥编号后的「拂晓，渔夫出港」——与 W11 实际写法一致）/ `edited notes are flagged`。
  - `real duration from duration_ms, else video artifact, else estimate` — 三档，估算行 durationEstimated=true。
  - `footer counts and total include deleted estimate` — 稿例：4 段 · 已生成 1 · 未生成 1 · 14 秒且 anyEstimated。
  - `highlight when selection is in the same shot` — 选中产物节点，对应段高亮。
- `script_panel_test.dart`（ProviderScope 覆写 scriptDocumentProvider、canvasNodes / Edges 控制器、jobsRegistry）：
  - `empty state shows import button` / `load error shows banner`。
  - `tap row selects and centers shot`（断言 selection == {shotId}）；`tap deleted row does nothing`。
  - `secondary tap opens menu with three entries; generate disabled for deleted`。
  - `copy puts source text on clipboard`（mock SystemChannels.platform）。
- `canvas_shot_notes_actions_test.dart`：`creates config node right of shot and narrative edge`；`add failure returns null and toasts`；`link failure keeps node and toasts link message`。
- `left_rail_state_test.dart`：`script page is last and tapPage(script) toggles like others`。
- `canvas_left_rail_test.dart`：`script key opens script page`（keyOf('script')）。
- 现有 `shot_config_inspector_test.dart` / `_sb3` / `_sb4` 不改即绿（纯搬移守卫）。

## 变异点
- M1 `script_model.dart` 镜号改用 `narrativeSequenceIndex` 而不是 `sequenceShotNumbers` → `shot number follows sequenceShotNumbers` 红（构造一个折叠场景：shot→config 两节点同一镜）。
- M2 状态判据把 running 放到 generated 之后 → `running beats generated` 红。
- M3 `shotNotesEdited` 去掉 CRLF 归一 / trim，或改成直接与 `sourceText` 比（不经 `splitScript` 剥编号）→ `fresh import is not notes-edited` 红。
- M4 时长跳过视频产物那一档 → `real duration from duration_ms, else video artifact, else estimate` 红。
- M5 底栏总时长排除 deleted 行 → `footer counts and total include deleted estimate` 红。
- M6 高亮只比 nodeId 不比同镜 → `highlight when selection is in the same shot` 红。
- M7 `script_panel.dart` 点 deleted 行仍调 focus → `tap deleted row does nothing` 红。
- M8 共享动作去掉连边 → `creates config node right of shot and narrative edge` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/widgets/left_rail test/features/canvas/providers/left_rail_state_test.dart test/features/canvas/util/canvas_shot_notes_actions_test.dart test/features/canvas/widgets/shot_config_inspector_test.dart test/features/canvas/widgets/shot_config_inspector_sb3_test.dart test/features/canvas/widgets/shot_config_inspector_sb4_test.dart`；M1–M8 逐条变异。
- 截图：`CanvasLeftRail` + `CanvasLeftRailPanel`（leftRailProvider 覆写为 script 页），覆写 scriptDocumentProvider 为稿例 4 段（01 备注已改 / 02 生成中 / 已删 / 03 未生成）；截 ① 稿例全貌 ② 第 2 段被选中高亮 ③ 右键菜单开着（已删行，生成置灰）④ 空态。暗色 / 亮色各一张。

## 风险与不确定
- ScriptRepository 方法名、`ScriptParagraph` / `ScriptDocument` 模型都按 W10 script-tables 派工单写；W10 定了 `UNIQUE(canvas_id)`，一画布只有一份文档。合入后名字若有出入以代码为准，回报里列差异。
- 「备注已改」按 W11 派工单的写法比对（`shot_notes` = 剥编号后的 notes，`source_text` = 剥编号前）；合入后核对一次 `script_import_controller` 实际写进 `shot_notes` 的值，与 R5 的「`splitScript(sourceText).firstOrNull?.notes`」不一致就以实际写法为准并点名。
- W13 script-panel-repair-actions「重建这一镜」与「用镜头备注拼剧本」写进库的 `shot_notes` / `source_text` 必须与 R5 同口径，否则重建出来的镜会被误标「备注已改」——已在 W13 派工单里对齐。
- `scriptDocumentProvider` 靠「节点 id 集合」签名刷新：只改段落不改节点的写入（W13 修复动作）需要显式 `invalidate`，由 W13 负责。
- toast-category-mute 同波给 `ToastService.show` 加了带默认值的 `category` 参数；本片「已复制原文」卡不传它（默认 general），两片互不影响。
