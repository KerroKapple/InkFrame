# script-reimport-diff · 重新导入剧本逐段比对（同段沿用原镜、新段建镜、删掉的段标出）
决定：RailScript-R2 按建议 B（逐段比对；做这一片）

- 波次：W17；lane：B；基底：origin/main（W0–W16 已合入后的 main）
- 依赖切片（硬依赖，执行时均已在 main）：script-tables（W10，v10：`script_documents` / `script_paragraphs`、`ScriptRepository`、UoW `scope.scripts`）、script-import（W11：导入 / 追加同事务写段落、新镜接链尾、估时长写 `duration_ms`、`ShotDraft` 带原段文本）、rail-script-panel（W12：左栏剧本页 `script_panel.dart` / `script_model.dart` / `script_document_provider.dart`）。另用到：narrative-splice（W1：`narrative_splice.dart` 的 `insertPlan`）、next-shot（W10：`next_shot.dart` 的 `nextShotPlacement`）、script-import-characters（W13：导入时的角色匹配）、script-panel-repair-actions（W13：`script_document_controller.dart`、面板头「追加…」）、duration-format（W0）。
- 阻塞决定：RailScript-R2 只决定做不做（plan.md 第 5 节「不阻塞、按建议默认」）→ 按建议 B 执行。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 剧本改过之后可以「重新导入」：粘贴新版全文，预览里逐段标出「沿用 / 改动 · 沿用原镜 / 新建 / 原文已删」，确认后只给新段建镜，原有镜头一个不删、段与镜的对应一条不丢。
- 左栏剧本页把从原文里删掉的段留在原位、标「原文已删」，点它仍能定位到那一镜。

## 设计依据
- RailScript 板 · 需要你定 R2：「A 只许追加，不许重导 / B 逐段比对：同段沿用原镜，新段建镜，删掉的段标出 / C 整份替换，旧镜断开对应。建议 B：不删镜头，也不丢对应」。
- RailScript 板 · 剧本小节规则（本片必须保持）：原文只读、改过 `shot_notes` 的段标「备注已改」（R4 A：原文是来源，备注是工作稿）；镜头删了标「已删」可重建；编号 = `sequenceShotNumbers`；导入 / 追加走现有导入对话框、同一事务写段落、新镜接链尾；时长按字数估（中文 4 字/秒，英文 2.5 词/秒，最少 2 秒），走统一时长格式；R3 B：估时长只写进**新建**的镜。
- UndoClipboard 板「什么进栈」：「导入剧本」是一步；GapsPanels 板：「整次导入一步撤销」。
- 设计缺口：① 板上没画重新导入的入口、预览、确认按钮文案和「原文已删」在面板里的样子，本片定义见下；② 只有三类（同段 / 新段 / 删段），没定义「改了几个字的段」——本片加一类「改动 · 沿用原镜」（相似度 ≥ 0.6 视为同段，见风险）；③ 「原文已删」标记能不能手动清掉没画，本片不做。

## 允许改的文件
- `lib/features/storyboard/util/script_diff.dart`（新建）：纯函数段落比对。
- `lib/features/storyboard/providers/script_reimport_controller.dart`（新建）：单事务应用比对结果。
- `lib/features/storyboard/providers/script_import_controller.dart`（由 script-import 改过）：把「在事务里建一个镜头节点 + 段落行」那段私有逻辑提成包内可复用函数，供重导用；导入 / 追加行为不变。
- `lib/features/storyboard/widgets/script_import_dialog.dart`（script_import_dialog 热点链 W17 归本片）：加重导模式。
- `lib/features/storyboard/widgets/script_reimport_preview.dart`（新建）：比对预览列表。
- （不改）`ScriptRepository` 与它的实现 / 测试替身：script-tables 已提供 `listParagraphs(documentId, {bool includeDeleted = false})`、`softDeleteParagraph(id)`、`restoreParagraph(id)`、`updateParagraph(id, patch)`、`createParagraph(...)`，本片够用，不加方法。
- `lib/features/canvas/providers/script_document_provider.dart`（由 rail-script-panel 新建）：一并读出已软删段落。
- `lib/features/canvas/widgets/left_rail/script_model.dart`（由 rail-script-panel 新建）：行状态加「原文已删」，页脚计数。
- `lib/features/canvas/widgets/left_rail/script_panel.dart`（由 rail-script-panel 新建）：「原文已删」标记 + 面板头「重新导入…」入口。
- 测试：`test/features/storyboard/util/script_diff_test.dart`（新建）、`test/features/storyboard/providers/script_reimport_controller_test.dart`（新建）、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`。

## 不许碰的文件
- 同波 rail-templates-page：`left_rail_state.dart`、`left_rail/canvas_left_rail.dart`、`left_rail/left_rail_panel.dart`、`left_rail/templates_panel.dart`、`templates/widgets/template_thumbnail_painter.dart`、`util/create_menu_model.dart`、`widgets/create_node_menu.dart` 与 `canvas_menu/` 新建条目、`canvas_toolbar.dart`、`studio/open_canvas.dart`。
- 同波 canvas-minimap：`canvas_screen.dart`（W17 归它）、`canvas_zoom_bar.dart`、`canvas_minimap.dart`、`minimap_geometry.dart`、`minimap_visible.dart`、`app_preferences.dart`、`file_preferences_service.dart`、`canvas_shortcuts.dart`。
- 同波 cm-knife-cut：`canvas_view.dart` / stage_pointer_layer、`edge_cut_controller.dart`、`edge_cut_hit.dart`、`edge_cut_painter.dart`、`canvas_cut_actions.dart`。
- 同波 shortcuts-page-v2：`settings/util/shortcut_catalog.dart`、`pointer_gesture_catalog.dart`、`overlay_key_catalog.dart`、`settings/widgets/shortcuts_section.dart`。
- 只读引用、不改：`narrative_splice.dart`、`next_shot.dart`、`narrative_order.dart`、`canvas_nodes_controller.dart`、`canvas_edges_controller.dart`（写库走自己的 UoW，完事 invalidate，与 `importDrafts` 同法）、`script_splitter.dart`、`script_document_controller.dart`、schema / 迁移（本片无迁移）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W17 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - rail-templates-page：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/util/template_ui_actions.dart`、`lib/features/templates/widgets/template_thumbnail_painter.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/widgets/template_thumbnail_painter_test.dart`
  - canvas-minimap：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/minimap_visible.dart`、`lib/features/canvas/util/minimap_geometry.dart`、`lib/features/canvas/widgets/canvas_capsule_host.dart`、`lib/features/canvas/widgets/canvas_minimap.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/canvas_zoom_bar.dart`、`lib/features/canvas/widgets/shortcuts/minimap_keys.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/minimap_visible_test.dart`、`test/features/canvas/util/minimap_geometry_test.dart`、`test/features/canvas/widgets/canvas_minimap_test.dart`、`test/features/canvas/widgets/canvas_screen_layout_test.dart`、`test/features/canvas/widgets/canvas_zoom_bar_test.dart`、`test/services/file_preferences_service_test.dart`
  - cm-knife-cut：`lib/features/canvas/models/commands/cut_edges_command.dart`、`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/util/canvas_cut_actions.dart`、`lib/features/canvas/util/edge_cut_hit.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/widgets/edge_cut_painter.dart`、`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`test/features/canvas/models/commands/cut_edges_command_test.dart`、`test/features/canvas/providers/edge_cut_controller_test.dart`、`test/features/canvas/util/edge_cut_hit_test.dart`、`test/features/canvas/widgets/canvas_knife_cut_test.dart`
  - shortcuts-page-v2：`lib/features/settings/util/overlay_key_catalog.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/settings/overlay_key_catalog_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/shortcut_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`

## 具体改动
```dart
// script_diff.dart（纯 Dart）
typedef DiffSourceParagraph = ({String id, String text, String? nodeId, int sortOrder});
enum ParagraphDiffKind { keep, changed, restored, added, removed }
@immutable class ParagraphDiffOp {
  final ParagraphDiffKind kind;
  final DiffSourceParagraph? old;   // keep / changed / restored / removed 有
  final int? newIndex;              // keep / changed / restored / added 有：在新稿里的下标
  final String? newText;            // 同上
}
@immutable class ScriptDiffPlan {
  final List<ParagraphDiffOp> ops;  // 合并序 = 落库后的 sort_order（0..n-1，含 removed）
  int get keepCount; int get changedCount; int get addedCount; int get removedCount; // restored 计入 keep
  bool get hasChanges;              // 全是 keep 且 sort_order 不变 ⇒ false
  String get signature;             // 每个 op 的 kind + old.id + newIndex 拼成，用于确认时判「比对过期」
}
String normalizeParagraph(String text);           // 统一换行 → 逐行 trimRight → 连续空白折成一个 → trim
double paragraphSimilarity(String a, String b);   // 规范化后字符二元组 Dice 系数，0..1
const double kParagraphChangedThreshold = 0.6;
ScriptDiffPlan diffParagraphs({
  required List<DiffSourceParagraph> alive,       // 当前未删段，按 sortOrder
  required List<DiffSourceParagraph> removed,     // 以前重导标为原文已删的段（deleted_at 非空）
  required List<String> incoming,                 // 新稿各段原文（ShotDraft 的原段文本），按序
});
```
算法：① alive 与 incoming 按 `normalizeParagraph` 做 LCS → keep；② 每个 LCS 间隙里，按序贪心配对旧段与新段，相似度 ≥ 阈值 → changed（两边指针都只前进）；③ 间隙里剩下的新段，先在 `removed` 里找规范化后完全相同、尚未用过的（按旧 sortOrder 取第一个）→ restored，否则 added；剩下的旧段 → removed；④ 合并序：keep / changed / restored / added 按新稿顺序，removed 紧跟在它在旧序里的前一个旧段之后（间隙开头的跟在间隙前的 keep 之后）。以前已删、本次没被恢复的 removed 段不进 ops，保持原样。
```dart
// script_reimport_controller.dart
final scriptReimportControllerProvider = Provider.family<ScriptReimportController, String>(...); // 不加 autoDispose，理由同 scriptImportControllerProvider
sealed class ScriptReimportResult {}
final class ScriptReimportApplied extends ScriptReimportResult { final int added; final int removed; final int changed; }
final class ScriptReimportStale extends ScriptReimportResult { final ScriptDiffPlan freshPlan; }
class ScriptReimportController {
  /// 一个 UoW：先读文档与段落、按 [drafts] 重算 plan；signature 与 [previewSignature] 不同 ⇒ 不写任何东西，返回 Stale。
  /// 否则按 plan 写库，完事 invalidate 节点、边控制器与 scriptDocumentProvider。失败抛 InkError（已回滚）。
  Future<ScriptReimportResult> apply({required List<ShotDraft> drafts, required String previewSignature, required bool writeEstimatedDuration});
}
```
写库（全部在同一 `uow.run` 里）：
- keep / restored / changed：`sort_order` = 合并序下标；changed 另写 `source_text` = 新文本（**不改**节点 `shot_notes` 与 label）；restored 另清 `deleted_at`，`node_id` 原样。
- removed：段落软删（`deleted_at = now`），`node_id` 保留，`sort_order` = 合并序下标；节点、边一律不动。
- added：用从 `script_import_controller.dart` 提出来的建镜函数建 shot 配置节点（label、`shot_notes`、`writeEstimatedDuration` 时写 `duration_ms`、W13 的角色匹配写 `character_ids`）+ 段落行（`node_id` = 新节点）。连链：锚点 = 合并序里往前最近一个「有 node_id 且节点未删」的段的节点；一串连续新段依次接成小链。
  - 锚点存在且有到「往后最近一个有活节点的段的节点」B 的叙事边 → 照 narrative-splice `insertPlan({required CanvasEdge edge, required String newNodeId, required List<CanvasEdge> edges})` 的形状落：软删 A→B，建 A→首（sortOrder = A→B 原值）、小链内部依次相连、尾→B（sortOrder 0）。`insertPlan` 只收单个新节点：小链只有 1 段时直接用它的 `SplicePlan`；多段时按同一形状在本事务里经 `scope.edges` 写，不改 narrative_splice.dart。
  - 锚点存在、没有到 B 的边、且锚点没有叙事出边 → 建 A→首。
  - 其余（锚点有别的出边 = 分叉，或没有锚点而 B 已有叙事入边）→ 照 script-import 接到链尾。
  - 没有锚点、B 没有叙事入边 → 建 尾→B。
  - 位置：`nextShotPlacement` 以锚点（或小链上一张）为基准；接链尾时与 script-import 落点一致。**不移动任何已有节点**；泳道 = 锚点的 laneId（无锚点 = 不进道）。

面板与对话框：
```dart
// script_model.dart：rail-script-panel 的 `enum ScriptRowStatus { generated, running, pending, deleted }` 描述的是镜头状态，不加值；
// 改为给 `ScriptRow` 追加字段 `final bool removedFromSource;`（段落 deleted_at 非空），镜号与镜头状态照常算——这样「原文已删」行仍显示镜号 / 已删
// 页脚：removed 行不计入「N 段」，>0 时追加「· 原文已删 K」
// script_document_provider.dart：同时给出 alive 与 removed 段落（按 sort_order 合并）
// script_import_dialog.dart：模式枚举（script-import 定的名）加 reimport；只在画布已有剧本文档时出现
Future<void> showScriptImportDialog(BuildContext context, {required String canvasId, Offset origin = Offset.zero, String initialText = '', ScriptImportMode mode = ScriptImportMode.import});
// initialText 由 W8 clipboard-text-paste 加。main 上没有模式枚举：W11 只有一种导入（新段接文档末尾、新镜接链尾），W13 repair-actions 的「追加…」直接打开普通导入对话框。本片新建 `enum ScriptImportMode { import, reimport }`（主 Agent 跨批核对补充）
// script_reimport_preview.dart
class ScriptReimportPreview extends StatelessWidget { const ScriptReimportPreview({super.key, required this.plan}); final ScriptDiffPlan plan; }
```
仓储：读已软删段落 = `listParagraphs(documentId, includeDeleted: true)` 后按 `deleted_at != null` 过滤；恢复 = `restoreParagraph(id)`；标原文已删 = `softDeleteParagraph(id)` + `updateParagraph(id, {sort_order: …})`。

## 行为规则与边界情况
1. 入口：剧本页头部「追加…」旁加「重新导入…」（文字按钮，与「追加…」同样式）；导入对话框在画布已有剧本文档时多一个「重新导入（逐段比对）」模式段。画布没有剧本文档 → 两处都不出现。
2. 重导模式打开时，经 `initialText` 预填当前未删段原文（段间空一行），拆分策略默认「空行分段」；用户可改或全选粘贴新稿。
3. 预览：顶部一行计数「沿用 N · 改动 C · 新建 M · 原文已删 K」；下方逐行「标记 + 段首行」，标记文案：沿用 / 改动 · 沿用原镜 / 恢复 · 沿用原镜 / 新建 / 原文已删（原文已删行文字 fg4）。随输入实时重算。
4. 确认按钮「按比对更新 · 新建 M 个镜头」（M=0 时「按比对更新」）；`!plan.hasChanges` 时禁用并在预览处写「原文没有变化」；新稿为空时禁用（不允许一键把全部段标成已删）。
5. 一段只改了几个字（相似度 ≥ 0.6）= 改动：沿用原镜，更新段落原文，不碰 `shot_notes`；因此面板随后标「备注已改」——这是预期提示。
6. 段落被删：段落行软删，节点、叙事边、产物全部保留；面板该段留在原位标「原文已删」，点它仍单选并居中那一镜。
7. 删掉的段在下次重导中原样回来（规范化后相同）= 恢复：清 `deleted_at`，沿用原镜，不新建。
8. 新段插在中间：按上面的连链规则插进叙事链，不挪已有节点；遇分叉一律接链尾。
9. 估时长：勾选「把估算时长写进镜头」时只写新建的镜（R3 B），沿用 / 改动的镜不动。
10. 比对过期：对话框打开期间剧本被别处改动（追加、重建这一镜、另一次重导）→ 确认时重算 signature 不同 → 什么都不写，预览换成新结果，顶部出提示「剧本刚被改动，已重新比对，请再确认」，按钮保持可点。
11. 失败：任一步抛 InkError → 整个事务回滚，画布与剧本都不变；对话框留着，出错误卡「没能更新剧本，画布和剧本都没有改动」。
12. 成功：关对话框，出成功卡「剧本已更新：新建 M 个镜头，K 段标为原文已删」（不响铃，与导入同）。
13. 撤销：本片**不进撤销栈**（见风险）。
14. 段落数量：比对是 O(n·m)，按 2000 × 2000 段以内设计，不做分块。
15. 重复段（同一句出现两次）按 LCS 顺序配对，不会把两处都对到同一镜。
16. mac / Windows 无差异；所有文案走 ARB，样式走 token。

## 新文案键
| key | en | zh |
|---|---|---|
| scriptPanelReimport | Re-import… | 重新导入… |
| scriptImportModeReimport | Re-import (compare paragraphs) | 重新导入（逐段比对） |
| scriptReimportSummary | {keep} kept · {changed} edited · {added} new · {removed} removed | 沿用 {keep} · 改动 {changed} · 新建 {added} · 原文已删 {removed} |
| scriptReimportMarkKeep | Kept | 沿用 |
| scriptReimportMarkChanged | Edited · keeps shot | 改动 · 沿用原镜 |
| scriptReimportMarkRestored | Back · keeps shot | 恢复 · 沿用原镜 |
| scriptReimportMarkAdded | New shot | 新建 |
| scriptReimportMarkRemoved | Removed from script | 原文已删 |
| scriptReimportNoChanges | The script hasn't changed. | 原文没有变化 |
| scriptReimportConfirm | {count, plural, =0{Update} =1{Update · create 1 shot} other{Update · create {count} shots}} | {count, plural, =0{按比对更新} other{按比对更新 · 新建 {count} 个镜头}} |
| scriptReimportStale | The script changed meanwhile — compared again, please confirm. | 剧本刚被改动，已重新比对，请再确认 |
| scriptReimportDone | Script updated: {added} new shots, {removed} paragraphs marked removed | 剧本已更新：新建 {added} 个镜头，{removed} 段标为原文已删 |
| scriptReimportFailed | Couldn't update the script. Nothing on the canvas or in the script changed. | 没能更新剧本，画布和剧本都没有改动。 |
| scriptPanelFooterRemoved | · {count} removed | · 原文已删 {count} |

## 测试
- `test/features/storyboard/util/script_diff_test.dart`（新）：`完全相同 ⇒ 全 keep 且 hasChanges=false`；`只差空白 ⇒ keep`；`末尾加段 ⇒ added`；`中间插段 ⇒ added 落在两 keep 之间`；`中间删段 ⇒ removed 带原 id 与 nodeId，位置紧跟前一旧段`；`改几个字 ⇒ changed`；`整段重写 ⇒ removed + added`；`以前删掉的段回来 ⇒ restored`；`重复段按序配对`；`合并序即 sort_order 0..n-1`；`signature 随任一 op 变化而变`；`paragraphSimilarity 边界：相同 1.0、空串 0`。
- `test/features/storyboard/providers/script_reimport_controller_test.dart`（新，FakeUnitOfWork + 内存仓储）：`keep 不碰节点与边`；`中间新段：软删 A→B，建 A→新、新→B，节点位置不动`；`锚点分叉 ⇒ 接链尾`；`开头新段且首镜无入边 ⇒ 新→首镜`；`removed：段落软删、node_id 保留、节点与边不变`；`changed：source_text 更新、shot_notes 不变`；`restored：deleted_at 清空、不新建节点`；`writeEstimatedDuration 只写新建镜`；`signature 不符 ⇒ 返回 Stale 且零写入`；`第 N 步抛 InkError ⇒ 整体回滚并抛出`；`成功后 invalidate 节点 / 边 / 剧本文档 provider`。
- `test/features/storyboard/providers/script_import_controller_test.dart`：提函数后原导入 / 追加用例全部不改仍绿；加 `建镜函数单独调用与 importDrafts 建出的节点同形`。
- `test/features/storyboard/widgets/script_import_dialog_test.dart`：`无剧本文档时没有重新导入模式`；`重导模式预填原文`；`改一段后预览计数与标记`；`无变化时按钮禁用并显示原文没有变化`；`Stale 时换新预览并出提示，对话框不关`；`成功关框并出成功卡`。
- `test/features/canvas/widgets/left_rail/script_model_test.dart`：`软删段落行 removedFromSource = true、仍带镜号与镜头状态`；`页脚不计 removed 并追加计数`。
- `test/features/canvas/widgets/left_rail/script_panel_test.dart`：`原文已删标记上屏`；`点原文已删行仍定位到镜头`；`头部重新导入…打开重导模式`。

## 变异点
1. `diffParagraphs` 跳过相似度配对（间隙里一律 removed + added）→ `改几个字 ⇒ changed` 变红。
2. 恢复判定去掉（不查 removed 列表）→ `以前删掉的段回来 ⇒ restored` 与 controller `restored：…不新建节点` 变红。
3. removed 分支改成连节点一起软删 → controller `removed：段落软删、node_id 保留、节点与边不变` 变红。
4. changed 分支顺手写 `shot_notes` → `changed：source_text 更新、shot_notes 不变` 变红。
5. 去掉 signature 比对 → `signature 不符 ⇒ 返回 Stale 且零写入` 与 dialog `Stale 时换新预览…` 变红。
6. 新段一律接链尾（删掉 insertPlan 分支）→ `中间新段：软删 A→B，建 A→新、新→B…` 变红。
7. 分叉时仍走 insertPlan → `锚点分叉 ⇒ 接链尾` 变红。
8. `writeEstimatedDuration` 也写到 keep / changed 镜 → `writeEstimatedDuration 只写新建镜` 变红。
9. 对话框不判 `hasChanges` → `无变化时按钮禁用…` 变红。
10. script_model 把软删段落过滤掉 → `软删段落行 removedFromSource = true…` 变红。

## 验收
- 跑 `flutter analyze lib test`、`flutter test test/features/storyboard test/features/canvas/widgets/left_rail --exclude-tags golden`，逐条变异。
- 截图：① `ScriptImportDialog`（重导模式），FakeUnitOfWork 种一份 4 段剧本（对应 4 镜链），新稿 = 删第 2 段、改第 3 段两个字、在第 3/4 段间插一段 → 截预览（计数 + 五种标记里出现的四种）；② 同一数据确认后的剧本页 `ScriptPanel`（宽 241）→ 截「原文已删」行与页脚；③ 无变化时的对话框（按钮禁用）。

## 风险与不确定
- **撤销**：板上「导入剧本」进栈、「整次导入一步撤销」；重导要撤的东西跨两类表（节点 / 边 + 剧本段落），反向令牌较大。本片先不进栈；若执行时发现 main 上 script-import 已有导入命令（`canvas_command.dart` 里有剧本导入的 CanvasCommand），请主 Agent 决定是本片照写一个「重新导入剧本」命令，还是另开一片。
- 「改动」这一类是本片加的（板只写同段 / 新段 / 删段），阈值 0.6 是经验值；不要这一类就把 `kParagraphChangedThreshold` 设成 1.0（改动全变成删 + 建）。需主 Agent 确认。
- 依赖的名字（`ScriptRepository` 的方法、`ScriptImportMode`、`ShotDraft` 的原段字段、`script_model` 的状态枚举、`scriptDocumentProvider`、`nextShotPlacement` / `insertPlan` 的签名）全部来自前序切片，执行时以 main 上实际代码为准；（`ScriptRepository` 已能列出软删段落、恢复段落，本片不加仓储方法、不动替身。）
- 「原文已删」借用段落 `deleted_at` 表达，含义从「删了」变成「原文里没有了」：script-panel-repair-actions 若有别的路径软删段落，两种语义会混在一起；执行时 grep 段落软删的调用点核对，有冲突在回报里写明。
- 插入新段时不挪已有节点，`nextShotPlacement` 找不到空位时会沿主轴往后放，可能离锚点较远；这是有意取舍（不打乱用户排版）。
- script_import_dialog 已被 W0 / W8 / W11 / W13 四片改过，本片是链上最后一环，diff 尽量放进新文件 `script_reimport_preview.dart`。
