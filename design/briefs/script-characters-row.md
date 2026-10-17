# script-characters-row · 剧本面板「剧中角色」：已有角色实心 chip，虚线候选可新建 / 关联 / 忽略，原文划选「设为角色」
- 波次：W15 / lane：C / 基底：origin/main（W0–W14 已合入）
- 依赖切片：script-panel-repair-actions（W13，`script_document_controller.dart`）、script-import-characters（W13，`script_character_match.dart`）、rail-script-panel（W12，`scriptDocumentProvider` / `ScriptDocumentView { document, paragraphs }`）、script-tables（W10，`script_documents.character_candidates` JSONB + 模型 `ScriptCharacterCandidate` / `ScriptCandidateState { candidate, ignored }` + `ScriptRepository.updateDocument`）、menu-split（W0，`CanvasMenuPopover` 带子菜单）、character-kind（W14：characters.kind 列默认 'character'，仓储接口不变，新建角色不用传 kind）
- 阻塞决定：RailScript R1 → 选 B（已有角色名匹配 + 原文划选「设为角色」，零 LLM）。

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W14 已合入）起新分支 `feat/script-characters-row`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表每片只追加一行——本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不写节点。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 匹配只用 `script_character_match.dart` 的 `matchCharacterNames`（W13 已建），**不另写一套**；本片在同一文件里追加计数函数与候选编解码，导入对话框与面板因此同一口径。

## 目标
- 剧本面板头部下面多一行「剧中角色」：项目里已有、并在原文里出现的角色画实心 chip，带出现在几段；用户标出来的候选画虚线 chip。
- 点虚线 chip 出菜单：新建（建成没有参考图的角色，chip 变实心）/ 关联 ›（把这个名字当成某个已有角色的别名）/ 忽略（不再显示）。
- 原文里划选一段文字，右键「设为角色」= 加一个候选；行尾「+」也能手输一个名字加候选。

## 设计依据
`b2/project/RailScript.dc.html`（文本版 SCRATCH/boards/RailScript.txt）「剧本 P1」：
- 稿面：面板头下「剧中角色」一行：「渔夫 2」「老人 1」「+」；第 03 段行内有一枚「老人」chip。
- 「角色：已有角色名匹配 = 实心；虚线候选可新建 / 关联 / 忽略」。
- R1 建议 B：「零 LLM，与拆分器同口径，结果可测」。
`b2/project/GapsPanels.dc.html`「剧本导入对话框」：「文本里选中一段 → 「设为角色」→ 虚线候选」「新建成没有参考图的角色」——面板与对话框同一套匹配。
script-tables notes：「在 script_documents 上顺手放一个 character_candidates JSONB（R1 B 的候选 / 忽略状态）」。
- 设计缺口：① chip 上数字的含义没写——本片 = 出现该角色的段数（稿例「渔夫 2」= 第 02、03 段）；② 「+」点了做什么没画——开 `InkNameDialog` 手输名字成候选；③ 点实心 chip 没画——打开角色编辑框；④ 段行内的 chip 稿上只画了一枚——本片画该镜头节点 `character_ids` 已挂的角色名（实心小 chip），不画匹配结果；⑤ 候选重名 / 与已有角色同名没画——见 R5。

## 允许改的文件
- `lib/features/storyboard/util/script_character_match.dart`（script-import-characters 新建）：追加计数函数、`CharacterNameRef` 的 key 扩展、候选模型与 JSON 编解码（纯函数）。
- `lib/features/storyboard/providers/script_document_controller.dart`（script-panel-repair-actions 新建）：候选读 provider + 加候选 / 忽略 / 关联 / 从候选新建四个动作。
- `lib/features/canvas/widgets/left_rail/script_panel.dart`（rail-script-panel 新建）：「剧中角色」行、段行内已挂角色 chip、原文 `SelectableText` + 「设为角色」。
- 测试：`test/features/storyboard/util/script_character_match_test.dart`（W13 script-import-characters 新建）、`test/features/storyboard/providers/script_document_controller_test.dart`（W13 script-panel-repair-actions 新建）、`test/features/canvas/widgets/left_rail/script_panel_test.dart`（W12 rail-script-panel 新建）（都加用例）。
- 不改仓储：W10 script-tables 的 `ScriptRepository` 已有 `updateDocument(String id, Map<String, Object?> patch)`（`ScriptDocumentCol.characterCandidates` 走它），候选模型 `ScriptCharacterCandidate` 也已在 W10 的 `storyboard/models/script_document.dart` 里。

## 不许碰的文件
- W15 同波：text-inline-edit 的 `node_inline_text_editor.dart`、`inline_edit_node.dart`、`node_card.dart`、`node_card_slot.dart`、`text_node_inspector.dart`、`inspector_submit_controller.dart`、`escape_ladder.dart`；collapse-all-panels 的 `left_rail_state.dart`、`inspector_expanded.dart`、`canvas_inspector_panel.dart`、`canvas_screen.dart`、`shortcuts/**`、`app_action_catalog.dart`；character-usage-links 的 `character_edit_dialog.dart`、`character_library_panel.dart`、`character_usage.dart`；delivery-history-tab / image-zip-export 的 `export/**`、`core/di/image_zip_export.dart`。
- `providers/characters_controller.dart`：归属表把它给了本片，但「从候选新建」要与候选状态同一事务，改走 UoW（`scope.characters.create`）后 invalidate，不需要改控制器——本片不碰它。
- `script_import_dialog.dart`、`script_import_controller.dart`（对话框侧行为不变，只因共用函数自动一致）、`providers/script_document_provider.dart`、`create_node_menu.dart`、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- text-inline-edit：`lib/features/canvas/providers/inline_edit_node.dart`、`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/stage/node_card_slot.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`test/features/canvas/providers/inline_edit_node_test.dart`、`test/features/canvas/providers/inspector_submit_controller_test.dart`、`test/features/canvas/widgets/text_inline_edit_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`
- collapse-all-panels：`lib/features/app_actions/app_action_ids.dart`（追加一行）、`lib/features/canvas/providers/inspector_expanded.dart`、`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`、`test/features/canvas/providers/inspector_expanded_test.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`
- character-usage-links：`lib/features/canvas/providers/character_usage.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`test/features/canvas/providers/character_usage_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`
- delivery-history-tab：`lib/features/export/widgets/delivery_history_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/widgets/delivery_history_tab_test.dart`
- image-zip-export：`lib/features/export/re_export.dart`（追加一行）、`lib/core/di/image_zip_export.dart`、`lib/core/interfaces/image_zip_export_service.dart`、`lib/features/export/providers/image_zip_export_controller.dart`、`lib/features/export/util/export_order.dart`、`lib/features/export/util/image_zip_manifest.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/image_zip_export_dialog.dart`、`lib/services/archive_image_zip_export_service.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/util/export_order_test.dart`、`test/features/export/util/image_zip_manifest_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`、`test/services/archive_image_zip_export_service_test.dart`

## 具体改动
已有 / 前序签名：
```dart
// script_character_match.dart（script-import-characters 新建，以合入为准）
class CharacterNameRef { final String? id; final String name; }  class CharacterHit { final CharacterNameRef ref; final int firstOffset; }
List<CharacterHit> matchCharacterNames(String text, List<CharacterNameRef> refs);  String? normalizeCharacterName(String raw);
// core/interfaces/character_repository.dart 约第 3 行：create({required projectId, name, referenceImagePaths, description, sortOrder})（W14 character-kind 不改这个签名，kind 落列默认值 'character'）
// canvas/providers/characters_controller.dart 约第 19 行：charactersControllerProvider（family projectId → List<Character>）
// canvas/widgets/character_edit_dialog.dart 约第 58 行：Future<void> showCharacterEditDialog(BuildContext, {required String projectId, required String characterId})
// theme/components/ink_name_dialog.dart 约第 23 行：InkNameDialog({title, hint, confirmLabel, cancelLabel, ...})，经 showDialog<String> 取名
// shell/providers/active_project.dart：activeProjectProvider
// storyboard/models/script_document.dart（W10 script-tables）：
//   enum ScriptCandidateState { candidate, ignored }
//   @immutable class ScriptCharacterCandidate { name, state, characterId?; fromJson / toJson }   // 坏元素 fromRow 时丢弃，不抛
//   @immutable class ScriptDocument { id, canvasId, List<ScriptCharacterCandidate> characterCandidates; fromRow }
// core/interfaces/script_repository.dart（W10）：Future<int> updateDocument(String id, Map<String, Object?> patch)
// canvas/providers/script_document_provider.dart（W12）：scriptDocumentProvider(canvasId) → ScriptDocumentView { document, paragraphs }
```
**不新建候选模型 / 编解码**：直接用 W10 的 `ScriptCharacterCandidate`。本片的三态在 W10 两态上这样表达（不改 W10 枚举）：
- 待定（pending）= `state == candidate && characterId == null`；
- 已关联（linked）= `state == candidate && characterId != null`；
- 忽略（ignored）= `state == ignored`。

追加到 `script_character_match.dart`：
```dart
/// 匹配用的名字表：已有角色名 + 已关联候选（id = characterId 的别名）+ 待定候选（id = null）；ignored 不参与。
List<CharacterNameRef> scriptNameRefs({required List<({String id, String name})> characters, required List<ScriptCharacterCandidate> candidates});
/// 每个 ref.key 出现在几段（一段多次只算 1）。
Map<String, int> paragraphCountsByRef(List<String> paragraphs, List<CharacterNameRef> refs);
extension CharacterNameRefKey on CharacterNameRef { String get key; } // id ?? 'candidate:<规范化名>'
```
JSON 元素形状沿用 W10：`{"name": "渔夫", "state": "candidate" | "ignored", "character_id": "<uuid>" | null}`，列存数组；读写只经 `ScriptCharacterCandidate.fromJson / toJson`。

追加到 `script_document_controller.dart`：
```dart
/// 候选列表 = scriptDocumentProvider(canvasId) 里 `document.characterCandidates`（W12 的视图已经带着文档），不另读库。
final scriptCandidatesProvider = Provider.autoDispose.family<AsyncValue<List<ScriptCharacterCandidate>>, String>(...); // canvasId
// 下面四个动作写完都 invalidate scriptDocumentProvider(canvasId)；写候选 = scope.scripts.updateDocument(documentId, {ScriptDocumentCol.characterCandidates: 列表.map(toJson)})（JSONB 参数写法按 W10 updateDocument 的约定）
Future<void> addCandidate({required String documentId, required String name});
Future<void> ignoreCandidate({required String documentId, required String name});
Future<void> linkCandidate({required String documentId, required String name, required String characterId});
Future<String> createCharacterFromCandidate({required String documentId, required String projectId, required String name}); // 一个事务：建角色 + 从候选表移除
```
`script_panel.dart`：头部下 `_CharactersRow`（label「剧中角色」+ chips + 「+」，测试锚点 `ScriptPanel.characterChipKey(ref.key)` / `ScriptPanel.addCandidateKey`）；原文改 `SelectableText`，`contextMenuBuilder` 在选区非空时加「设为角色」。

## 行为规则与边界情况
- R1 实心 chip = 已有角色中 `paragraphCountsByRef` ≥ 1 的那些，按角色库排序（sortOrder）；数字 = 段数（别名命中也算到该角色，同一段只算 1）。
- R2 虚线 chip = `pending` 候选，数字为 0 也画（用户刚标的名字可能还没出现在别段）；`ignored` 不画；`linked` 不单独画（并入它指向的实心 chip）。
- R3 段集合 = 面板显示的全部段（含「已删」段，不含软删的段落行）。
- R4 「设为角色」：选区文字经 `normalizeCharacterName`；空 ⇒ 不动作。
- R5 去重：名字（规范化后）已是某个已有角色名 ⇒ 不加候选，只弹 info「已是角色」；已是 pending ⇒ 不重复；已是 ignored ⇒ 改回 pending；已是 linked ⇒ 不动。
- R6 新建：同一事务里 `scope.characters.create(projectId, name, sortOrder: 现有最大 + 1)` + 把该候选从数组里删掉 ⇒ 之后它作为已有角色实心显示。失败整体回滚、候选仍在、error 卡。成功后 invalidate `charactersControllerProvider(projectId)` 与 `scriptCandidatesProvider(documentId)`。
- R7 关联：子菜单列项目内全部已有角色（按 sortOrder）；选中 ⇒ 候选变 `linked` + `character_id`。指向的角色被删除（不在列表里）⇒ 该 linked 候选按 pending 处理显示。
- R8 忽略：候选变 `ignored`，chip 消失；不提供「取消忽略」入口，除非再次「设为角色」（R5）。
- R9 「+」：`InkNameDialog` 取名 ⇒ 走 R4 / R5 同一路径。
- R10 点实心 chip ⇒ `showCharacterEditDialog(projectId, characterId)`。
- R11 段行内 chip：该段节点 `type_config.character_ids` 里仍存在的角色名，最多 3 枚，余下「+N」；节点已删的段不画。
- R12 没有活动项目：整行不画（角色是项目级），「设为角色」也不出现。
- R13 导入对话框一致性：对话框与面板对同一段文字、同一角色表的命中结果相同（同一个 `matchCharacterNames`）——用一条跨用例测试钉住。
- R14 撤销：候选操作不进画布撤销栈（不是画布对象）；新建角色可在角色库删除。
- R15 平台：选区右键菜单在 macOS（含 ctrl+单击）与 Windows 走同一个 `contextMenuBuilder`；无其他平台差异。

## 新文案键
| key | en | zh |
|---|---|---|
| scriptPanelCharactersLabel | Characters in script | 剧中角色 |
| scriptPanelAddCandidate | Add character name | 添加角色名 |
| scriptPanelAddCandidateHint | Name as it appears in the script | 按剧本里的写法 |
| scriptPanelCandidateCreate | Create character | 新建 |
| scriptPanelCandidateLink | Link to | 关联 |
| scriptPanelCandidateIgnore | Ignore | 忽略 |
| scriptPanelAlreadyCharacter | "{name}" is already a character | 「{name}」已是角色 |
| scriptPanelCandidateCreateFailed | Couldn't create the character. | 新建角色失败 |
| scriptPanelMoreCharacters | +{count} | +{count} |
（「设为角色」复用 W13 script-import-characters 的 `scriptImportMarkCharacter`，面板与对话框同一个词，不新建 `scriptPanelMarkCharacter`。）

## 测试
先写、先红。
- `script_character_match_test.dart`：
  - `paragraph counts count each paragraph once`（稿例：渔夫 2、老人 1）。
  - `linked candidate counts toward its character`。
  - `ignored candidates are excluded from refs`。
  - `three display states map onto W10 two-state model` —— candidate+无 id ⇒ 待定、candidate+有 id ⇒ 已关联、ignored ⇒ 忽略；写回后 `toJson` 的 state 只出现 `candidate` / `ignored`。
  - `panel and import dialog agree on hits`：同一文本 + 角色表，`matchCharacterNames` 结果与 `scriptNameRefs` 组装后的面板命中集一致。
- `script_document_controller_test.dart`：
  - `add candidate ignores names that are already characters`；`re-marking an ignored name makes it pending`。
  - `create from candidate is one transaction`（fake UoW 在写候选时抛错 ⇒ 角色表为空）。
  - `link sets state and character id`；`ignore hides candidate`。
- `script_panel_test.dart`：
  - `characters row shows solid chips with paragraph counts`；`pending candidate is dashed and opens menu with three items`。
  - `selecting text offers set-as-character`；`plus opens name dialog and adds candidate`。
  - `row chips show mounted character_ids`；`no active project hides characters row`。

## 变异点
- M1 `paragraphCountsByRef` 改成数出现次数 → `paragraph counts count each paragraph once` 红。
- M2 `scriptNameRefs` 不把 linked 候选作为别名 → `linked candidate counts toward its character` 红。
- M3 `scriptNameRefs` 放进 ignored → `ignored candidates are excluded from refs` 红。
- M4 `addCandidate` 去掉「已是角色」判据 → `add candidate ignores names that are already characters` 红。
- M5 `createCharacterFromCandidate` 拆成两次事务 → `create from candidate is one transaction` 红。
- M6 面板用自写 `contains` 判命中而非 `matchCharacterNames` → `panel and import dialog agree on hits` 红（用「老人家」长名用例区分）。
- M7 行内 chip 改画匹配结果 → `row chips show mounted character_ids` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/storyboard test/features/canvas/widgets/left_rail`；M1–M7 逐条变异。
- 截图：`ScriptPanel`，ProviderScope 覆写 `activeProjectProvider`、`charactersControllerProvider`（渔夫、老人）、`scriptDocumentProvider`（稿例 4 段）、`scriptCandidatesProvider`（一个 pending「白鹭」）；截 ① 「剧中角色：渔夫 2 · 老人 1 · 白鹭（虚线）· +」② 虚线 chip 菜单开着（关联子菜单展开）③ 原文划选后的右键菜单。

## 风险与不确定
- `character_candidates` 的形状按 W10 script-tables 派工单（`[{name, state: candidate|ignored, character_id?}]`，默认 `'[]'`，CHECK 为数组）；本片不新增 state 字面量（「已关联」= candidate + character_id），合入后若 W10 形状不同，以 W10 为准并回报。
- `ScriptRepository` 是否已有改文档字段的方法未知（见「允许改的文件」条件项）。
- 归属表把 `characters_controller.dart` 划给本片，但本片按事务原子性改走 UoW，不改它——回报里说明（是范围收窄，不是扩大）。
- `SelectableText` 接管了点击与右键：点原文仍要定位、选区为空时右键仍要出 W12 的段菜单——实现时在 `onTap` 与 `contextMenuBuilder` 里分流，需要截图核对两种右键。
- 段行内 chip 的语义（已挂角色 vs 匹配结果）是对稿的解读（设计缺口 ④），需设计确认。
