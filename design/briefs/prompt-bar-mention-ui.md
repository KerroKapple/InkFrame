# prompt-bar-mention-ui · 提示词条里的 @角色补全

> **阻塞决定 IS-Q3（plan.md 第 5 节）：按建议 A 写——提示词里持久化 `@{角色 id}`，插入即挂载、删标签不卸载，`character_ids` 仍是唯一来源。** 如最终拍板改选，本单与 W11 mention-token-core 一起重写。

- 波次：W12 / lane：D / 基底：origin/main（前序波已合入，含 W11 mention-token-core；#301 fix/demo-promptbar-sample 已在 main）
- 依赖切片：mention-token-core（W11，`lib/core/text/character_mention.dart`）、esc-ladder（W0，`util/escape_ladder.dart`）
- 阻塞决定：**IS-Q3 = A**（插入即挂载，删标签不卸载；`character_ids` 仍是唯一来源；提示词里持久化 `@{角色 id}`）

## 执行约定
1. 在你自己的工作树里，从 origin/main（W11 已合入）起新分支 `feat/prompt-bar-mention-ui`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片一张都不碰。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法，用现有 patchTypeConfig / findById。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. **只做提示词条**：检查器在 main 上只读 `promptText`（不可编辑），提示词条是唯一能编辑提示词的地方；画板说「检查器的提示词框也有」，本片不做（slices notes）。

## 目标
- 在底部提示词条里敲 `@` 弹出角色候选：已挂载的排前、继续打字筛选；↑↓ 选，↵ / Tab 插入，Esc 收起。
- 插入后文字里出现一枚琥珀色角色标签（显示角色名），同时角色被挂到这个配置节点（检查器「角色」区立即打勾）。
- 退格把整枚标签一次删掉，但不卸载角色；角色被删后标签变灰，发出时由生成侧去掉。
- 候选末行「从图片新建角色…」：选图起名 → 新建角色 → 直接插入并挂载。

## 设计依据
- 画板 `b2/project/ImportSearch.dc.html` ›「提示词里 @角色」：
  - 弹层宽 200、padding 4、`#262626` 底、`#4A4A4A` 边、圆角 6、阴影 0 24 64；行高 30：20px 圆形缩略 + 名称（11px，命中字高亮 `#2A2318` 底 / accent 字）+ 次行「N 张参考图」（9px）+ 右侧「已挂载」胶囊（16 高、accent 描边）；分隔线后一行 26 高「从图片新建角色…」。
  - 原文要点：「输入 @ 弹出，打字筛选；↑↓ 选，↵ / Tab 插入，Esc 收起；已挂载的排前面」「文字里存记号 `@{角色 id}`，插入同时追加进 character_ids；退格整块删，不卸载」「发出时记号换成角色名，描述照旧按 character_ids 顺序注入」「角色被删：标签变灰，发出时去掉」。
  - 插入后的标签：18 高、圆角 9、`#2A2318` 底、`#6B5A38` 边、accent 字、左侧 12px 头像。
  - 键盘层序（同板「画布内查找」小节）：「Esc 一次只收一层：菜单 > @ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中」。
- 设计缺口：被删角色的名字取不到（`listByProject` 不返回软删行），画板画的是带名字的灰标签——本片显示灰标签「已删除的角色」。
- 设计缺口：标签实现为可编辑文本里的「样式化区间」，不是 WidgetSpan；头像与 9px 圆角画不出（TextStyle.background 只能画直角矩形）。见「风险与不确定」。
- 设计缺口：弹层贴在哪——画板把弹层画在条子上方偏右；本片锚在光标所在行的光标位置上方 4px，越出舞台右沿时右对齐。

## 允许改的文件
- `lib/features/canvas/widgets/canvas_prompt_bar.dart`：`_PromptBarBodyState._prompt` 换成 `MentionTextController`；挂 OverlayPortal 弹层；`onChanged` 写 `storageText`；字数改按「展开成名字后的文本」数；⌘↵ 提交用 `storageText`。
- `lib/features/canvas/widgets/mention_text_controller.dart`（新建）：TextEditingController 子类，名字文本 + 区间表 ⇄ `@{id}` 存储串；buildTextSpan 画标签；原子删除。
- `lib/features/canvas/widgets/mention_popover.dart`（新建）：候选弹层（OverlayPortal 内容）+ 键盘导航 + 「从图片新建角色…」。
- `lib/features/canvas/util/mention_candidates.dart`（新建）：纯函数，筛选 + 已挂载优先排序 + 命中区间。
- `lib/features/canvas/providers/inspector_submit_controller.dart`：新增 `insertMention`（提示词 + character_ids 一笔写）。
- `lib/features/canvas/util/escape_ladder.dart`（esc-ladder 新建，名字以合入后为准）：登记 @ 弹层一层（菜单之后、查找条之前）。
- `lib/features/canvas/widgets/characters_section.dart`：**偏离归属表**——加 `didUpdateWidget`，当 `targetNode.typeConfig['character_ids']` 变了就重读 `_attachedIds`（否则检查器里留着旧集合，下次点角色会把 @ 刚挂上的角色写没）。W12 无人占用。
- `lib/features/canvas/widgets/character_library_panel.dart`：**偏离归属表**——`createCharacterFromFile` 返回值由 `Future<void>` 改 `Future<String?>`（新角色 id；取消 / 失败 ⇒ null），调用方不变。W12 无人占用。
- 测试：`test/features/canvas/util/mention_candidates_test.dart`（新建）、`test/features/canvas/widgets/mention_text_controller_test.dart`（新建）、`test/features/canvas/widgets/prompt_bar_mention_test.dart`（新建）、`test/features/canvas/providers/inspector_submit_mention_test.dart`（新建）、`test/features/canvas/widgets/characters_section_mounted_guard_test.dart`（追加一条）。

## 不许碰的文件
- W12 其他片：`util/node_menu_model.dart`、`canvas_menu/multi_menu_entries.dart`、`canvas_menu/canvas_menu_host.dart`、`canvas_menu/menu_registry.dart`（cm-multi-select-menu / locate-in-gallery 各追加一行）；toast 一族（`core/interfaces/toast_service.dart`、`notifications/**`、`canvas_snackbars.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`）；`providers/left_rail_state.dart`、`left_rail/canvas_left_rail.dart`、`left_rail_panel.dart`、`left_rail/script_panel.dart`、`widgets/shot_config_inspector.dart`、`util/canvas_shot_notes_actions.dart`；`gallery/**`。
- `lib/core/text/character_mention.dart`（W11 已定格式，只调用）、`generation/generation_controller.dart`、`services/import/import_remapper.dart`。
- `create_node_menu.dart`（barrel）、`models/canvas_node.dart`、`image_config_inspector.dart` / `video_config_inspector.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W12）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- cm-multi-select-menu：`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/multi_menu_entries.dart`、`lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`、`test/features/canvas/util/node_menu_model_test.dart`、`test/features/canvas/widgets/canvas_multi_menu_test.dart`
- toast-category-mute：`lib/core/interfaces/toast_service.dart`、`lib/core/models/app_preferences.dart`、`lib/features/canvas/util/canvas_snackbars.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/notifications/providers/toast_center.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/features/notifications/widgets/notification_bell.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/_harness/fake_toast_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/canvas_snackbars_test.dart`、`test/features/notifications/providers/toast_center_test.dart`、`test/features/notifications/widgets/job_notification_listener_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
- rail-script-panel：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/canvas/widgets/shot_config_inspector.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`
- locate-in-gallery：`lib/features/canvas/widgets/canvas_menu/node_locate_gallery_entry.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/providers/gallery_selection.dart`、`lib/features/gallery/util/locate_in_gallery.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_grid.dart`、`test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`、`test/features/gallery/util/locate_in_gallery_test.dart`、`test/features/gallery/widgets/gallery_locate_test.dart`

## 具体改动
```dart
// util/mention_candidates.dart
@immutable class MentionCandidate { final Character character; final bool mounted; final List<(int,int)> nameHits; }
List<MentionCandidate> mentionCandidates({required List<Character> all, required Set<String> mountedIds, required String query});
// 规则：query 去首尾空白、不区分大小写，按名字包含匹配（空 query 全出）；已挂载在前，组内保持 all 的原序；nameHits 是名字里命中的区间。

// widgets/mention_text_controller.dart
class MentionTextController extends TextEditingController {
  MentionTextController.fromStorage(String storage, {required Map<String, String> namesById});
  String get storageText;                       // 区间 → `@{id}`，其余原样（格式化走 character_mention 的 emit 函数）
  Set<String> get mentionedIds;
  void insertMention({required String id, required String name, required TextRange replacing}); // 替换「@查询串」
  void refreshNames(Map<String, String> namesById); // 角色改名 / 删除后重画；删了的标灰
  ({int start, String query})? get activeMentionQuery; // 光标前最近的 '@' 到光标；中间有空白/换行或超 24 字 ⇒ null
}
// 区间表随编辑平移：value setter 里比对新旧文本的公共前后缀算出改动区；改动区与某个标签相交 ⇒ 整枚删掉；
// 光标 / 选区落在标签内部 ⇒ 吸到最近边界。composing 非空（输入法组字中）时不做原子删除。

// providers/inspector_submit_controller.dart
/// 插入 @ 标签：取消挂起的 prompt 防抖，在 _serialized 里读库里这一行的 character_ids（NodeRepository.findById），
/// 不在就追加 [characterId]，与 prompt 一起 patchTypeConfig 一笔写；成败照 _attemptWrite 记账。
Future<void> insertMention({required String prompt, required String characterId});
```
- 现有签名（照抄）：`void savePromptDebounced(String prompt)`（约第 478 行）、`Future<void> saveConfig(Map<String, Object?> patch)`（约第 280 行）、`Future<String> createFromImage({required String name, required String sourceAbsolutePath})`（characters_controller.dart 约第 50 行）、`Future<void> createCharacterFromFile(BuildContext context, WidgetRef ref, String projectId)`（character_library_panel.dart 约第 473 行）。
- `insertMention` 成功后：`ref.invalidate(canvasNodesControllerProvider(canvasId))`（让检查器 CharactersSection 拿到新 character_ids，写法同 text_node_inspector.dart 约第 85 行）+ `ref.invalidate(galleryGraphProvider(projectId))`（引用计数，写法同 characters_section.dart `_toggle`）。
- 弹层状态：`_PromptBarBodyState` 持 `OverlayPortalController` + 高亮下标；`activeMentionQuery != null` 且焦点在提示词框 ⇒ 开。候选数据：`charactersControllerProvider(projectId)`（node.projectId 为空 ⇒ 不开）。
- 键位（仅弹层开着时接管，`CallbackShortcuts` 包在 TextField 外，与现有 ⌘↵ 同层）：↑ / ↓ 移高亮（循环），↵ / Tab 插入高亮项（高亮在「从图片新建角色…」上 ⇒ 走新建），Esc 只收弹层、焦点留在提示词框。弹层关着时 ↵ 仍是换行、Tab 仍是焦点遍历。
- Esc 层：在 escape_ladder 登记 `mentionPopover` 层，active() = 弹层开着，dismiss() = 关弹层；序位在「菜单」之后、「查找条」之前。

## 行为规则与边界情况
- R1 敲 `@` 且光标前一个字符是行首 / 空白 / 标点 / 中日韩文字时开弹层；`a@b`（前面是 ASCII 字母数字，像邮箱）不开。
- R2 查询串过滤按名字不区分大小写包含；没有命中时只剩「从图片新建角色…」一行，不显示空列表文案。
- R3 已挂载（节点 character_ids 里有）的候选排在前面并带「已挂载」胶囊；组内顺序 = 角色库顺序。
- R4 插入：「@查询串」被替换成标签 + 一个空格；同一笔写里 prompt 与 character_ids 一起落库；已挂载的不重复追加。
- R5 写库失败：不回滚文字；自动保存状态显示「未保存 · 重试」（沿用 InspectorAutoSave 那一套），重试时两个键一起写。
- R6 退格 / Delete 碰到标签的任何一个字 ⇒ 整枚删；不卸载角色（Q3-A），character_ids 不变。
- R7 选中一段跨标签的文字删除 ⇒ 被碰到的标签整枚删。粘贴进来的 `@{…}` 字面量当普通文本，不变标签。
- R8 角色被删（不在 `charactersControllerProvider` 列表里）：标签灰色（fg5 字、surface5 底）显示「已删除的角色」；存储串保持 `@{id}` 不动，发出时由生成侧去掉（W11）。
- R9 角色改名：标签文字跟着变（refreshNames），存储串不变。
- R10 「从图片新建角色…」：调 `createCharacterFromFile`，返回 id ⇒ 插入并挂载；用户取消 / 失败 ⇒ 弹层关、文字不动（失败卡沿用该函数里已有的错误提示）。
- R11 Esc 优先级：新建菜单开着时 Esc 先关菜单；菜单没开、弹层开 ⇒ 关弹层，焦点留在提示词框、画布选中不变；再按 Esc ⇒ 走 esc-ladder 的「提示词条只失焦」。
- R12 失焦（点舞台、切节点）⇒ 弹层关；切到另一个节点（body 以 node.id 为 key 重建）⇒ 新控制器按新节点存储串重建标签。
- R13 提交（⌘↵ / 按钮）用 `storageText`；字数显示按「标签展开成名字」的文本数。
- R14 撤销栈：本片不登记撤销步（提示词编辑本来就不进画布撤销栈，Ctrl Z 在文本框里归文本框——W2 undo-shortcuts-ui）。
- R15 平台差异：无。↵ / Tab / Esc / ↑↓ 两个平台同键；⌘↵ / Ctrl↵ 已在现有绑定里分别处理。

## 新文案键
| key | en | zh |
|---|---|---|
| promptBarMentionMounted | Attached | 已挂载 |
| promptBarMentionRefCount | {count, plural, =0{No reference images} =1{1 reference image} other{{count} reference images}} | {count} 张参考图 |
| promptBarMentionCreateFromImage | New character from image… | 从图片新建角色… |
| promptBarMentionDeleted | Deleted character | 已删除的角色 |

## 测试
- `test/features/canvas/util/mention_candidates_test.dart`
  - `'mounted characters come first, library order kept within groups'`：断言顺序。
  - `'query filters by name case-insensitively and reports hit ranges'`。
  - `'empty query returns all'`。
- `test/features/canvas/widgets/mention_text_controller_test.dart`
  - `'fromStorage renders tokens as names and storageText round-trips'`。
  - `'backspace inside a chip removes the whole chip'`：storageText 不再含该 `@{id}`。
  - `'caret placed inside a chip snaps to its boundary'`。
  - `'activeMentionQuery is null after whitespace or ascii-letter prefix'`（R1）。
  - `'deleted character renders with deleted label but keeps token'`（R8）。
- `test/features/canvas/providers/inspector_submit_mention_test.dart`
  - `'insertMention writes prompt and appended character_ids in one patch'`：fake NodeRepository 只收到一次 patchTypeConfig，含两个键。
  - `'insertMention reads current row, keeps attached ids and does not duplicate'`：库里已有 [c0, c1]，插 c1 ⇒ 写 [c0, c1]；插 c2 ⇒ 写 [c0, c1, c2]。
  - `'insertMention cancels the pending prompt debounce'`：500ms 后不再有第二笔 prompt 写。
- `test/features/canvas/widgets/prompt_bar_mention_test.dart`（ProviderScope 覆写 charactersControllerProvider / nodeRepositoryProvider / 选中一个 image config 节点）
  - `'typing @ opens popover with mounted first'`；`'arrow keys and enter insert highlighted candidate'`；`'tab inserts too'`；
  - `'escape closes popover but keeps focus and selection'`（R11）；`'enter without popover inserts newline'`；
  - `'submit sends storage text with tokens'`：⌘↵ 后 submit 收到的 prompt 含 `@{id}`。
- `characters_section_mounted_guard_test.dart` 追加 `'reloads attached ids when node character_ids change'`。

## 变异点
- M1 把 `mention_candidates.dart` 的「mounted 优先」排序删掉 → `'mounted characters come first…'` 红。
- M2 把 `MentionTextController` 原子删除分支改成只删一个字符 → `'backspace inside a chip removes the whole chip'` 红。
- M3 `insertMention` 改成两次写（先 prompt 后 ids）→ `'…in one patch'` 红。
- M4 `insertMention` 不读库、直接写 `[characterId]` → `'insertMention reads current row, keeps attached ids…'` 红。
- M5 弹层 Esc 处理里去掉「保留焦点」→ `'escape closes popover but keeps focus and selection'` 红。
- M6 `CallbackShortcuts` 的 ↵ 绑定不判弹层是否开 → `'enter without popover inserts newline'` 红。
- M7 提交改回用 `_prompt.text` → `'submit sends storage text with tokens'` 红。
- M8 删掉 characters_section 的 didUpdateWidget → `'reloads attached ids when node character_ids change'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util test/features/canvas/widgets test/features/canvas/providers --exclude-tags golden`；逐条做 M1–M8。
- 截图场景：`CanvasPromptBar`，ProviderScope 覆写选中一个 image config 节点（character_ids = [c1]）、角色列表 [c1 渔夫(3 图), c2 老渔翁(1 图)]：①敲「拂晓，@渔」弹层开、渔夫带「已挂载」高亮；②插入后标签；③c1 被删后的灰标签；④查询无命中只剩「从图片新建角色…」。

## 风险与不确定
- mention-token-core 的函数名 / 签名（parse、expandToNames、stripToNames、emit）由 W11 提供，签名以合入后为准；本片只依赖「解析出 (区间, id)」与「id → `@{id}`」两件事。
- esc-ladder 的登记口形状（动态 register 还是枚举表）以 W0 合入后为准。
- 标签用「样式化文本区间」而不是 WidgetSpan：好处是复制出来是名字、光标 / 输入法不错位；代价是画不出头像和圆角——与画板有出入，需要主 Agent 认可。
- characters_section.dart、character_library_panel.dart 不在归属表里，是本片为数据一致性加的最小改动（W12 无人占用；W14 character-kind、W15 character-usage-links 会在其上叠加 character_library_panel.dart）。
- 检查器 CharactersSection 与提示词条同时开着时，若用户在 @ 写库落地前点了检查器里的角色，后者仍可能用旧集合覆盖——didUpdateWidget 缩小了窗口但不能完全消除（两处写不在同一条串行链上：CharactersSection 也走同一个 InspectorSubmitController 的 saveConfig，故实际串行，风险低）。
