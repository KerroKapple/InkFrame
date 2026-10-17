# character-usage-links · 角色「被引用」可点：跳到引用它的节点
- 波次：W15 / lane：D / 基底：叠在 character-kind 之后（W14 已合入 origin/main）
- 依赖切片：character-kind（W14，同一对 widget 文件）、sequence-locate-regenerate（W13：`left_rail/left_rail_actions.dart` 的 `focusNodeAcrossCanvas`）、menu-split（W0：`canvas_menu/canvas_menu_popover.dart` 的 `CanvasMenuPopover`）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（W14 character-kind 已合入）起新分支 `feat/character-usage-links`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。
5. 注册表每片只追加一行——本片不碰注册表。
6. CanvasNode 新派生属性写成 extension；不给任何仓储加方法（数据只来自现有 `galleryGraphProvider` 投影）。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. **不改 `left_rail_actions.dart`**：跨画布定位一律调用 W13 的 `focusNodeAcrossCanvas`，不自己 openCanvas + 挂请求。

## 目标
- 角色编辑框「被引用」里的每个 chip 显示「画布名 · 节点名」，点一下：关掉编辑框，切到那张画布（别的画布先打开），单选该节点并移到视口中心。
- 编辑框里有没保存的改动时，先问「保存后前往 / 不保存 / 取消」。
- 角色库每行的「M 处引用」也能点：只有 1 处直接跳；多处弹一个小列表选去哪；0 处不可点。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` ›「角色：按类型分组 · 被引用可点」：
  - 行 meta「3 张参考图 · <u>4 处引用</u>」：引用数是 accent 色 + 下划线（可点态）；「没有引用」是普通 fg5 字。
  - 「被引用」小节（编辑框里，「点了去那个节点」）：chip 22 高、左右 8、圆角 3、10.5px；悬停 / 焦点态 `#6B5A38` 边 + `#2A2318` 底 + accent 字 + 尾随「↗」；常态 `#3F3F3F` 边、透明底、fg3 字。示例文字「画布 1 · 镜头 01」「画布 2 · 镜头 04」。
  - 原文要点：「「被引用」chip 可点：有未存改动先问，关框定位，跨画布先 openCanvas；行上「M 处引用」同样可点」。
- slices notes：「character_usage 返回的引用要带 canvasId 和画布名」「跨画布先 openCanvas，再挂 canvasFocusRequestProvider（center: true）」——后半句由 W13 `focusNodeAcrossCanvas` 实现。
- 设计缺口：「M 处引用」多于 1 处时点了去哪——画板没画。本片：1 处直接跳；≥2 处在下划线文字下方弹 `CanvasMenuPopover`，每项是同样的「画布名 · 节点名」。
- 设计缺口：「有未存改动先问」的对话框没画。本片：三个按钮「保存后前往」（主）/「不保存」/「取消」，文案见下表。

## 允许改的文件
- `lib/features/canvas/providers/character_usage.dart`：新增 `CharacterUsageRef` 与 `indexCharacterUsageRefs`（纯函数）+ `characterUsageRefsProvider`；现有 `indexCharacterUsages` / `characterUsageProvider` 签名不动（`image_config_inspector_characters_test` 等在用）。
- `lib/features/canvas/widgets/character_edit_dialog.dart`（W14 已改）：`_referencedBy` 的 chip 可点 + 悬停态；脏检查与确认框；`_save` 拆出不 pop 的 `_persist`。
- `lib/features/canvas/widgets/character_library_panel.dart`（W14 已改）：`CharacterLibraryRow` 的 meta 拆成「N 张参考图 · 」+ 可点的「M 处引用」；多处时开 `CanvasMenuPopover`。
- 测试：`test/features/canvas/providers/character_usage_test.dart`（追加）、`test/features/canvas/widgets/character_edit_dialog_test.dart`（追加）、`test/features/canvas/widgets/character_library_panel_test.dart`（追加）。

## 不许碰的文件
- `lib/features/canvas/widgets/left_rail/left_rail_actions.dart`（W13 定型，只调用）、`providers/canvas_focus_request.dart`、`shell/providers/shell_controller.dart`、`canvas_menu/canvas_menu_popover.dart`（只用）。
- W15 其他片：`widgets/node_inline_text_editor.dart`、`providers/inline_edit_node.dart`、`widgets/node_card.dart`、`widgets/node_card_slot.dart`、`widgets/text_node_inspector.dart`、`providers/inspector_submit_controller.dart`、`util/escape_ladder.dart`（text-inline-edit）；`providers/left_rail_state.dart`、`providers/inspector_expanded.dart`、`widgets/canvas_inspector_panel.dart`、`widgets/canvas_screen.dart`（collapse-all-panels）；`storyboard/**`、`left_rail/script_panel.dart`、**`providers/characters_controller.dart`**（script-characters-row）；`export/**`、`core/di/image_zip_export.dart`（delivery-history-tab → image-zip-export）。
- `gallery/**`（含 `gallery_graph_provider.dart`）、`create_node_menu.dart`（barrel）、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- text-inline-edit：`lib/features/canvas/providers/inline_edit_node.dart`、`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_card_slot.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`test/features/canvas/providers/inline_edit_node_test.dart`、`test/features/canvas/providers/inspector_submit_controller_test.dart`、`test/features/canvas/widgets/text_inline_edit_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`
- collapse-all-panels：`lib/features/canvas/providers/inspector_expanded.dart`、`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`、`test/features/canvas/providers/inspector_expanded_test.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`
- script-characters-row：`lib/core/interfaces/script_repository.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/storage/repositories/postgres_script_repository.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`
- delivery-history-tab：`lib/features/export/widgets/delivery_history_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/widgets/delivery_history_tab_test.dart`
- image-zip-export：`lib/core/di/image_zip_export.dart`、`lib/core/interfaces/image_zip_export_service.dart`、`lib/features/export/providers/image_zip_export_controller.dart`、`lib/features/export/util/export_order.dart`、`lib/features/export/util/image_zip_manifest.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/image_zip_export_dialog.dart`、`lib/services/archive_image_zip_export_service.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/util/export_order_test.dart`、`test/features/export/util/image_zip_manifest_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`、`test/services/archive_image_zip_export_service_test.dart`

## 具体改动
```dart
// providers/character_usage.dart
@immutable
class CharacterUsageRef {
  const CharacterUsageRef({required this.canvasId, required this.canvasName, required this.node});
  final String canvasId; final String canvasName; final CanvasNode node;
  // == / hashCode 按 canvasId + node.id
}
/// 与 indexCharacterUsages 同口径（只数 config、跨全项目画布、按节点 id 去重、画布顺序 → 画布内顺序），多带画布 id 与名字。
Map<String, List<CharacterUsageRef>> indexCharacterUsageRefs(GalleryGraph graph);
final characterUsageRefsProvider = FutureProvider.autoDispose.family<Map<String, List<CharacterUsageRef>>, String>(...);

// widgets/character_edit_dialog.dart（私有）
bool get _dirty;                         // 名称 / 描述（trim 后）/ 类型 与当前角色不同
Future<bool> _persist();                 // 原 _save 去掉 pop；全部写成功 ⇒ true
Future<void> _goTo(CharacterUsageRef ref); // _dirty ⇒ 先问；然后 focusNodeAcrossCanvas + 关框
enum _LeaveChoice { saveAndGo, discardAndGo, cancel }

// widgets/character_library_panel.dart（私有）
void _openUsages(BuildContext anchorContext, List<CharacterUsageRef> refs); // 1 ⇒ 直接跳；≥2 ⇒ CanvasMenuPopover
```
- 现有签名（照抄）：`Map<String, List<CanvasNode>> indexCharacterUsages(GalleryGraph graph)`（character_usage.dart 约第 34 行）、`final characterUsageProvider = FutureProvider.autoDispose.family<Map<String, List<CanvasNode>>, String>`（约第 50 行）、`class GalleryCanvasInfo { final String id; final String name; … }`（gallery_graph.dart 约第 11 行）、`List<CanvasNode> nodesOf(String canvasId)`（约第 71 行）、`String nodeRefName(BuildContext context, CanvasNode node)`（node_card.dart 约第 462 行）、`Future<void> _save()`（character_edit_dialog.dart，W14 后约第 460 行附近）、`Widget _referencedBy(InkColors c, InkTypography t, List<CanvasNode> nodes)`（约第 370 行，参数改成 `List<CharacterUsageRef>`）。
- 定位调用：`focusNodeAcrossCanvas(ref, canvasId: r.canvasId, nodeId: r.node.id)`（sequence-locate-regenerate 提供，签名以合入后为准；预期内部：目标画布不是当前画布 ⇒ `shellControllerProvider.openCanvas(canvasId)`，再 `canvasFocusRequestProvider.request(canvasId:, nodeId:, center: true)`）。
- 编辑框里先调用定位、再 `Navigator.of(context).pop()`，两步在同一同步段完成（pop 之后不再碰 ref）。
- `CharacterLibraryRow` 新增参数 `usages`（`List<CharacterUsageRef>`），保留 `usageCount` 取 `usages.length`；面板改 watch `characterUsageRefsProvider`。「M 处引用」用独立 `GestureDetector`（opaque）包住，点它不触发整行的「编辑」。

## 行为规则与边界情况
- R1 chip 文案 =「画布名 · nodeRefName(节点)」；顺序 = 画布顺序 → 画布内节点顺序；同节点只出一次。
- R2 点 chip，没未存改动：编辑框关闭，壳切到目标画布（跨画布时先打开），该节点单选并居中；当前画布就是目标时不重开画布。
- R3 有未存改动：弹确认框。「保存后前往」⇒ `_persist` 成功才前往（失败：错误卡、编辑框留着、不前往）；「不保存」⇒ 不写库直接前往；「取消」/ Esc ⇒ 什么都不做，编辑框留着、输入保留。
- R4 只改了参考图（即时落库的那类）不算未存改动。
- R5 行上「M 处引用」：M = 0 显示「未引用」且不可点；M = 1 点了直接前往；M ≥ 2 弹列表，选一项前往，Esc / 点外面关列表。点行的其余部分仍是「编辑」。
- R6 引用数据未就绪（provider loading）：按 0 显示（沿用现有「慢一拍按 0」），不可点；报错同样按 0。
- R7 目标节点在投影计算之后被删：定位请求落地时找不到节点 ⇒ 由 `_PendingFocusApplier` 丢弃请求，不报错（沿用现有行为）；画布被删 ⇒ 投影里本就没有它。
- R8 定位后左栏角色页面板保持原状（不因切画布而收起），选中由定位请求设置。
- R9 撤销：纯导航，不进画布撤销栈。
- R10 平台差异：无（点击 / Esc 两端一致；chip 悬停态在触控板与鼠标上同样由 MouseRegion 触发）。

## 新文案键
| key | en | zh |
|---|---|---|
| characterUsageChip | {canvas} · {node} | {canvas} · {node} |
| characterUsageLink | {count, plural, =1{1 use} other{{count} uses}} | {count} 处引用 |
| characterUsageNone | unused | 未引用 |
| characterLeaveUnsavedTitle | Unsaved changes | 有未保存的改动 |
| characterLeaveUnsavedBody | Save changes to this character before going to the node? | 前往节点之前，要保存对这个角色的改动吗？ |
| characterLeaveSaveAndGo | Save and go | 保存后前往 |
| characterLeaveDiscardAndGo | Don't save | 不保存 |

（行 meta 前半段继续用现有 `characterRefAndUsageNone` / `characterRefAndUsage` 的同一组复数规则；若拆分后要单独的「N 张参考图 · 」，由主 Agent 决定是否新增 `characterRefCountPrefix`。）

## 测试
- `test/features/canvas/providers/character_usage_test.dart`
  - `'refs carry canvas id and name in canvas order'`；`'refs count only config nodes and dedupe by node id'`（与 indexCharacterUsages 同口径）。
- `test/features/canvas/widgets/character_edit_dialog_test.dart`（ProviderScope 覆写 charactersControllerProvider、characterUsageRefsProvider、shellControllerProvider 初态在画布 cv1）
  - `'chip shows canvas name and node name'`；
  - `'tapping a chip on another canvas opens it and requests centered focus, then closes dialog'`：断言 shell 状态 canvasId == 'cv2'、`canvasFocusRequestProvider` == `CanvasFocusRequest(canvasId: 'cv2', nodeId: 'n4', center: true)`、`find.byType(CharacterEditDialog)` 为空；
  - `'dirty dialog asks first and cancel keeps editing'`；`'discard goes without writing'`（FakeCharacterRepo 无 update 调用）；`'save and go writes then navigates'`；`'save failure stays and does not navigate'`（failUpdate = true）。
- `test/features/canvas/widgets/character_library_panel_test.dart`
  - `'single usage link navigates directly'`；`'multiple usages open a popover list'`；`'zero usages is not tappable'`；`'tapping the row outside the link still opens the editor'`。

## 变异点
- M1 `indexCharacterUsageRefs` 把画布名写成 canvasId → `'refs carry canvas id and name…'` 红。
- M2 去掉 config 过滤 → `'refs count only config nodes…'` 红。
- M3 `_goTo` 不判 `_dirty` → `'dirty dialog asks first…'` 红。
- M4 「不保存」分支也调 `_persist` → `'discard goes without writing'` 红。
- M5 `_persist` 失败仍前往 → `'save failure stays and does not navigate'` 红。
- M6 chip 点击后不 pop → `'tapping a chip … then closes dialog'` 红。
- M7 「M 处引用」去掉独立 GestureDetector（点击冒泡到行）→ `'single usage link navigates directly'` 红（会开编辑框）。
- M8 M ≥ 2 也直接跳第一个 → `'multiple usages open a popover list'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/providers test/features/canvas/widgets --exclude-tags golden`；逐条做 M1–M8。
- 截图场景：①`CharacterLibraryPanel`（三组，阿青 4 处引用带下划线、青铜灯未引用）；②同面板点阿青「4 处引用」后的弹出列表；③`CharacterEditDialog` 「被引用」两个 chip、第一个悬停态带 ↗；④脏状态下点 chip 弹出的确认框。数据：ProviderScope 覆写 `characterUsageRefsProvider` 与 `charactersControllerProvider`。

## 风险与不确定
- `focusNodeAcrossCanvas` 由 W13 sequence-locate-regenerate 提供，签名以合入后为准；本片的测试只断言可观察状态（壳的 canvasId + 定位请求），不依赖它的内部写法。
- `CanvasMenuPopover` 的构造参数由 W0 menu-split 定，以合入后为准。
- 编辑框是从左栏打开的对话框；若 W13 的函数内部做 `openCanvas` 时把左栏页切走，R8 不成立——需合入后核对。
- `galleryGraphProvider` 只在画廊脏刷新 / 挂角色后定点失效时重读，「被引用」可能慢一拍（现有口径，不在本片修）。
