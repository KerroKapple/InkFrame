# script-panel-repair-actions · 剧本面板补全动作：「重建这一镜」「用镜头备注拼出剧本」头部「追加…」
- 波次：W13 / lane：C / 基底：叠在 script-import-characters 之后（分支 `feat/script-import-characters`）
- 依赖切片：rail-script-panel（W12，`script_panel.dart` / `script_model.dart` / `scriptDocumentProvider`）、script-tables（W10，ScriptRepository / UoW `scope.scripts`）、script-import（W11，导入天然接链尾 + 段落接文档末尾、`estimateShotDurationMs`、导入时 `shot_notes` = 剥编号后的 notes）、narrative-splice（W1，`util/narrative_splice.dart`）、script-import-characters（W13 前序，同 lane）
- 阻塞决定：无（R4 已按 A：原文只读；R3 按 B：只给新建的镜写 duration_ms）

## 执行约定
1. 在你自己的工作树里，从 `feat/script-import-characters` 起新分支 `feat/script-panel-repair-actions`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表每片只追加一行——本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（建节点 / 挪位置用现有 `scope.nodes.create` / `update`）。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. **不给 `ScriptRepository` 加方法**：W10 script-tables 已提供 `ensureDocument(canvasId)`、`nextParagraphSortOrder`、`createParagraph({documentId, sortOrder, sourceText, nodeId})`、`updateParagraph(id, patch)`，本片够用。合入后若真缺，停下回报。

## 目标
- 剧本面板里「已删」的段多一个「重建这一镜」：按原文新建一个镜头，插回它在叙事链里原来的位置（前后都接上），段落重新指向新镜头。
- 画布有镜头但没有剧本时，空态多一个「用镜头备注拼出剧本」：按叙事链序把各镜的备注拼成一份剧本，每段对到它的镜头。
- 有剧本时面板头部右侧有「追加…」：打开导入剧本对话框（W11 的导入本来就是新段接在文档末尾、新镜接链尾）。

## 设计依据
`b2/project/RailScript.dc.html`（文本版 SCRATCH/boards/RailScript.txt）「剧本 P1」：
- 稿面：面板头「剧本」右侧「追加…」；已删段（无镜号、「已删」标签）下方一行 accent 链接「重建这一镜」、时长「~2 秒」。
- 「导入 / 追加走现有导入对话框，同一事务写段落；新镜接链尾」。
- 「原文只读；改过 shot_notes 的段标「备注已改」；镜头删了标「已删」，可重建」。
- 「空态：「导入剧本…」；已有镜头时另给「用镜头备注拼出剧本」」。
- R3 建议 B「序列不再一律 3 秒；只写新建的镜」——重建出来的镜是新建的，写估算 duration_ms。
slices.json notes：「重建出来的镜要插回原来那一段在叙事链里的位置（前后都接上），在一个事务里完成」。
- 设计缺口：重建时前后邻居一个都不在、或后一镜已经有别的叙事入边时稿没画——见 R4 / R5。「拼出剧本」时有的镜头备注为空稿没画——跳过（R8）。重建 / 拼剧本失败的反馈稿没画——错误卡（R10）。

## 允许改的文件
- `lib/features/storyboard/providers/script_document_controller.dart`（新建）：`ScriptDocumentController`（重建 / 拼剧本，各一个事务）+ 两个纯规划函数。
- `lib/features/canvas/widgets/left_rail/script_panel.dart`（rail-script-panel 新建）：已删段的「重建这一镜」、空态第二个按钮、头部「追加…」。
- 测试：`test/features/storyboard/providers/script_document_controller_test.dart`（新建，用 W10 的 `test/_harness/fake_script_repository.dart`）、`test/features/canvas/widgets/left_rail/script_panel_test.dart`（加用例）。
- 不改：`core/interfaces/script_repository.dart`、`storage/repositories/postgres_script_repository.dart`（见执行约定 9）。

## 不许碰的文件
- W13 同波：selection-toolbar 的 `selection_toolbar*.dart`、`util/node_menu_model.dart`、`widgets/canvas_view.dart`、`canvas_menu/canvas_menu_host.dart`、`app_preferences.dart`、`file_preferences_service.dart`；outline-drag-reorder 的 `outline_panel.dart`、`outline_model.dart`；create-menu-pick-recent 的 `create_menu_model.dart`、`create_menu_entries.dart`、`util/canvas_tool_actions.dart`、`providers/canvas_nodes_controller.dart`、`recent_presets_provider.dart`；sequence-locate-regenerate 的 `sequence/**`、`left_rail_actions.dart`。
- 同 lane 前序本片不再改：`script_character_match.dart`、`script_import_dialog.dart`、`script_import_controller.dart`、`canvas_shot_notes_actions.dart`。
- `util/narrative_splice.dart`（只调用）、`providers/canvas_edges_controller.dart`、`models/canvas_command.dart`、`create_node_menu.dart`、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- selection-toolbar：`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/util/selection_toolbar_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/selection_toolbar.dart`、`lib/features/canvas/widgets/stage/stage_overlays.dart`（可能）、`lib/features/settings/providers/selection_toolbar_pref_controller.dart`、`lib/features/settings/widgets/canvas_appearance_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/selection_toolbar_model_test.dart`、`test/features/canvas/widgets/selection_toolbar_test.dart`、`test/features/settings/canvas_appearance_section_test.dart`
- outline-drag-reorder：`lib/features/canvas/models/canvas_command.dart`（只追加一行）、`lib/features/canvas/models/commands/outline_reorder_command.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`test/features/canvas/models/outline_reorder_command_test.dart`、`test/features/canvas/util/outline_drop_plan_test.dart`、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`
- script-import-characters：`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
- create-menu-pick-recent：`lib/core/di/recent_job_presets.dart`、`lib/core/interfaces/recent_job_preset_source.dart`、`lib/features/canvas/models/recent_preset.dart`、`lib/features/canvas/providers/recent_presets_provider.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/recent_presets.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/storage/repositories/postgres_recent_job_preset_source.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/providers/recent_presets_provider_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/recent_presets_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`
- sequence-locate-regenerate：`lib/features/canvas/widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/util/sequence_shot_actions.dart`、`lib/features/sequence/widgets/sequence_screen.dart`、`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`、`test/features/sequence/util/sequence_shot_actions_test.dart`、`test/features/sequence/widgets/sequence_context_menu_test.dart`

## 具体改动
已有签名（核对过）：
```dart
// core/interfaces/node_repository.dart 约第 4 行
Future<String> create({required String canvasId, required String type, required String nodeRole, String label = '', String? sourceNodeId, String? laneId, double positionX = 0, double positionY = 0, double width = 240, double height = 240, int zIndex = 0, Map<String, Object?> typeConfig = const {}});
// core/interfaces/edge_repository.dart：create({required canvasId, ...sourceNodeId, targetNodeId, edgeType, sortOrder...}) / update / softDelete
// storyboard/providers/script_import_controller.dart：const double kShotChainSpacingX = 260;
// storyboard/util/script_splitter.dart 约第 46 行：List<ShotDraft> splitScript(String text, {ScriptSplitStrategy strategy = blankLine}); ShotDraft{label, notes}
// canvas/util/narrative_order.dart 约第 27 行：List<CanvasNode> orderByNarrativeChain({required nodes, required edges, bool Function(CanvasNode)? include})
// canvas/util/create_menu_model.dart 约第 160 行：int nextNarrativeSortOrder({required String anchorId, required List<CanvasEdge> edges})
// canvas/models/canvas_node.dart：Size defaultNodeSize(CanvasNodeType)（script_import_controller 在用）
```
前序 API（按前序派工单）：
- narrative-splice（W1）：`SplicePlan? insertPlan({required CanvasEdge edge, required String newNodeId, required List<CanvasEdge> edges})`、`Map<String, Offset> makeRoomShifts({required CanvasEdge edge, required List<CanvasNode> nodes, required List<CanvasEdge> edges, required LaneDirection direction})`（纯函数；本片在自己的 UoW 里照 `SplicePlan` 的 removeEdgeIds / addEdges / sortOrders 写，不调 `applySplice`——那是独立事务，没法和建节点、改段落合成一笔）。
- script-import（W11）：`estimateShotDurationMs(String)`（`storyboard/util/duration_estimate.dart`）；导入对话框**没有追加模式参数**——`importDrafts` 有链尾就自动接链尾、段落自动接在文档末尾（`nextParagraphSortOrder`），所以「追加…」就是普通打开对话框。
- rail-script-panel（W12）：`scriptDocumentProvider(canvasId)` / `ScriptDocumentView { document, paragraphs }`；段落模型是 W10 的 `ScriptParagraph`（`storyboard/models/script_document.dart`）。
- script-tables（W10）：`scope.scripts` 的现成方法——
```dart
Future<String> ensureDocument(String canvasId);   // 没有就建，一画布一份
Future<int> nextParagraphSortOrder(String documentId);
Future<String> createParagraph({required String documentId, required int sortOrder, required String sourceText, String? nodeId});
Future<int> updateParagraph(String id, Map<String, Object?> patch); // patch 键走 ScriptParagraphCol
```
新增（`script_document_controller.dart`）：
```dart
final scriptDocumentControllerProvider = Provider.family<ScriptDocumentController, String>(...); // canvasId；不 autoDispose，理由同 scriptImportControllerProvider
class ScriptDocumentController {
  Future<String> rebuildShot({required ScriptDocumentView doc, required String paragraphId}); // 返回新镜头 id
  Future<int> buildFromShotNotes(); // 返回段数；已有文档时抛 StateError（UI 层不会让它发生）
}
@immutable class ShotRebuildPlan { final Offset position; final String? laneId; final String? prevId; final String? nextId;
  final String? bridgeEdgeIdToRemove; final int prevSortOrder; final bool linkToNext; final Map<String, Offset> shifts; }
ShotRebuildPlan planShotRebuild({required ScriptDocumentView doc, required String paragraphId, required List<CanvasNode> nodes, required List<CanvasEdge> edges});
List<({String nodeId, String text})> planDocumentFromShots({required List<CanvasNode> nodes, required List<CanvasEdge> edges});
```
`rebuildShot` 事务内：建 shot 节点（`final d = splitScript(sourceText).firstOrNull`；label = `d?.label`，空则 `canvasNodeDefaultLabel` 由 UI 传入；typeConfig = `{'shot_notes': d?.notes ?? sourceText, 'duration_ms': estimateShotDurationMs(d?.notes ?? sourceText)}`——与 W11 导入写 `shot_notes` 的口径一致（剥编号后的 notes），否则 W12 的「备注已改」会把重建出来的镜误标）→ 按计划删桥边 / 建 prev→new / new→next → 应用 shifts（`scope.nodes.update` 改位置）→ `updateParagraph(paragraphId, {node_id: newId})`。完成后 invalidate 节点、边控制器与 `scriptDocumentProvider(canvasId)`，并单选新镜头（`canvasSelectionControllerProvider(canvasId).select`）。

`script_panel.dart`：已删行下加 `ScriptPanel.rebuildKey(paragraphId)` 链接；空态在「导入剧本…」下加 `ScriptPanel.fromNotesKey` 按钮（`planDocumentFromShots` 非空才画）；`LeftPanelHeader(trailing: 追加…)` 仅文档存在时画，点 = `showScriptImportDialog(context, canvasId: canvasId)`（W11 的导入天然接链尾、段落接文档末尾；W8 若给它加了 `initialText`，这里不传）。`buildFromShotNotes` 用 `scope.scripts.ensureDocument(canvasId)` 建文档（没有 createDocument）。

## 行为规则与边界情况
- R1 邻居：prev = 该段之前最近一个「节点仍在」的段的节点；next = 之后最近一个「节点仍在」的段的节点。已删段之间互不当邻居。
- R2 prev 与 next 之间有存活的 narrative 边（删除时被 delete-bridge 接上的）→ 走 narrative-splice 的插入口径：删那条边，建 prev→new（沿用旧边 sortOrder）+ new→next；需要让位时照 `makeRoomShifts` 推后续卡。
- R3 prev 与 next 之间没有边 → prev→new 的 sortOrder = `nextNarrativeSortOrder(anchorId: prev)`（排在 prev 已有分叉之后）。
- R4 next 已有别的叙事入边（不是来自 prev）→ 不建 new→next（不造汇合），只接 prev→new；只有 next 没有 prev 时同理判断。
- R5 两个邻居都不在 → 孤立新建，位置 = 链上最右节点右侧一格（`kShotChainSpacingX`），画布无链则世界原点；不连边。
- R6 位置：有 prev = prev 右侧一格；只有 next = next 左侧一格；laneId 取 prev（没有 prev 取 next）。
- R7 原子性：建节点、改边、挪位置、改段落 node_id 在同一事务；任一步失败整体回滚，段落仍是「已删」。
- R8 拼剧本：先叙事链上的 shot 节点（`orderByNarrativeChain` 序），再链外 shot 节点（按 y、再按 x）；`shot_notes` trim 后为空的跳过；全部为空 ⇒ 按钮不画。一个文档 + N 段一个事务；段 `source_text` = 原备注（不 trim 内部换行），`node_id` = 镜头 id。拼出来的段不会被标「备注已改」。
- R9 已有文档时不显示「用镜头备注拼出剧本」；文档存在才显示「追加…」。
- R10 失败：两种动作失败都弹 error 卡（「重建失败，画布未改动」/「拼剧本失败」），面板不变；按钮执行中置灰防连点。
- R11 撤销：两种动作不进撤销栈（`CanvasCommand` 不归本片）；重建出来的镜头可以照常删除。若用户随后撤销「删除原镜头」，旧镜头回来、段落仍指向新镜头——在回报里列为已知行为。
- R12 并发：同一段连点两次 ⇒ 第二次时按钮已置灰；跨窗口并发不考虑（单实例）。
- R13 平台：无平台差异——纯数据操作与普通按钮。

## 新文案键
| key | en | zh |
|---|---|---|
| scriptPanelRebuildShot | Rebuild this shot | 重建这一镜 |
| scriptPanelRebuildFailed | Couldn't rebuild the shot. Nothing was changed. | 重建失败，画布未改动 |
| scriptPanelFromNotes | Build script from shot notes | 用镜头备注拼出剧本 |
| scriptPanelFromNotesFailed | Couldn't build the script from shot notes. | 拼剧本失败 |
| scriptPanelAppend | Append… | 追加… |

## 测试
先写、先红。
- `script_document_controller_test.dart`（纯函数 + fake UoW）：
  - `rebuild between bridged neighbours splices into the bridge edge` — prev→next 有边：删它，建两条，旧 sortOrder 沿用。
  - `rebuild without bridge appends after prev branches` — sortOrder = 最大 + 1。
  - `rebuild does not create a merge into next` — next 已有别的入边 ⇒ 只有 prev→new。
  - `rebuild with no live neighbours is isolated`。
  - `rebuild writes estimated duration_ms and shot_notes in import form` — 段原文「3. 老人坐在船头」⇒ `shot_notes` = 「老人坐在船头」（同 W11 剥编号口径），重建后 W12 的 `shotNotesEdited` 为 false。
  - `rebuild relinks paragraph node_id in the same transaction` — 第三步（改段落）抛错 ⇒ 节点 / 边都回滚。
  - `plan document from shots: chain order, then unchained by position, empty notes skipped`。
  - `buildFromShotNotes writes one document and N paragraphs atomically`。
- `script_panel_test.dart`：`deleted row shows rebuild link`；`empty state shows build-from-notes only when shots with notes exist`；`append shown only when a document exists`；`rebuild failure shows error toast and keeps row deleted`。

## 变异点
- M1 `planShotRebuild` 忽略桥边（不删 prev→next）→ `rebuild between bridged neighbours splices into the bridge edge` 红。
- M2 prev→new 的 sortOrder 固定写 0 → `rebuild without bridge appends after prev branches` 红。
- M3 去掉「next 已有入边则不连」判据 → `rebuild does not create a merge into next` 红。
- M4 把 `updateParagraph` 挪到事务外 → `rebuild relinks paragraph node_id in the same transaction` 红。
- M5 不写 duration_ms，或 `shot_notes` 直接写 sourceText（不剥编号）→ `rebuild writes estimated duration_ms and shot_notes in import form` 红。
- M6 `planDocumentFromShots` 不跳过空备注 → `plan document from shots: ...` 红。
- M7 面板无条件画「追加…」→ `append shown only when a document exists` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/storyboard test/features/canvas/widgets/left_rail`；M1–M7 逐条变异。
- 截图：`ScriptPanel`，ProviderScope 覆写 scriptDocumentProvider（稿例 4 段，第 3 段已删）、节点 / 边控制器；截 ① 已删段带「重建这一镜」② 重建后（第 3 段有镜号）③ 无文档但有 3 个带备注镜头的空态 ④ 头部「追加…」。

## 风险与不确定
- ScriptRepository 的写方法按 W10 派工单已齐（`ensureDocument` / `createParagraph` / `updateParagraph`）；合入后真缺才停下回报，本片不加接口方法。
- `insertPlan` / `makeRoomShifts` 是纯函数（W1 派工单），本片只取它们算出的 `SplicePlan` / 位移，在自己的 UoW 里落库；若合入后它们要求控制器状态，本片按 R2–R6 自写最小规划，不复用。
- 「追加…」不需要对话框参数：W11 的导入一律接链尾；若主 Agent 想让「追加」与「导入」有不同文案，那是 script_import_dialog 的改动，不在本片。
- R8「拼出来的段不会被标备注已改」在备注本身以「1.」之类编号开头时不成立（W12 的比对会先剥编号）；这类备注很少，回报里列为已知行为。
- 撤销交互（R11）未与 undo-stack 打通，属有意取舍；若主 Agent 要求进撤销栈，需要 `canvas_command.dart` 加变体，超出本片范围。
