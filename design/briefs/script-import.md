# script-import · 导入剧本写段落、接到链尾、估时长写进镜头
- 波次 W11 / lane C / 基底：origin/main（W0–W10 已合入）；依赖切片：script-tables（W10，ScriptRepository + scope.scripts）、duration-format（W0，formatDurationLabel）、naming-shot-unify（W0）、clipboard-text-paste（W8，对话框预填入口）、undo-stack / undo-node-create-move（W0 / W4，软依赖）；阻塞决定：无（RailScript R3 → B 按建议走）

## 目标（用户看到什么变化，2–4 行）
导入剧本对话框的预览里每镜多一列估算时长，顶上写「N 镜 · ~M 秒」，底部多一个默认勾上的「把估算时长写进镜头」。点「创建 N 个镜头」后：画布上已有叙事链时，新镜接在链尾后面（不再从原点 / 视口中心另起一条）；每镜的原文按段写进本画布的剧本；新建的镜带上估算时长，序列里不再一律 3 秒。整次导入 Ctrl Z 一步撤掉。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/GapsPanels.dc.html` ›「剧本导入对话框：识别角色 · 估时长」：流程不变（粘贴 → 拆分 → 实时预览 → 一个事务建链）；预览头「3 镜 · 约 9 秒 · …」，每行一个时长；估时长「中文 4 字 / 秒、英文 2.5 词 / 秒，最少 2 秒，与剧本面板同一个函数」；「把估算时长写进镜头」默认勾（R3），写 duration_ms；「整次导入一步撤销」。角色 chip / 「设为角色」不在本片（W13 script-import-characters）。
- `b2/project/RailScript.dc.html` ›「剧本 P1」：「导入 / 追加走现有导入对话框，同一事务写段落；新镜接链尾」；「时长：有 duration_ms 用实数，否则按字数估…显示走统一时长格式」；「需要你定」R3 建议 B：「只写新建的镜」。
- 板上数字核对：GapsPanels 三镜 8 / 13 / 10 个汉字 ⇒ 2 / 4 / 3 秒，合计 9 ⇒ 规则是「只数汉字、标点不算、按秒向上取整、再取 ≥ 2」。
- 设计缺口：RailScript 第 02 段「江面雾气渐散，渔夫撑船缓缓驶出画面。」16 字按规则是 ~4 秒，板上写 ~5 秒（合计 ~14 应为 ~13），以 GapsPanels 的算法为准。
- 设计缺口：GapsPanels 每行写「2 秒」不带 ~，RailScript 估算值带 ~；本片行与合计都用 `estimated: true`（都是估算）。
- 设计缺口：接到链尾时，链尾若在视口外，用户看不到新镜；板上没画是否定位 / 选中，本片不动相机与选中，只在预览里写「接在第 N 镜之后」并保留完成通知。
- 设计缺口：链尾在泳道里时新镜进不进那条道，板上没说；本片让新镜跟链尾同道（与「下一镜」不出锚点泳道一致）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/storyboard/util/duration_estimate.dart`（新）：估时长唯一一份（RailScript 剧本面板 W12 也调它）。
- `lib/features/storyboard/util/script_splitter.dart`：`ShotDraft` 加 `sourceText`（段原文，剥编号前、已 tidy）；`==`/`hashCode` 带上。
- `lib/features/storyboard/providers/script_import_controller.dart`：同一事务写 document + 段落 + 节点 + 边；接链尾；写 duration_ms；返回结果记录；登记一步撤销。新增两个顶层纯函数（链尾、接续落点）放在本文件。
- `lib/features/storyboard/widgets/script_import_dialog.dart`：预览加时长列与合计、「接在第 N 镜之后」提示行、「把估算时长写进镜头」勾选框；兼容 W8 的预填入口。
- 测试：`test/features/storyboard/util/duration_estimate_test.dart`（新）、`test/features/storyboard/util/script_splitter_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-dialog：`widgets/canvas_toolbar.dart`（「更多」里的导入剧本入口不动）、`widgets/left_rail/outline_panel.dart`、Ctrl ↵ 核心键文件、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`。
- node-menu-append-chain：新 `util/append_to_chain.dart` 等三个新文件（本片不 import 它，同波未合）。
- result-inspector-align：`widgets/canvas_inspector_panel.dart`、`result_inspector_parts.dart`、`image_result_inspector.dart`、`video_result_inspector.dart`、`lib/theme/icons/ink_glyph.dart`。
- mention-token-core：`lib/features/generation/generation_controller.dart`、`lib/services/import/import_remapper.dart`、`util/clipboard_snapshot.dart`、`lib/features/generation/services/prompt_assembler.dart`。
- f6-notification-region：`toast_layer.dart`、`ink_toast_card.dart`、`toast_center.dart`、`notification_bell.dart`、`shortcut_catalog.dart`。
- 全波：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`（空白处「导入剧本…」入口不动）、`canvas_shortcuts.dart`、`models/canvas_command.dart`、`util/narrative_order.dart`（只调用）、`util/create_menu_model.dart`（只调用 nextNarrativeSortOrder）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：f6-notification-region：`lib/features/settings/widgets/shortcuts_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// duration_estimate.dart（纯 Dart）
const double kCjkCharsPerSecond = 4;
const double kLatinWordsPerSecond = 2.5;
const int kMinEstimatedShotMs = 2000;
/// 汉字 / 假名 / 谚文按字数，拉丁字母数字串（含 ' ’ -）按词数；标点与空白不算；
/// 秒 = 字/4 + 词/2.5，向上取整到整秒，再取 ≥ 2 秒。
int estimateShotDurationMs(String text);

// script_splitter.dart
class ShotDraft { const ShotDraft({required label, required notes, required sourceText}); final String sourceText; }

// script_import_controller.dart
typedef ScriptImportResult = ({int count, List<String> nodeIds, String? appendedAfterNodeId});
/// 链尾 = orderByNarrativeChain(include: narrativeChainMembers 里的) 的最后一个；画布上没有叙事链 ⇒ null。
CanvasNode? scriptChainTail(List<CanvasNode> nodes, List<CanvasEdge> edges);
/// 第一镜左上角：x = max(链尾右沿, 链尾名下 result 节点的右沿) + kResultColumnGap，y = 链尾 y；
/// 链尾在泳道里且画布 lane_direction = vertical ⇒ 沿 y 排（y = 下沿 + gap，x = 链尾 x）。
Offset scriptAppendOrigin({required CanvasNode tail, required List<CanvasNode> nodes, required LaneDirection direction});
Future<ScriptImportResult> importDrafts(List<ShotDraft> drafts, {Offset origin = Offset.zero, bool writeEstimatedDuration = true});
```
importDrafts 流程：事务前读 `canvasNodesControllerProvider(canvasId).future`、`canvasEdgesControllerProvider(canvasId).future`、`canvasLaneDirectionProvider(canvasId).future` 求链尾与落点（有链尾时忽略 `origin`）。`uow.run` 里依次：`scope.scripts.ensureDocument(canvasId)` → `nextParagraphSortOrder(docId)` 取起号 → 逐镜 `scope.nodes.create(type: shot, laneId: tail?.laneId, typeConfig: {'shot_notes': notes, if (writeEstimatedDuration) 'duration_ms': estimateShotDurationMs(notes)})` → 逐镜 `scope.scripts.createParagraph(sourceText: draft.sourceText, nodeId: 新节点, sortOrder: 起号 + i)` → 有链尾时先建 `tail → 第一镜` 叙事边（sortOrder = `nextNarrativeSortOrder(anchorId: tail.id, edges)`），再建新镜之间的边（沿用现在的 sortOrder: i）。提交后 invalidate 节点 / 边控制器（现有两行不动），再登记撤销。
对话框：`_drafts` 仍每帧现算；`_writeDuration = true`；预览头 `scriptImportPreviewSummary(count, durationLabel)`；每行尾 `formatDurationLabel(l, ms, estimated: true)`；有链尾时预览上方一行 `scriptImportAppendAfter(n)`（n = `sequenceShotNumbers(nodes, edges)[tail.id]`，拿不到号用 `scriptImportAppendAfterChain`）；勾选框在预览下、按钮上；`_confirm` 传 `writeEstimatedDuration: _writeDuration`。W8 加的 `initialText` 参数（clipboard-text-paste 派工单写的名字，以落地为准）原样保留，预填文字同样参与实时预览与估时。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 估时：「山脊上，阿青回头望」⇒ 2000；「雾里走出一个老人，提着一盏灯」⇒ 4000；「两人对视，很久没有说话」⇒ 3000；「a fox runs」⇒ 2000（3 词 1.2 s → 2 s 下限）；12 个英文词 ⇒ 5000；中英混排两项相加后再取整；空串 ⇒ 2000。
2. 预览头写镜数与合计（上例三镜 ⇒ 「3 镜 · ~9 秒」）；满 60 秒走 m:ss（formatDurationLabel 自己处理）。空文本 ⇒ 现有空态文案，不画合计、勾选框仍在但「创建」禁用。
3. 勾着 ⇒ 每个新镜 type_config 有 `duration_ms`（= 预览显示的那个数）；不勾 ⇒ 没有这个键（不是 0）。默认勾上，每次打开对话框都重置为勾上。
4. R3 B：只写新建的镜——画布上原有节点的 type_config 一个字节不改（含链尾）。
5. 画布上没有叙事链 ⇒ 行为与现在一致：从 `origin` 沿 x 排开、新镜不进泳道、不建接续边。
6. 有链尾 ⇒ 第一镜落在链尾（及其名下产物那一列）右侧 kResultColumnGap 处、同一 y；新镜 laneId = 链尾 laneId；多一条 `链尾 → 第一镜` 叙事边，sortOrder 排在链尾已有出向叙事边之后（链尾已有分叉时新镜成为最后一个分叉）。
7. 链尾所在泳道是竖向（lane_direction = vertical）⇒ 沿 y 往下排。
8. 每镜一段：document 不存在时新建、存在时续写；段落 sort_order 从已有最大值 + 1 起连续；段落 node_id = 对应新镜；source_text 保留段首编号（「镜头 1：…」原样），notes 照旧剥编号。
9. 失败零残留：任一步（建 document / 节点 / 段落 / 边，含接续边）抛 InkError ⇒ 节点、边、document、段落全回滚；对话框留着可再点，toast 走现有 `scriptImportFailed`。单段超过 131072 字被库拒 ⇒ 同此路径。
10. 取消 / Esc：不写任何东西（现有行为）；导入进行中（_busy）取消按钮禁用，不能中途取消。
11. 撤销：整次导入登记为一步——撤销 = 软删全部新镜与新边（含接续边），重做 = 恢复；段落行不删，node_id 仍指向那些镜（撤销后剧本页显示「已删」，重做后自动恢复关联）。撤销前先冲 pendingWriteRegistry（CanvasHistoryController 自带）。
12. 并发：导入事务进行中有生成任务落 result 节点 ⇒ 不影响（result 不在链上）；同画布两次导入接连提交 ⇒ 第二次以第一次的末镜为链尾（每次都在事务前重新读链）。
13. 预填（W8）：带预填打开 ⇒ 输入框有字、预览与合计立即可见、勾选框默认勾。
14. mac / Windows 无差异（换行已在 splitter 统一 CRLF / CR）。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| scriptImportPreviewSummary | {count, plural, =1{1 shot} other{{count} shots}} · {duration} | {count} 镜 · {duration} |
| scriptImportWriteDuration | Write estimated durations into shots | 把估算时长写进镜头 |
| scriptImportAppendAfter | Continues after shot {number} | 接在第 {number} 镜之后 |
| scriptImportAppendAfterChain | Continues at the end of the story chain | 接在叙事链末尾 |
（`duration` 占位符传 formatDurationLabel 的结果；`scriptImportShotCount` 若不再被引用由主 Agent 决定是否删。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `duration_estimate_test.dart`（新）：板上三例 2000 / 4000 / 3000；纯标点 ⇒ 2000；英文 3 词 / 12 词；中英混排；全角数字与半角数字都算一个词（规则 1）。
- `script_splitter_test.dart`：`sourceText` 保留「镜头 1：」前缀而 notes 已剥；CRLF 归一后 sourceText 无 \r；perLine 下 sourceText = 该行。
- `script_import_controller_test.dart`（沿用文件里的 staging 仓储写法，加 `test/_harness/fake_script_repository.dart`（script-tables 新建）的 staging 版或在文件内包一层）：
  - 「勾选 ⇒ 每镜 duration_ms = estimate；不勾 ⇒ 无此键」（规则 3）。
  - 「无链 ⇒ 落点同旧、不建接续边」（规则 5，旧用例保留）。
  - 「有链 ⇒ 第一镜在链尾右侧 gap、同道、接续边 sortOrder = 已有最大 + 1」：链尾预置一条 sortOrder 3 的出边，断言新边 4（规则 6）。
  - 「链尾名下有 result ⇒ x 越过产物列」「竖向泳道 ⇒ 沿 y」（规则 6、7）。
  - 「原有节点 type_config 不变」（规则 4，对 fake 仓储 patch / update 调用计数 = 0）。
  - 「document 已存在 ⇒ 不新建、段落从 max+1 续号、node_id 一一对应、sourceText 带编号」（规则 8）。
  - 「第 k 段 createParagraph 失败 ⇒ 节点 / 边 / 段落 / 文档零提交」「接续边失败 ⇒ 同样零提交」（规则 9）。
  - 「导入后历史栈多一步；undo ⇒ 新镜与新边被软删、段落还在；redo ⇒ 恢复」（规则 11；undo-stack 未落地则此组标 skip 并写进回报）。
  - 「连续两次导入 ⇒ 第二次接在第一次末镜之后」（规则 12）。
- `script_import_dialog_test.dart`：「三段板上原文 ⇒ 预览头含 formatDurationLabel(l, 9000, estimated: true)、每行有时长」；「勾选框默认勾上，取消勾选后点创建 ⇒ controller 收到 false」（用 override 的 fake controller 记参数）；「画布有链 ⇒ 出现接在第 N 镜之后」；「空文本 ⇒ 无合计、创建禁用」；「预填文字 ⇒ 预览立即有合计」（规则 2、3、13）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 估时里 `ceil` 改成 `round` ⇒ 板上 13 字例（4000）红。
2. 下限 2000 去掉 ⇒「a fox runs」例红。
3. 把标点算进字数 ⇒ 8 字例变 3000 红。
4. `if (writeEstimatedDuration)` 去掉（总写）⇒「不勾无此键」红。
5. 有链尾时仍用 `origin` ⇒「链尾右侧」红。
6. 接续边 sortOrder 写死 0 ⇒「最大 + 1」红。
7. 删掉接续边那一步 ⇒ 有链用例红。
8. 段落写到事务外（单独 await 仓储）⇒「段落失败零提交」红。
9. 段落 sortOrder 从 0 起 ⇒ 续号用例红。
10. 对话框勾选初值改 false ⇒ 默认勾上用例红。
11. 不登记撤销 ⇒ 历史栈用例红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/storyboard`；上面 11 条变异。
- 截图（test/_harness/screenshot.dart，ScriptImportDialog，zh 与 en 各一）：① 粘入 GapsPanels 三段原文、画布无链（预览头「3 镜 · ~9 秒」、三行时长、勾选框勾着）；② 画布已有 2 镜的链（多出「接在第 2 镜之后」）；③ 空文本空态；④ 取消勾选后的样子。

## 风险与不确定
- 撤销：canvas_command.dart 本波没人能改，CanvasCommand 是 sealed、子类只能写在那个文件里。本片复用 W4 undo-node-create-move 的「新建若干节点 + 边算一步」那条命令（名字以落地为准）；若它只收单节点，需主 Agent 裁决：要么 W12 起归属给本功能补一个 ImportShotsCommand，要么接受「每镜一步」的降级——本片先不登记并在回报里说明，不得私改 canvas_command.dart。
- 链尾判据与 W11 node-menu-append-chain 的 `append_to_chain.dart`（同波未合）语义相同；本片在 controller 里用 orderByNarrativeChain + narrativeChainMembers 现写，两片合入后由主 Agent 决定是否统一成一个函数。
- 接续落点不避让已有节点（可能压到别的卡上）；next-shot（W10）的 `nextShotPlacement` 若已支持「锚点之后第 k 个、越过占位」，可改调它——签名以落地为准，执行代理核对后二选一并写进 PR 说明。
- W8 预填参数名 `initialText`、W0 改过的确认按钮键（「创建 N 个镜头」）以落地为准；W8 的 `script_import_dialog_prefill_test.dart` 必须仍绿。
- W8 胶囊「按剧本拆镜…」给的 origin 是文本节点下方；画布已有叙事链时本片忽略 origin、接到链尾——拆出来的镜会离那个文本节点很远。按 RailScript「新镜接链尾」走，回报给主 Agent 作为设计缺口。
- 段落原文含编号前缀是本片替 RailScript 定的（「原文是来源」R4）；W12 剧本页若要隐藏编号在显示侧处理。
