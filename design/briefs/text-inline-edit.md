# text-inline-edit · 双击文本 / 便签卡就地编辑
- 波次：W15 / lane：A / 基底：origin/main（W0–W14 已合入，含 note-variant）
- 依赖切片：canvas-view-split（W0，`widgets/stage/node_card_slot.dart`）、esc-ladder（W0，`isEditingText()` 在 `shortcuts/canvas_tool_keys.dart`，单键 `CanvasKeyGate.notEditingText` 让位；Esc 阶梯的 `textField` 档）、undo-shortcuts-ui（W2，文本框有焦点时 Ctrl Z 归文本框）、undo-params（W5）、canvas-find-bar（W9）、note-variant（W14，便签自动适用）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W14 已合入）起新分支 `feat/text-inline-edit`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行（本片不需要追加）。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法，用现有 patchTypeConfig / update。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 正文只有一个键 `type_config.text`（`kTextNodeContentKey`，text_node_inspector.dart 第 26 行）。卡片与检查器**走同一条** `InspectorSubmitController(nodeId)` 防抖写链，不另起写库路径、不另起计时器。

## 目标
- 双击文本卡或便签卡，卡片正文原地变成可编辑的文本框，打字即存（与检查器正文框同一条防抖写链）。
- 点别处 / 按 Esc 结束编辑：立即落一笔并让画布重载；选中保持。
- 就地编辑期间，检查器的正文框变只读并实时跟着显示卡片里打的字。

## 设计依据
- `b2/project/ImportSearch.dc.html` ›「工具锁 · 便签」：
  - 「正文只有一个键 type_config.text：检查器正文框（fix/demo-inspectors 已上，F1 已修）是随时可用的那条路；双击文本 / 便签卡就地编辑只是快捷入口」。
  - 「两处走同一条防抖写入链（InspectorSubmitController：失败重试、退出前冲刷），失焦再写一笔并重载画布；就地编辑时检查器正文框只读跟随」。
  - 「单键只在画布持焦且不在文字里时生效」；「Esc 一次只收一层：菜单 > @ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中」。
  - 样稿：文本卡正文区内描边 `outline-offset -3` 的琥珀框 + 光标，卡下标「双击编辑中」。
- `b2/project/KeyMap.dc.html`：「双击文本/便签 · 就地编辑 · 画布 · 第二批」。
- revise-summary.txt「Text / 便签 editing」：F1 由检查器修，双击只是快捷入口；编辑态检查器只读跟随。
- 设计缺口：编辑态的正文框边框用什么色、卡片状态行要不要写「编辑中」没定（「双击编辑中」像是样稿注释）。本片：正文区内画 `colors.accent` 1px 内描边，不改状态行。
- 设计缺口：缩小态（缩放 < 0.6 卡片只画图标）双击怎么办没画。本片：缩小态不进入就地编辑（检查器路仍可用）。
- 设计缺口：Esc 在就地编辑里算哪一层没写进层序。本片：编辑框自己吃掉 Esc（结束编辑、选中保留），不登记 escape_ladder 新层。

## 允许改的文件
- `lib/features/canvas/providers/inline_edit_node.dart`（新建）：哪张卡在就地编辑 + 当前文本。
- `lib/features/canvas/widgets/node_inline_text_editor.dart`（新建）：卡内编辑框。
- `lib/features/canvas/widgets/node_card.dart`（W15 归本片）：`NodeCard` 加 `inlineEditor` 槽位；有它时替换正文区、关掉卡片拖动。
- `lib/features/canvas/widgets/stage/node_card_slot.dart`（canvas-view-split 新建于 `widgets/stage/` 下，类名 `NodeCardSlot`；W15 归本片）：原始指针双击识别、开始编辑、把编辑框塞给 NodeCard。
- `lib/features/canvas/widgets/text_node_inspector.dart`：只读跟随 + 失焦提交改走 `commitNow`。
- `lib/features/canvas/providers/inspector_submit_controller.dart`：加 `commitNow` 与 `latestValueOf`。
- 测试：`test/features/canvas/widgets/text_inline_edit_test.dart`（新建）、`test/features/canvas/providers/inline_edit_node_test.dart`（新建）、`test/features/canvas/providers/inspector_submit_controller_test.dart`（追加）、`test/features/canvas/widgets/text_node_inspector_test.dart`（追加）。

## 不许碰的文件
- W15 其他切片：`left_rail_state.dart`、`inspector_expanded.dart`、`canvas_inspector_panel.dart`、`canvas_screen.dart`、`shortcuts/collapse_panels_keys.dart`（collapse-all-panels）；`storyboard/*`、`left_rail/script_panel.dart`、`characters_controller.dart`（script-characters-row）；`character_edit_dialog.dart`、`character_library_panel.dart`、`character_usage.dart`（character-usage-links）；`export/*`、`core/di/image_zip_export.dart` 等（delivery-history-tab → image-zip-export）。
- `canvas_shortcuts.dart` 与 `shortcuts/*`（单键靠现有 `isEditingText()` 自动让位，不改）、`util/escape_ladder.dart`（本片不登记新层）、`stage_pointer_layer.dart`、`canvas_view.dart`、`canvas_node.dart`、`canvas_node_note.dart`（只调用）、`create_node_menu.dart`。
- ARB、`lib/l10n/generated/`、`docs/CLAUDE.md`。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- collapse-all-panels：`lib/features/app_actions/app_action_ids.dart`（追加一行）、`lib/features/canvas/providers/inspector_expanded.dart`、`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`、`test/features/canvas/providers/inspector_expanded_test.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`
- script-characters-row：`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`
- character-usage-links：`lib/features/canvas/providers/character_usage.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`test/features/canvas/providers/character_usage_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`
- delivery-history-tab：`lib/features/export/widgets/delivery_history_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/widgets/delivery_history_tab_test.dart`
- image-zip-export：`lib/features/export/re_export.dart`（追加一行）、`lib/core/di/image_zip_export.dart`、`lib/core/interfaces/image_zip_export_service.dart`、`lib/features/export/providers/image_zip_export_controller.dart`、`lib/features/export/util/export_order.dart`、`lib/features/export/util/image_zip_manifest.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/image_zip_export_dialog.dart`、`lib/services/archive_image_zip_export_service.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/util/export_order_test.dart`、`test/features/export/util/image_zip_manifest_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`、`test/services/archive_image_zip_export_service_test.dart`

## 具体改动
inline_edit_node.dart：
```dart
@immutable class InlineEditSession { const InlineEditSession({required this.nodeId, required this.text}); final String nodeId; final String text; }
final inlineEditNodeProvider = AutoDisposeNotifierProviderFamily<InlineEditNodeController, InlineEditSession?, String>(InlineEditNodeController.new, name: 'inlineEditNodeProvider');   // family 参数 = canvasId
class InlineEditNodeController extends AutoDisposeFamilyNotifier<InlineEditSession?, String> {
  InlineEditSession? build(String canvasId);   // null
  void begin(String nodeId, String initialText);   // 已有别的会话 ⇒ 直接换成新的（旧编辑框失焦时已自行提交）
  void update(String nodeId, String text);         // 只更新同一 nodeId 的会话
  void end(String nodeId);                         // 只结束同一 nodeId 的会话
}
bool canInlineEdit(CanvasNode node);   // role == config && type == text（便签是 text，自动包含）
```
inspector_submit_controller.dart（现有 `saveConfig` 约第 280 行、`saveDebounced` 约第 461 行、`debounceDuration` 第 198 行 = 500ms）：
```dart
Object? latestValueOf(String key);                       // 最近一次交给 saveDebounced / saveConfig / commitNow 的该键值；没有 ⇒ null
Future<void> commitNow(Map<String, Object?> patch);      // 从 _pendingDebounced 摘掉这些键（摘空则取消计时器并释放保活），再 saveConfig(patch)；不抛
```
- `latestValueOf` 用一个 `Map<String, Object?> _latest` 在三个入口里记账；控制器 autoDispose 后自然清空（那时写链已落完）。
- `commitNow` 让「失焦再写一笔」不再与随后发射的同值防抖重复写一次。
node_inline_text_editor.dart：
```dart
class NodeInlineTextEditor extends ConsumerStatefulWidget {
  const NodeInlineTextEditor({super.key, required this.node, required this.initialText, required this.style});
  static const Key fieldKey = ValueKey<String>('canvas.inlineTextEditor');
}
```
- 自持 `TextEditingController(text: initialText)` 与 `FocusNode`，`autofocus: true`，光标放到末尾；`TextField` 用 `InputDecoration.collapsed`、多行（`maxLines: null`）、外层可滚动；样式由调用方传（文本卡同 `_ConfigText` 正文：`typo.body`、`fg2`、行高 1.55；便签同便签正文）。
- initState 里取好 `InspectorSubmitController` notifier、`InlineEditNodeController` notifier、`canvasId`（dispose 后 ref 不可用）。
- onChanged：`inline.update(id, v)` + `submit.saveDebounced({kTextNodeContentKey: v})`。
- 失焦：`await submit.commitNow({kTextNodeContentKey: text})` → `ref.invalidate(canvasNodesControllerProvider(canvasId))` → `inline.end(id)`。
- Esc：编辑框外包 `CallbackShortcuts`（`SingleActivator(LogicalKeyboardKey.escape)`）⇒ `focusNode.unfocus()` 并吃掉事件，失焦路径负责提交；画布的 Esc（清空选中）不会触发。
- dispose：先摘焦点监听；会话若仍是本节点 ⇒ `inline.end(id)`（不再写库——挂起防抖由控制器自己保活写完）。
node_card.dart：`NodeCard` 新增 `final Widget? inlineEditor;`。非 null 时：正文区（文本卡的图区 / 便签卡的整卡正文）换成它，外加 `colors.accent` 1px 内描边；`GestureDetector` 的 `onPan*` 置 null（文本选择拖动不拖卡）；鼠标光标 `SystemMouseCursors.text`。
node_card_slot.dart：
- 原始指针双击识别（不用 `GestureDetector.onDoubleTap`，原因同 W0 拆到 `widgets/stage/stage_pointer_layer.dart` 的 `BlankPointerDetector` 头注：双击识别器进竞技场会推迟单击）：私有 `_CardDoubleClickDetector`，`Listener.onPointerDown`，主键、同设备、第二下距第一下按下 ≤ `kDoubleTapTimeout` 且位移 ≤ `kDoubleTapSlop`、按下时无 Shift / Ctrl / ⌘ 才算。
- 命中后：`canInlineEdit(node)` 且非缩小态（`canvasCompactCardsProvider`）且不在连线模式 / 拖线 / 平移（`linkModeControllerProvider`、`canvasWireDragProvider`、`canvasPanActiveProvider`）⇒ 单选该卡、`inline.begin(node.id, initialText)`；initialText = `submit.latestValueOf('text') as String? ?? node.textContent ?? ''`。
- 本卡在会话里 ⇒ 给 NodeCard 传 `NodeInlineTextEditor(key: ValueKey(node.id), node:, initialText: session.text, style: …)`。
text_node_inspector.dart：
- `ref.listen(inlineEditNodeProvider(canvasId).select((s) => s?.nodeId == node.id ? s!.text : null), …)`：非 null ⇒ `_content.text = text`（保持光标在末尾），输入框 `enabled: false`，下方一行提示 `inspectorTextInlineEditingHint`；转 null ⇒ 恢复可编辑。
- `_commitAndRefresh`（约第 79 行）里的 `saveConfig` 换成 `commitNow`，其余不变。

## 行为规则与边界情况
- R1：双击文本卡 / 便签卡（不带修饰键）⇒ 进入就地编辑，光标在末尾，卡被单选；单击行为与现状完全一样（单击不被推迟）。
- R2：图像 / 视频 / 镜头配置卡、产物卡双击不进入编辑（保持现状）。
- R3：缩小态、连线模式、拖线中、平移工具 / 按住空格时双击不进入编辑。
- R4：打字 ⇒ 每次经 `saveDebounced` 合并写库（500ms）；检查器正文框同步显示同一文本且不可编辑。
- R5：失焦（点舞台别处 / 点检查器 / Tab 移走）⇒ 立即 `commitNow` 落一笔、画布节点表重载、会话结束；卡片正文显示新文本。
- R6：Esc ⇒ 结束编辑（同 R5），**选中保留**，不触发画布清空选中。
- R7：编辑中按 I / G / T / N / V / Delete / Backspace / Ctrl A 等画布键 ⇒ 归文本框（`isEditingText()` 让位）；Delete 不删卡。
- R8：编辑中 Ctrl Z / ⌘Z ⇒ 文本框内撤销（undo-shortcuts-ui 规则）；结束编辑后画布 Ctrl Z 的行为按 undo-params 对 type_config 写入的口径，本片不新增撤销命令。
- R9：写库失败 ⇒ 与检查器同一套「未保存 · 重试」（同一控制器）；编辑框里的文字不丢。
- R10：编辑期间该画布节点表被重载（job 完成、别处 invalidate）⇒ 编辑框 State 按 `ValueKey(node.id)` 保留，正在打的字不被旧值覆盖。
- R11：编辑期间卡被删除 / 切画布 / 关画布 ⇒ 编辑框卸载、会话结束；挂起的防抖由控制器保活写完，退出时由 pending-write 注册表冲刷。
- R12：检查器正文框里还有没发射的防抖时双击卡片 ⇒ 编辑框初值取 `latestValueOf('text')`，不会退回库里旧值。
- R13：同一时刻只有一个会话；在 A 卡编辑时双击 B 卡 ⇒ A 先失焦提交，B 开始编辑。
- R14：画布查找（canvas-find-bar）打开时双击：查找条持焦让出，进入编辑；查找结果按重载后的正文刷新。
- R15：平台差异：修饰键判定 mac 用 ⌘、Windows 用 Ctrl（与 `_handleNodeTap` 现有判定同一组：Shift / Ctrl / Meta 任一按下即不算）；双击时长取 Flutter 常量，两平台一致。

## 新文案键
| key | en | zh |
|---|---|---|
| inspectorTextInlineEditingHint | Editing on canvas — changes appear here | 正在画布上编辑，这里只读跟随 |

## 测试
先写、先红。
- `test/features/canvas/providers/inline_edit_node_test.dart`（新建）：
  - `'begin replaces an existing session'`；`'update and end ignore other node ids'`；`'canInlineEdit accepts text and note config nodes only'`（image 配置、text 产物 ⇒ false；便签 ⇒ true）。
- `test/features/canvas/providers/inspector_submit_controller_test.dart`（追加）：
  - `'commitNow drops pending debounced keys and writes once'`：saveDebounced('a') → commitNow({'text':'b'}) → 等过 500ms，仓储 patch 调用只有 1 次且值为 'b'。
  - `'latestValueOf returns the last value handed to the write chain'`。
- `test/features/canvas/widgets/text_inline_edit_test.dart`（新建；`test/_harness/fake_repositories.dart` 的 InMemoryNodeRepository + `test_app.dart`，挂整个舞台）：
  - `'double click on a text card opens the inline editor'`：两次 tap 间隔 < kDoubleTapTimeout ⇒ 找到 `NodeInlineTextEditor.fieldKey`。
  - `'single click on a text card is not delayed'`：一次 tap 后立即（pump 0）卡已选中。
  - `'double click on an image config card does not open the editor'`。
  - `'double click on a sticky note opens the inline editor'`。
  - `'typing writes type_config.text through the debounce chain'`：输入后 499ms 仓储未变，500ms 后为新值。
  - `'focus loss commits immediately and reloads the canvas'`：点舞台空白 ⇒ 不等 500ms 仓储已是新值，卡片正文显示新值。
  - `'escape ends editing and keeps the selection'`：Esc 后编辑框消失，选中集仍含该卡。
  - `'canvas single keys and delete yield to the inline editor'`：编辑中按 I、Backspace ⇒ 节点数不变，文字变化。
  - `'inspector follows inline text read-only'`：同时挂检查器，卡里打字 ⇒ `TextNodeInspector.contentFieldKey` 显示同文本且 enabled == false；结束后恢复可编辑。
  - `'editor keeps typed text when the node list reloads'`：编辑中 invalidate 节点控制器 ⇒ 编辑框文本不变。
- `test/features/canvas/widgets/text_node_inspector_test.dart`（追加）：`'blur commit uses commitNow and writes once'`。

## 变异点
- M1：node_card_slot 改用 `GestureDetector.onDoubleTap` → `'single click on a text card is not delayed'` 变红。
- M2：`canInlineEdit` 去掉 `type == text` → `'double click on an image config card does not open the editor'`、`'canInlineEdit accepts…'` 变红。
- M3：编辑框 onChanged 不再调 `saveDebounced` → `'typing writes type_config.text through the debounce chain'` 变红。
- M4：失焦路径去掉 `commitNow` / invalidate → `'focus loss commits immediately and reloads the canvas'` 变红。
- M5：编辑框不吃 Esc（交给画布）→ `'escape ends editing and keeps the selection'` 变红。
- M6：检查器去掉只读跟随 → `'inspector follows inline text read-only'` 变红。
- M7：`commitNow` 不摘 `_pendingDebounced` 的键 → `'commitNow drops pending debounced keys and writes once'` 变红。
- M8：编辑框去掉 `ValueKey(node.id)`（或在 didUpdateWidget 里按 node 重置文本）→ `'editor keeps typed text when the node list reloads'` 变红。
- M9：`InlineEditNodeController.end` 不比对 nodeId → `'update and end ignore other node ids'` 变红。

## 验收
- `flutter analyze lib test`。
- `flutter test --exclude-tags golden test/features/canvas/widgets/text_inline_edit_test.dart test/features/canvas/providers/inline_edit_node_test.dart test/features/canvas/providers/inspector_submit_controller_test.dart test/features/canvas/providers/inspector_auto_save_test.dart test/features/canvas/widgets/text_node_inspector_test.dart`，再跑 `test/features/canvas/` 全目录。
- 变异 M1–M9 逐条。
- 截图：`CanvasScreen` + ProviderScope 覆写 InMemory 仓储（一张文本卡连到图像配置、一张琥珀便签），截：①双击文本卡后的编辑态（内描边 + 光标）；②同时选中时检查器正文框只读跟随 + 提示行；③便签编辑态；④结束编辑后卡片正文已更新。

## 风险与不确定
- W0 拆分后 `node_card_slot.dart` 里卡片单击 / 拖动的接法以合入后为准；若 group-drag / snapping / find-bar 已在 slot 上包了指针层，双击识别要放在最内层，避免吞事件。
- esc-ladder 的 `isEditingText` 分支会让 Esc 只失焦；本片编辑框自己吃 Esc，两者结果一致，但若 W0 的实现在 Esc 进文本框前就拦截，需改为依赖那条分支（不改 escape_ladder，回报说明）。
- undo-params 是否把 type_config.text 的写入记成撤销步、以及撤销前「先冲掉防抖」与 `commitNow` 的先后，以 W5 合入后为准；需要时由主 Agent 在 rebase 时核对 `commitNow` 是否也该被撤销栈的冲刷入口调用。
- W16 note-heading-style 会给便签加标题样式；本片编辑框样式由调用方传入，W16 只需换传入的样式。
- 设计缺口：编辑态描边色、缩小态双击、Esc 层序归属（见设计依据）。
