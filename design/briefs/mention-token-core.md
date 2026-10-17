# mention-token-core · `@{角色 id}` 记号纯函数层，接上生成、项目包导入与跨项目粘贴
- 波次 W11 / lane D / 基底：origin/main（W0–W10 已合入）；依赖切片：gen-inputs-snapshot（W2，remapper 里已有 gen_inputs 改写段）、canvas-clipboard-core / clipboard-paste（W7：clipboard_snapshot.dart 的 `draftPaste`（otherProject 分支删 character_ids、降级记号）、`degradeCharacterMentions(String text, Map<String, String> names)` → `({String text, int replaced})`、写系统剪贴板的 `clipboardPlainText(ClipboardSnapshot s, {required String Function(ClipNode) displayName})`、快照里的 `characterNames`）、clipboard-text-paste（W8：指纹比的是复制时存下的 `CanvasClipboardState.systemText`，不重新出字；W8 没有 `snapshotPlainText` 这个函数）、batch-run-executor（W10，generation_controller 的 runGroup 改动在前）；阻塞决定：IS-Q3 → A（提示词里存 `@{角色 id}`，插入即挂载、删标签不卸载，character_ids 仍是唯一来源）

## 目标（用户看到什么变化，2–4 行）
本片没有新界面（@ 补全是 W12 prompt-bar-mention-ui）。它定下提示词里角色引用的存法 `@{<角色 uuid>}`，并让三条路认得它：生成时记号换成角色名再发给模型、角色被删的记号发出时去掉；项目包导入时记号换成新角色 id；跨项目粘贴时记号降成纯文字「@名字」并从 character_ids 剔除。系统剪贴板里的纯文字也写成「@名字」，不把 uuid 露给别的软件。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ImportSearch.dc.html` ›「提示词里 @角色」：「文字里存记号 @{角色 id}，插入同时追加进 character_ids；退格整块删，不卸载」；「发出时记号换成角色名，描述照旧按 character_ids 顺序注入」；「角色被删：标签变灰，发出时去掉」；「项目包导入、模板插入、跨项目粘贴都改写记号：能映射的与 character_ids 走同一张角色表换新 id（项目包导入即 import_remapper 的 characterMap）」；「角色没跟过来的（跨项目粘贴、模板没带该角色）：记号降成纯文字『@名字』，同时从 character_ids 剔除；名字取不到就删掉记号」。「需要你定」3：A 插入即挂载 / B 双向同步 / C 纯文字 @名字——建议 A。
- `b2/project/UndoClipboard.dc.html` ›「要补的底座」：粘贴改写 id 时「跨项目再把提示词里的 @{角色 id}」改写；plan.md 第 3 节 W7–W9 验收「跨项目时 `@{id}` 换成『@名字』，并从 character_ids 删掉」（板上表格格子写的「挂载和 @ 记号都去掉」以 plan 为准）。
- `b2/project/RailScript.dc.html` ›「模板」：插入时「@{角色 id} 剥成纯名字」——本片提供 `stripToNames`，模板插入是 W16 template-core 的事。
- 设计缺口：全保真项目包里每个角色行都在包里、都能映射，「@名字」分支在项目包导入里实际走不到；只有第三方 / 手改的包缺角色行才会映射不到，而那时包里也没有名字 ⇒ 记号直接删。验收要点「remapper 映射不到的角色记号变成『@名字』」只有在包里有该角色的名字、却没有可保留的角色行时才成立，见规则 9。
- 设计缺口：检查器「完整提示词」预览（image_config_inspector 第 609 行 assemblePrompt）、产物检查器 / 画廊的提示词行、⌘K / 大纲筛选都直接显示 type_config.prompt，W12 之后会露出 `@{uuid}`；板上没画这些地方怎么显示，本片不改它们（不在归属内），回报给主 Agent。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/core/text/character_mention.dart`（新）：纯 Dart，不 import Flutter / features / services（放 core 是因为 services/import 不能反向 import features）。
- `lib/features/generation/generation_controller.dart`：`submitFromConfigNode` 里在拼镜头语言前缀之前把 prompt 展开成角色名；jobs.user_prompt 存展开后的文字。
- `lib/services/import/import_remapper.dart`：nodes 那一步在 character_ids 改写之后，用共享函数改写 type_config.prompt；gen_inputs 里的提示词字段同样改写。
- `lib/features/canvas/util/clipboard_snapshot.dart`（W7 新建、W8 改过）：`draftPaste` 的 otherProject 分支换成共享函数；`degradeCharacterMentions` 的实现改为委托 `stripToNames`（签名与返回的 `replaced` 计数不变，W7 的调用点与测试不动）；`clipboardPlainText` 里的提示词走 `stripToNames`。
- `lib/features/generation/services/prompt_assembler.dart`：核对后不改（展开在 controller 里做，拼接公式不变）；列在这里只为表明本波归本片。
- 测试：`test/core/text/character_mention_test.dart`（新）、`test/features/generation/generation_controller_mention_test.dart`（新）、`test/services/import/import_remapper_test.dart`、`test/features/canvas/util/clipboard_snapshot_test.dart`（W7 的，只增用例 / 把原跨项目断言改成新口径）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-dialog：新 `widgets/batch_run_dialog.dart`、`util/canvas_batch_run_actions.dart`、Ctrl ↵ 核心键文件、`widgets/canvas_toolbar.dart`、`widgets/left_rail/outline_panel.dart`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`。
- node-menu-append-chain：新 `util/append_to_chain.dart`、`util/canvas_append_chain_actions.dart`、`canvas_menu/append_chain_menu_entries.dart`。
- result-inspector-align：`widgets/canvas_inspector_panel.dart`、`widgets/result_inspector_parts.dart`、`widgets/image_result_inspector.dart`、`widgets/video_result_inspector.dart`、`lib/theme/icons/ink_glyph.dart`（产物检查器提示词行的显示不在本片改）。
- script-import：`lib/features/storyboard/` 下 controller / splitter / dialog / duration_estimate。
- f6-notification-region：`toast_layer.dart`、`ink_toast_card.dart`、`toast_center.dart`、`notification_bell.dart`、`lib/features/settings/util/shortcut_catalog.dart`。
- 全波：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart`、`models/canvas_command.dart`、`util/canvas_paste_actions.dart`、`widgets/image_config_inspector.dart`、`util/result_params.dart`。
- 同波另有（交叉核对补）：batch-run-dialog 的 `shortcuts/core_canvas_keys.dart`、`util/more_menu_model.dart`、`app_action_catalog.dart` / `app_action_ids.dart`（追加行）；node-menu-append-chain 的 `canvas_menu/menu_registry.dart`（追加行）、新 `models/commands/append_chain_command.dart`；result-inspector-align 的 `lib/theme/tokens.dart`、`lib/theme/icons/ink_glyph.dart`；script-import 的新 `lib/features/storyboard/util/duration_estimate.dart`；f6-notification-region 的新 `lib/features/notifications/widgets/notification_region.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-import：`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_splitter.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`；f6-notification-region：`lib/features/settings/widgets/shortcuts_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/core/text/character_mention.dart
/// 记号字面：`@{` + 小写或大写 8-4-4-4-12 十六进制 uuid + `}`；别的 `@{…}` 是普通文字，不认。
final RegExp kCharacterMentionPattern;
String characterMentionToken(String characterId);           // '@{<id>}'
@immutable class CharacterMention { final int start; final int end; final String characterId; }
List<CharacterMention> parseMentions(String text);            // 按出现顺序
/// 发给模型：记号 → 角色名（不带 @）；nameOf 返回 null / 空白 ⇒ 记号删掉。
String expandToNames(String text, String? Function(String id) nameOf);
/// 纯文字场合（系统剪贴板、模板插入、角色没跟过来）：记号 → '@名字'；取不到名 ⇒ 删掉。
String stripToNames(String text, String? Function(String id) nameOf);
/// 能映射的换新 id；映射不到的原样留着（调用方自己决定再降级）。
String rewriteIds(String text, Map<String, String> idMap);
/// 能映射的换新 id；映射不到的降成 '@名字'，取不到名就删；返回改写后的文字与被降级 / 删掉的旧 id。
({String text, Set<String> droppedIds}) dropUnmapped(String text, Map<String, String> idMap, String? Function(String oldId) nameOf);
/// type_config 一站式：'prompt' 走 dropUnmapped；'character_ids' 只留映射得到的（换成新 id、保序去重）。
/// 返回新 Map（不改入参）与计数，供 remapper 记 nulledRefs、供粘贴出胶囊。
({Map<String, Object?> typeConfig, int droppedMentions, int droppedCharacterIds}) remapCharacterRefsInTypeConfig(
    Map<String, Object?> typeConfig, Map<String, String> idMap, String? Function(String oldId) nameOf);
const List<String> kMentionTextKeys = <String>['prompt'];   // 存记号的 type_config 键；以后加键只改这里
```
删记号时的空白规则（expand / strip / dropUnmapped 共用）：记号被整个删掉时，若它左右都是空白，只留一个空白；行首 / 行尾的记号连同紧挨着的那一个空白一起删；中文无空白处直接删。

generation_controller：`prompt` 判空之后，若 `parseMentions(prompt)` 非空，用 `characters.listByProject(projectId)`（只回未软删）建 id → name 表一次；`sentPrompt = expandToNames(prompt, names)`；`sentPrompt.trim().isEmpty` ⇒ 抛 `InvalidGenerationConfigError('prompt is empty')`（在建 job 事务之前）；后面镜头语言前缀拼的是 sentPrompt，`userPrompt:` 写 sentPrompt。prompt 里没有记号 ⇒ 不读角色表。

import_remapper：nodes 循环里 character_ids 改写之后调 `remapCharacterRefsInTypeConfig(cfg, characterMap, oldName)`，其中 `oldName` 从包里全部角色行（含软删）建；droppedMentions 计入 nulledRefs（character_ids 的计数沿用原有那段，不重复计）。W2 已在本文件改写 gen_inputs 里的源节点 id——就在那段旁边，对 gen_inputs 里存的提示词字段（键名以 gen-inputs-snapshot 落地为准）同样调 `dropUnmapped`。

clipboard_snapshot：`draftPaste` 跨项目分支改调 `remapCharacterRefsInTypeConfig(cfg, const {}, sourceName)`（`sourceName = (id) => snapshot.characterNames[id]`；目标项目没有这些角色 ⇒ 全部降级；`droppedMentions` 计进 `PasteDraft.droppedCharacterRefs`），同项目不动；`clipboardPlainText` 里的提示词改为 `stripToNames(prompt, sourceName)`。胶囊文案沿用 W7 已有的键。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. `parseMentions('拂晓，@{<A>}站在船头 @{<B>}')` ⇒ 两个，顺序 A、B，start / end 精确；`@{abc}`、`@{<A>`（缺右括号）、`@ {<A>}` 都不认。
2. `expandToNames`：A=渔夫 ⇒「拂晓，渔夫站在船头」；名字取不到 ⇒ 记号删掉，按空白规则不留双空格（`'a @{X} walks'` ⇒ `'a walks'`）。
3. `stripToNames`：⇒「拂晓，@渔夫站在船头」；取不到名 ⇒ 删。
4. `rewriteIds`：映射到的换新 id，没映射的原样；无记号的文字原样返回（同一字符串）。
5. `dropUnmapped`：映射到的换新、映射不到有名 ⇒「@名字」、无名 ⇒ 删；droppedIds = 后两者。
6. `remapCharacterRefsInTypeConfig`：不改入参；character_ids 只留映射到的并换新 id；没有 prompt / character_ids 键 ⇒ 原样；prompt 非字符串 ⇒ 不动。
7. 生成：prompt 含挂载角色 A 的记号 ⇒ 发给 provider 的 fullPrompt 与 jobs.user_prompt 里是「渔夫」，不含 `@{`；角色描述注入顺序仍按 character_ids（规则不变）。
8. 生成：A 已软删 ⇒ 记号去掉后照常生成；prompt 只剩一个已删角色的记号 ⇒ 抛 InvalidGenerationConfigError，不建 result 节点、不建 job（零残留）。角色表读失败（InkError）⇒ 原样上抛、不提交（少了主角的提示词照发是花钱出错图，不降级）。
9. 项目包导入：包里有角色 A ⇒ 记号换成 A 的新 id，与 character_ids 换的是同一个新 id；记号指向包里没有的角色 ⇒ 删掉 + nulledRefs；（只有名字可得而行不可保留时才出「@名字」，见设计缺口）。
10. gen_inputs 里的提示词与 type_config.prompt 按同一张表改写——导入后 W7 过期标记不会因为 id 变了而误报过期。
11. 跨项目粘贴：记号全部降成「@名字」、character_ids 清空；同项目粘贴（含同项目别的画布）记号与 character_ids 原样。
12. 复制节点写系统剪贴板的纯文字里是「@名字」；W8 指纹判据仍对得上（W8 比的是复制时存进 `CanvasClipboardState.systemText` 的同一段文字，不重新出字）。
13. 撤销栈：本片不新增命令；粘贴的撤销沿用 W7（记号改写发生在写库前，撤销粘贴 = 删粘出来的节点）。
14. 并发：生成读角色名与用户同时改名 ⇒ 用提交那一刻读到的名字，不重试。mac / Windows 无差异（纯字符串）。

## 新文案键（key · en · zh 表；没有写无）
无（发给模型的是英文常量以外的用户原文；本片不产生新界面文案）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/core/text/character_mention_test.dart`（新）：规则 1–6 逐条，含空白规则三种位置（句中、行首、行尾）、中文无空白、同一 id 出现两次、大写 uuid、`@{abc}` 不认、入参 Map 未被修改（`identical` + 深比较）。
- `test/features/generation/generation_controller_mention_test.dart`（新，沿用现有 generation 测试的 fake 仓储 / registry 写法）：
  - 「记号展开成名字：provider 收到的 prompt 与 jobs.create 的 userPrompt 都不含 `@{`」（规则 7）。
  - 「已删角色的记号去掉，照常提交」（规则 8 前半）。
  - 「只剩已删角色记号 ⇒ InvalidGenerationConfigError，nodes.create / jobs.create 调用 0 次」（规则 8 后半）。
  - 「角色表读失败 ⇒ 抛出、不提交」。
  - 「无记号 ⇒ listByProject 调用 0 次」。
- `test/services/import/import_remapper_test.dart`：「prompt 里的记号与 character_ids 换成同一个新 id」「记号指向包外角色 ⇒ 删掉 + nulledRefs 加 1」「gen_inputs 提示词同样改写」（规则 9、10）。
- `test/features/canvas/util/clipboard_snapshot_test.dart`：「跨项目 ⇒ @名字 + character_ids 清空」「同项目 ⇒ 原样」「clipboardPlainText 是 @名字、不含 uuid」（规则 11、12）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 正则放宽成 `@\{[^}]+\}` ⇒「`@{abc}` 不认」红。
2. expandToNames 取不到名时保留原记号 ⇒ 规则 2 用例红。
3. 删记号不处理空白 ⇒ `'a walks'` 用例红。
4. stripToNames 去掉 '@' 前缀 ⇒ 规则 3 红。
5. remapCharacterRefsInTypeConfig 原地改入参 ⇒ 不变性用例红。
6. generation_controller 里 `userPrompt:` 改回 `prompt` ⇒ userPrompt 用例红。
7. 去掉 `sentPrompt.trim().isEmpty` 判断 ⇒「只剩已删记号」用例红。
8. 角色表读失败改成吞掉 ⇒ 失败用例红。
9. 无记号时也读角色表 ⇒ 调用 0 次用例红。
10. remapper 里删掉 `remapCharacterRefsInTypeConfig` 调用 ⇒ 导入用例红。
11. clipboard_snapshot 跨项目改回旧实现 / 换成 rewriteIds ⇒ 粘贴用例红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/core/text test/features/generation test/services/import test/features/canvas/util/clipboard_snapshot_test.dart test/quality`（no_reverse_layer_import 必须绿：core/text 不 import 上层）；上面 11 条变异。无 UI，不截图。

## 风险与不确定
- gen_inputs 的存放位置与键名以 W2 落地为准；W7 / W8 的名字按派工单（`draftPaste`、`degradeCharacterMentions`、`clipboardPlainText`、`CanvasClipboardState.systemText`），执行代理先读真实代码再接。
- generation_controller 本波只归本片，但 W10 batch-run-executor 刚改过 `submitFromConfigNode`（runGroup）；本片只在 prompt 判空之后插几行，冲突小。
- 显示侧（检查器预览、产物 / 画廊提示词行、大纲 / ⌘K 搜索）还会显示原始记号——W12 prompt-bar-mention-ui 写入记号之前没人会产生记号，所以本片合入时不会露；需要主 Agent 在 W12 前排一片「显示侧 stripToNames」，或并进 W12。
- 生成侧 generate_gate 只看原始 prompt 非空，「只剩已删角色记号」时生成按钮可点、提交才报错——由 W12 在 UI 层补判据。
- docs/CLAUDE.md 要新增 `lib/core/text/` 一行，回报给主 Agent。
