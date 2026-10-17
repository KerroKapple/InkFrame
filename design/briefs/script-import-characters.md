# script-import-characters · 剧本导入识别角色：已有角色名挂到镜头，划选「设为角色」导入时新建
- 波次：W13 / lane：C / 基底：origin/main（W12 已合入，含 rail-script-panel、W11 script-import）
- 依赖切片：script-import（W11：`importDrafts(List<ShotDraft> drafts, {Offset origin = Offset.zero, bool writeEstimatedDuration = true}) → Future<ScriptImportResult>`（`({int count, List<String> nodeIds, String? appendedAfterNodeId})`），同一事务写 document + 段落 + 节点 + 边、接链尾、登记一步撤销；`ShotDraft` 已有 `sourceText`）、rail-script-panel（W12，新建 `util/canvas_shot_notes_actions.dart` 的 `createConfigFromShotNotes`）、script-tables（W10，`scope.scripts`）
- 阻塞决定：RailScript R1 → 选 B（A + 原文划选「设为角色」，零 LLM）。后序 script-panel-repair-actions 叠在本片之后（同 lane 串行）。

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W12 已合入）起新分支 `feat/script-import-characters`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表每片只追加一行——本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（镜头节点的 `character_ids` 在 `scope.nodes.create` 的 typeConfig 里一次写好）。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 匹配函数**只有一份**：`lib/features/storyboard/util/script_character_match.dart`（不建 slices.json 里的 `script_character_detect.dart`）。W15 script-characters-row 会复用并扩展计数函数，规则以 RailScript 板为准，写死在本片的测试里。

## 目标
- 导入剧本对话框在预览里现算角色：项目里已有的角色名出现在某段 = 那一镜旁的实心 chip，导入后写进镜头节点 `character_ids`。
- 在原文里选中一段文字点「设为角色」= 成为虚线候选 chip；勾着的候选导入时在同一事务里新建成没有参考图的角色，并挂到出现它的镜头上。
- 预览摘要变成「3 镜 · 约 9 秒 · 2 个角色（1 个新建）」；「用本镜备注生成」建出来的配置节点带上镜头的 `character_ids`。

## 设计依据
`b2/project/GapsPanels.dc.html`（文本版 SCRATCH/boards/GapsPanels.txt）小节「剧本导入对话框：识别角色 · 估时长」：
- 「流程不变（粘贴 → 拆分 → 实时预览 → 一个事务建链）；角色与时长都在预览里现算，纯函数，不调 LLM」。
- 「已有角色名出现 = 实心 chip，导入时挂到这一镜（写镜头节点 character_ids；「用本镜备注生成」要把它带到配置节点，这一步要补）」。
- 「文本里选中一段 → 「设为角色」→ 虚线候选，勾着的导入时新建成没有参考图的角色（RailScript R1）」。
- 稿面：原文区下有「设为角色」按钮；「角色」行：实心「阿青」、虚线「老人 · 新建」；预览行 = 镜号 + 首句 + 角色 chip + 时长；摘要「3 镜 · 约 9 秒 · 2 个角色（1 个新建）」；按钮「创建 3 个镜头」（W11 已做）。
`b2/project/RailScript.dc.html`「剧本」小节：「角色：已有角色名匹配 = 实心；虚线候选可新建 / 关联 / 忽略」；R1 建议 B「零 LLM，与拆分器同口径，结果可测」。本片只做导入时的「新建」；关联 / 忽略在面板里，归 W15。
- 设计缺口：候选 chip 怎么取消勾选没画——本片：点虚线 chip 切换勾选，未勾 = 灰虚线、不计入「新建」；chip 右侧 × 移除候选。划选的文字与已有角色同名时稿没画——按已有角色处理，不进候选。没有活动项目时（角色是项目级）稿没画——隐藏「角色」行与「设为角色」按钮。

## 允许改的文件
- `lib/features/storyboard/util/script_character_match.dart`（新建）：匹配纯函数。
- `lib/features/storyboard/widgets/script_import_dialog.dart`：「设为角色」按钮、「角色」行、预览行角色 chip、摘要文案。
- `lib/features/storyboard/providers/script_import_controller.dart`：`importDrafts` 收角色计划，同一 UoW 里建候选角色、给镜头写 `character_ids`，成功后 invalidate 角色列表。
- `lib/features/canvas/util/canvas_shot_notes_actions.dart`（rail-script-panel 新建）：`createConfigFromShotNotes` 把 `shot.typeConfig['character_ids']`（非空字符串列表）带进新配置节点的 typeConfig。
- 测试：`test/features/storyboard/util/script_character_match_test.dart`（新建）、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`（rail-script-panel 新建，加用例）。

## 不许碰的文件
- W13 同波：`widgets/selection_toolbar.dart`、`util/selection_toolbar_model.dart`、`util/node_menu_model.dart`、`widgets/canvas_view.dart`、`canvas_menu/canvas_menu_host.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`、`settings/**`（selection-toolbar）；`widgets/left_rail/outline_panel.dart`、`util/outline_model.dart`（outline-drag-reorder）；`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`util/canvas_tool_actions.dart`、`providers/canvas_nodes_controller.dart`、`providers/recent_presets_provider.dart`、job 仓储（create-menu-pick-recent）；`sequence/**`、`widgets/left_rail/left_rail_actions.dart`（sequence-locate-regenerate）。
- 同 lane 后序（script-panel-repair-actions）：`storyboard/providers/script_document_controller.dart`、`widgets/left_rail/script_panel.dart`（`script_repository.dart` / `postgres_script_repository.dart` 两片都不改）。
- `widgets/shot_config_inspector.dart`（W12 已把动作抽走，本片只改共享动作文件）、`providers/characters_controller.dart`（W15 归 script-characters-row）、`core/interfaces/character_repository.dart`（不改；W14 character-kind 也不改接口）、`create_node_menu.dart`、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W13）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- selection-toolbar：`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/util/selection_toolbar_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/selection_toolbar.dart`、`lib/features/canvas/widgets/stage/stage_overlays.dart`（可能）、`lib/features/settings/providers/selection_toolbar_pref_controller.dart`、`lib/features/settings/widgets/canvas_appearance_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/selection_toolbar_model_test.dart`、`test/features/canvas/widgets/selection_toolbar_test.dart`、`test/features/settings/canvas_appearance_section_test.dart`
- outline-drag-reorder：`lib/features/canvas/models/canvas_command.dart`（只追加一行）、`lib/features/canvas/models/commands/outline_reorder_command.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/left_rail/outline_panel.dart`、`test/features/canvas/models/outline_reorder_command_test.dart`、`test/features/canvas/util/outline_drop_plan_test.dart`、`test/features/canvas/widgets/left_rail/outline_drag_test.dart`
- script-panel-repair-actions：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`
- create-menu-pick-recent：`lib/core/di/recent_job_presets.dart`、`lib/core/interfaces/recent_job_preset_source.dart`、`lib/features/canvas/models/recent_preset.dart`、`lib/features/canvas/providers/recent_presets_provider.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/recent_presets.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/storage/repositories/postgres_recent_job_preset_source.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/providers/recent_presets_provider_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/recent_presets_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`、`test/storage/repositories/postgres_recent_job_preset_source_test.dart`
- sequence-locate-regenerate：`lib/features/canvas/widgets/left_rail/left_rail_actions.dart`、`lib/features/sequence/util/sequence_shot_actions.dart`、`lib/features/sequence/widgets/sequence_screen.dart`、`test/features/canvas/widgets/left_rail/focus_node_across_canvas_test.dart`、`test/features/sequence/util/sequence_shot_actions_test.dart`、`test/features/sequence/widgets/sequence_context_menu_test.dart`

## 具体改动
已有签名（核对过）：
```dart
// core/interfaces/character_repository.dart 约第 3 行
Future<String> create({required String projectId, String name = '', List<String> referenceImagePaths = const <String>[], String description = '', int sortOrder = 0});
// core/interfaces/unit_of_work.dart 约第 27 行：RepositoryScope.characters
// canvas/providers/characters_controller.dart 约第 19 行：charactersControllerProvider（AutoDispose family<List<Character>, projectId>）
// canvas/models/character.dart：Character { id, name, description, ... }（手写不可变，非 freezed）
// shell/providers/active_project.dart：activeProjectProvider → ProjectRef?
// generation/generation_controller.dart 约第 891 行：读 typeConfig['character_ids']（List<String>）
```
新增（`script_character_match.dart`，纯 Dart）：
```dart
/// 一个可匹配的名字。[id] 为 null = 候选（还没建）；同一 [id] 可出现多次（W15 的「关联」别名）。
@immutable class CharacterNameRef { const CharacterNameRef({this.id, required this.name}); final String? id; final String name; }
@immutable class CharacterHit { final CharacterNameRef ref; final int firstOffset; }
/// [text] 里出现的角色，按首次出现位置排序；同一 id（或同一候选名）只出一次。
List<CharacterHit> matchCharacterNames(String text, List<CharacterNameRef> refs);
/// 规范化名字：trim、折叠内部空白；空串返回 null（不参与匹配）。
String? normalizeCharacterName(String raw);
```
控制器：
```dart
@immutable class ScriptCharacterPlan { final String projectId; final List<CharacterNameRef> existing; final List<String> createNames; }
Future<ScriptImportResult> importDrafts(List<ShotDraft> drafts, {Offset origin = Offset.zero, bool writeEstimatedDuration = true, ScriptCharacterPlan? characters});
```
事务内顺序（插在 W11 的 `ensureDocument` 之前）：先 `scope.characters.create(projectId, name, sortOrder: 现有最大 + 1 起递增)` 建全部 `createNames` 得到 name→id → 每个 draft 用 `matchCharacterNames(draft.notes, existing + 新建的)` 得到 id 列表 → `scope.nodes.create(... typeConfig: {...W11 的 shot_notes / duration_ms, kCharacterIdsKey: ids})`（ids 为空不写键；键名用 `providers/character_usage.dart` 的现有常量 `kCharacterIdsKey`）。W11 其余步骤（段落、接链尾边、撤销登记）原样。成功后 `invalidate(charactersControllerProvider(projectId))` 与 `invalidate(galleryGraphProvider(projectId))`（角色引用计数的数据源，同 characters_section 约第 106 行的做法）。

对话框：状态 `List<({String name, bool checked})> _candidates`；「设为角色」按钮在原文输入框选区非空时可用；`_ctrl.selection` 取文字 → `normalizeCharacterName` → 已在已有角色 / 候选里则忽略。预览每行用同一个 `matchCharacterNames` 现算。

## 行为规则与边界情况
- R1 匹配是子串匹配：名字在段里出现即命中；拉丁字母不区分大小写，中文按原样。
- R2 长名优先：同一位置被更长的名字占用后，较短名字在该区间不再命中（「老人家」命中时「老人」不在那一处计数；别处单独出现的「老人」照样命中）。
- R3 名字经 `normalizeCharacterName`；空名字的角色（库里允许 `name = ''`）永不参与匹配。
- R4 结果顺序 = 首次出现位置；同一 id 多个别名都命中时只出一次（取最早的位置）。
- R5 `character_ids` 只写命中的；未命中任何角色的镜头不写该键（不写空数组）。
- R6 候选：只有勾着的进 `createNames`；未勾的不建、不挂、不持久化（候选的持久化是 W15 的事）。新建角色没有参考图、没有描述。
- R7 原子性：建角色、建镜头、建边、写段落同一事务；任一步失败整体回滚——库里既没有新角色也没有镜头（与 W11「失败零残留」同一条）。
- R8 没有活动项目：不显示「角色」行与「设为角色」，`characters` 传 null，导入行为与 W11 完全一致。
- R9 角色列表还没载入（AsyncLoading）：预览照常，角色 chip 晚到；载入失败：角色行显示一行错误说明，导入照样可用（只是不挂已有角色）。
- R10 摘要：`{shots} 镜 · 约 {duration} · {characters} 个角色（{created} 个新建）`；没有任何命中且没有勾着的候选时不写角色那一截。
- R11 「用本镜备注生成」：`createConfigFromShotNotes` 把镜头的 `character_ids` 原样复制进新配置节点（过滤非字符串项）；镜头没有该键则不写。检查器与剧本面板两个入口共用，都生效。
- R12 撤销：整次导入仍是 W11 定的那一步撤销；新建的角色不随撤销删除（角色是项目级资产，删除走角色库）——在回报里注明这一点让主 Agent 确认。
- R13 平台：无平台差异——选区读取用 `TextEditingController.selection`，mac / Windows 相同。

## 新文案键
| key | en | zh |
|---|---|---|
| scriptImportMarkCharacter | Set as character | 设为角色 |
| scriptImportCandidateNew | New | 新建 |
| scriptImportCandidateRemove | Remove candidate | 移除候选 |
| scriptImportSummaryCharacters | {count, plural, =1{1 character} other{{count} characters}} ({created} new) | {count} 个角色（{created} 个新建） |
| scriptImportCharactersLoadFailed | Couldn't load characters. Shots will be created without them. | 角色读取失败，镜头照常创建，不挂角色。 |
（摘要前半「N 镜 · 约 X」沿用 W11 的 `scriptImportPreviewSummary`；本片只追加角色那一截，拼接用「 · 」。「角色」行标签复用现有 `inspectorCharactersLabel`（「Characters / 角色」），不新建。）

## 测试
先写、先红。
- `script_character_match_test.dart`：
  - `matches existing name as substring` — 「山脊上，阿青回头望」命中阿青。
  - `latin names are case-insensitive`。
  - `longer name wins at the same span` — 「老人家」与「老人」：「老人家坐下」只命中老人家；「老人家与老人」两个都命中。
  - `empty names never match`。
  - `hits ordered by first occurrence and deduped by id` — 别名（同 id 两个名字）只出一次。
  - `candidate refs have null id and still match`。
- `script_import_controller_test.dart`：
  - `writes character_ids for matched existing characters`。
  - `creates checked candidates in the same transaction and links them`。
  - `no character_ids key when nothing matches`。
  - `failure after creating characters rolls back everything`（fake UoW 第 2 个节点 create 抛 InkError，断言角色表为空）。
  - `null plan behaves exactly as before`。
- `script_import_dialog_test.dart`：
  - `existing character shows as solid chip on matching row`。
  - `set as character adds a dashed candidate from the selection`；`unchecked candidate is not counted as new`。
  - `summary shows characters and created counts`。
  - `no active project hides characters row`。
- `canvas_shot_notes_actions_test.dart`：`copies character_ids from shot to new config`；`no character_ids key when shot has none`。

## 变异点
- M1 `script_character_match.dart` 去掉长名优先（按列表序逐个子串查）→ `longer name wins at the same span` 红。
- M2 去掉大小写折叠 → `latin names are case-insensitive` 红。
- M3 去掉按 id 去重 → `hits ordered by first occurrence and deduped by id` 红。
- M4 控制器把建角色移到 `uow.run` 之外 → `failure after creating characters rolls back everything` 红。
- M5 命中为空时写 `'character_ids': []` → `no character_ids key when nothing matches` 红。
- M6 对话框把未勾候选也放进 `createNames` → `unchecked candidate is not counted as new` 红。
- M7 `createConfigFromShotNotes` 不复制 `character_ids` → `copies character_ids from shot to new config` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/storyboard test/features/canvas/util/canvas_shot_notes_actions_test.dart test/features/canvas/widgets/shot_config_inspector_test.dart`；M1–M7 逐条变异。
- 截图：`ScriptImportDialog`，ProviderScope 覆写 `activeProjectProvider`（一个项目）、`charactersControllerProvider` 返回 [阿青]；输入稿例三段。截 ① 稿例全貌（阿青实心、老人虚线新建、摘要「3 镜 · 约 9 秒 · 2 个角色（1 个新建）」）② 候选取消勾选后 ③ 无活动项目时。

## 风险与不确定
- `importDrafts` 按 W11 派工单是 `(drafts, {origin, writeEstimatedDuration}) → ScriptImportResult`；本片只追加命名参数 `characters`，不改已有参数与返回值。W11 的撤销步只软删镜头与边（段落保留），新建角色不在它的撤销范围里——与 R12 一致。
- W14 character-kind 在本片之后合入，且不改 `CharacterRepository.create` 的签名（kind 走列默认值 'character'），本片新建角色不用传 kind。
- 导入撤销是否连带删新角色（R12）plan 没写；按「不删」实现，需主 Agent 确认。
- 设计缺口：候选的取消勾选 / 移除交互、与已有角色同名的划选、无项目时的表现，稿上都没画，按上文处理。
