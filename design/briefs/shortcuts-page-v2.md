# shortcuts-page-v2 · 设置「快捷键」页分组（单键 / Esc 阶梯 / 组合键 / 指针 / 弹层内部，每行带范围）

- 波次：W17；lane：E；基底：origin/main（W0–W16 已合入后的 main）
- 依赖切片：硬依赖 esc-ladder（W0：快捷键注册表 `canvas_shortcut_registry.dart` + `escape_ladder.dart` 层序表，`shortcut_catalog` 已改为从注册表取键与文案）。esc-ladder 之后 catalog 的现状（本单一切以它为底）：`ShortcutAction` 枚举与 `shortcutActionOf` **已删**；`ShortcutRow { final String id; final ShortcutGroup group; final String Function(AppLocalizations l) label; final List<String> keys; }`，其中 `ShortcutGroup` 是 `widgets/shortcuts/canvas_key_binding.dart` 的 `{ app, tools, edit, view, generate, panels }`；`buildShortcutRows({required bool isMac, List<CanvasKeyBinding> registry = kCanvasKeyRegistry})`；shortcuts_section 的 `actionLabel` switch 已删、改用 `row.label(l)`。Esc 层是 `util/escape_ladder.dart` 的 `enum EscapeRungId { menu, mentionPopup, findBar, textField, wireDrag, marquee, linkMode, toolLock, panTool, selection }`（同波 cm-knife-cut 在 `marquee` 后追加 `edgeCut`），层的登记在运行时（`canvasEscapeLadderProvider`），静态拿不到「有没有 handler」。软相关、执行时都已在 main：app-action-table（W1）、marquee-select（W3）、win-menubar（W4）、group-drag（W5）、snapping（W6）、lone-alt-menubar（W7）、canvas-find-bar（W9）、f6-notification-region（W11）、prompt-bar-mention-ui（W12）、note-variant（W14）、text-inline-edit（W15）——它们登记的键 / 手势 / 弹层要出现在本页。
- 阻塞决定：无（KeyMap 的 Q1–Q6 都不影响本片：待定键在这里什么都不做，谁拍板谁登记）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 设置 › 快捷键页从一张平铺表变成五段：单键 · Esc 阶梯 · 组合键 · 指针 · 弹层内部，段头带一句适用条件。
- 每行多一列「范围」（画布 / 应用 / 弹层 / 序列）。仍然只列真正注册过 / main 上真有的键位与手势，按当前平台只显示一套。

## 设计依据（KeyMap 板「快捷键总表与冲突规则」）
- 状态图例「已上线 / 第二批 / 待定 Qn」**不上屏**：本页只列已注册的；待定行（P、Shift D、C、镜头）不出现。
- 范围图例：画布 = 画布持焦、不在文字里；应用 = 任何标签，文字里也生效；弹层 = 只在那个弹层里；序列 = 序列标签。
- 单键段头「画布持焦、不在文字里」；行：V 选择工具 · H 平移工具开/关 · 按住 Space 临时平移 · I G T 新建图像配置/视频配置/文本 · F 新建泳道（开对话框）· L 连线开/退 · Tab 新建…菜单 · Del/Backspace 删除选中 · Esc 剥一层（见阶梯）· Shift 1 适应全部 · Shift 2 适应选中，以及 W1–W16 登记的 N / M（M 若 canvas-minimap 已合）/ F6 等。
- Esc 阶梯段「按一次剥一层，从上往下找」：1 菜单（新建 / 右键；子菜单先关）· 2 @ 补全弹层（收起，字留着）· 3 查找条（关掉，选中留在当前）· 4 文字输入框（失焦，焦点回画布）· 5 进行中的手势（拖线 · 框选）· 6 工具回到选择（工具锁 · 平移 · 连线）· 7 清空选中（节点和连线）。阶梯下注：「不在阶梯上：对话框 · ⌘K · 设置 · 任务弹层 · 铃铛盖着时，Esc 归它们」。
- 组合键段「⌘ / Ctrl 同时注册，清单按平台只显示一套」：mac 显示 ⌘ 变体，Windows 显示 Ctrl 变体；重做每平台一个主键（Ctrl Y / ⇧⌘Z）。
- 指针段「修饰键各管一件」：点卡单选；Shift/Ctrl 点卡（mac ⇧/⌘）切换选中；点可播视频产物 = 选中并开播放框；左键拖空白 = 框选；Shift 拖框加选；Ctrl（⌘）拖框反选；右键拖、中键拖 = 平移；右键点 = 松开时开右键菜单；滚轮 = 以指针为中心缩放；双指/捏合 = 平移/缩放；双击空白 = 新建…菜单；双击泳道标题 = 折叠/展开；双击文本/便签 = 就地编辑；端口拖到空白 = 新建菜单并建好连线；端口拖到卡上 = 连线；拖卡 = 移动，跨带够深才换道；拖卡 + Shift = 锁轴；拖卡 + Ctrl（⌘）= 原样放下；拖素材/文件进来 = 导入或挂到节点；Ctrl（⌘）+ 滚轮 = 时间轴缩放（序列）。mac 只写 ⇧ / ⌘ 点。
- 弹层内部段「作用域隔开，和画布键不冲突」：新建/右键菜单（↑↓ 移 · Enter 选 · → 开子菜单 · ← / Esc 关子菜单 · 打字即搜索）；⌘K 命令面板（↑↓ · Enter 打开 · Ctrl Enter / ⌘↵ 在画布中定位 · Esc 关）；批量对比（←→ 切格 · Enter 设为当前 · Esc 关）；画廊网格（↑↓←→ 移锚点 · Space 预览）；查找条（Enter 下一个 · Shift Enter 上一个 · Esc 关）；@ 补全（↑↓ · Enter / Tab 插入 · Esc 收起 · 退格整块删）；F6 通知区（↑↓ 切卡 · Enter 主按钮 · Tab 卡内按钮 · Del 关卡 · Esc 回原处）；菜单栏（仅 Windows：←→ 切菜单 · ↑↓ · Enter · Esc 退出）。
- 设计缺口：板是两平台并排的总表，没画设置页里的样子（段头字号、范围列宽、阶梯怎么排）。本片按现有 API 密钥页表形：段头 `t.bodyStrong` fg1 + 段注 `t.meta` fg5；表三列「动作 | 范围 | 快捷键」；阶梯段是带序号的两列表（层名 | 作用）。板上「单独 Alt」「文字让位」两块本页不单列（单独 Alt 若 lone-alt-menubar 已收进清单，则作为组合键段一行，范围应用，仅 Windows）。

## 允许改的文件
- `lib/features/settings/util/shortcut_catalog.dart`：`ShortcutRow` 追加 `scope` / `section` 两个字段（`group` 已被 esc-ladder 占用，不动）；新增 `ShortcutScope`、`ShortcutSection`、`shortcutSectionOf`、`EscLadderLayer`、`buildEscLadderRows`；`_keyLabels` 加 ↑ ↓ ← → 四个方向键展示名（给弹层段用），并预先加 `LogicalKeyboardKey.keyM.keyId: 'M'`（同波 canvas-minimap 的 M 键只往注册表追加一行、不碰本文件，键名由本片先备好；若 main 上已有则跳过）。现有 `buildShortcutRows` / `canvasShortcutLabel` / `formatShortcutActivator` 的签名与输出不变。
- `lib/features/settings/util/pointer_gesture_catalog.dart`（新建）：指针手势常量表。
- `lib/features/settings/util/overlay_key_catalog.dart`（新建）：弹层内部键表常量。
- `lib/features/settings/widgets/shortcuts_section.dart`：改成五段渲染 + 范围列；行名继续用 esc-ladder 的 `row.label(l)`，新增 `scopeLabel` / `escLayerLabel` / `pointerLabel` / `overlayLabel` 映射（全部穷尽 switch）。
- `test/features/settings/shortcut_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`（现有路径，不在 util/ 下）。
- `test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/overlay_key_catalog_test.dart`（新建）。

## 不许碰的文件
- 同波 rail-templates-page：`left_rail_state.dart`、`left_rail/canvas_left_rail.dart`、`left_rail/left_rail_panel.dart`、`left_rail/templates_panel.dart`、`lib/features/templates/widgets/template_thumbnail_painter.dart`、`util/create_menu_model.dart`、`widgets/create_node_menu.dart` 及 `canvas_menu/` 下新建菜单条目（新建菜单链 W17 归它）、`canvas_toolbar.dart`、`lib/features/studio/open_canvas.dart`。
- 同波 canvas-minimap：`canvas_minimap.dart`、`util/minimap_geometry.dart`、`providers/minimap_visible.dart`、`canvas_zoom_bar.dart`、`canvas_screen.dart`（canvas_screen 链 W17 归它）、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`（app_preferences 链 W17 归它）。
- 同波 cm-knife-cut：stage_pointer_layer（W17 归它）/ `canvas_view.dart`、`providers/edge_cut_controller.dart`、`util/edge_cut_hit.dart`、`edge_cut_painter.dart`、`canvas_cut_actions.dart`。
- 同波 script-reimport-diff：`lib/features/storyboard/**`、`left_rail/script_panel.dart`、`left_rail/script_model.dart`、script 仓储。
- `canvas_shortcuts.dart` / `canvas_shortcut_registry.dart` / `escape_ladder.dart`：本片只读，不登记新键。
- 弹层源文件 `command_palette_dialog.dart`、`batch_compare_overlay.dart`、`gallery_grid.dart`、`theme/components/ink_menu_panel.dart`、查找条 / @ 弹层 / 通知区 / 菜单栏：本片不改（键表写成设置侧常量，见风险）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W17 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - rail-templates-page：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/util/template_ui_actions.dart`、`lib/features/templates/widgets/template_thumbnail_painter.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/widgets/template_thumbnail_painter_test.dart`
  - script-reimport-diff：`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/providers/script_reimport_controller.dart`、`lib/features/storyboard/util/script_diff.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`lib/features/storyboard/widgets/script_reimport_preview.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/providers/script_reimport_controller_test.dart`、`test/features/storyboard/util/script_diff_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
  - canvas-minimap：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/minimap_visible.dart`、`lib/features/canvas/util/minimap_geometry.dart`、`lib/features/canvas/widgets/canvas_capsule_host.dart`、`lib/features/canvas/widgets/canvas_minimap.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/canvas_zoom_bar.dart`、`lib/features/canvas/widgets/shortcuts/minimap_keys.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/minimap_visible_test.dart`、`test/features/canvas/util/minimap_geometry_test.dart`、`test/features/canvas/widgets/canvas_minimap_test.dart`、`test/features/canvas/widgets/canvas_screen_layout_test.dart`、`test/features/canvas/widgets/canvas_zoom_bar_test.dart`、`test/services/file_preferences_service_test.dart`
  - cm-knife-cut：`lib/features/canvas/models/commands/cut_edges_command.dart`、`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/util/canvas_cut_actions.dart`、`lib/features/canvas/util/edge_cut_hit.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/widgets/edge_cut_painter.dart`、`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`test/features/canvas/models/commands/cut_edges_command_test.dart`、`test/features/canvas/providers/edge_cut_controller_test.dart`、`test/features/canvas/util/edge_cut_hit_test.dart`、`test/features/canvas/widgets/canvas_knife_cut_test.dart`

## 具体改动
```dart
// shortcut_catalog.dart
enum ShortcutScope { canvas, app, overlay, sequence }
enum ShortcutSection { singleKey, combination }   // 名字避开 esc-ladder 已有的 ShortcutGroup
/// 主键位（行里第一个键）不带 Ctrl / ⌘ / Alt ⇒ singleKey（Shift 允许：Shift 1 / Shift 2 归单键）；否则 combination。
ShortcutSection shortcutSectionOf(ShortcutActivator primary);
class ShortcutRow { final String id; final ShortcutGroup group; final String Function(AppLocalizations l) label; final List<String> keys; /* ↑ esc-ladder 原样 */ final ShortcutScope scope; final ShortcutSection section; }
// scope 按来源表给：画布注册表 → canvas；kCommandPaletteActivators 与其他应用级表（F6、单独 Alt、退出等，main 上 catalog 已收的）→ app；
// kOverlayDismissActivator → overlay；CanvasToolKeys.holdToPan → canvas + singleKey（手动收的行在 add 处显式给 group / scope）。
List<ShortcutRow> buildShortcutRows({required bool isMac, List<CanvasKeyBinding> registry = kCanvasKeyRegistry}); // 签名与行序不变（esc-ladder 定的：commandPalette、overlayDismiss，再按注册表顺序）
/// 设置页上的 7 层（板上的说法），由 EscapeRungId 归并：menu→menu、mentionPopup→mention、findBar→findBar、textField→textField、
/// wireDrag / marquee / edgeCut→gesture、linkMode / toolLock / panTool→tool、selection→selection。归并用对 EscapeRungId 的穷举 switch，新加档不归类就编译不过。
enum EscLadderLayer { menu, mention, findBar, textField, gesture, tool, selection }
EscLadderLayer escLadderLayerOf(EscapeRungId id);
@immutable class EscLadderRow { final int step; final EscLadderLayer layer; }
/// 按 EscapeRungId.values 顺序归并去重，序号从 1 起；7 层全列（登记是运行时的事，静态不判有无 handler）。
List<EscLadderRow> buildEscLadderRows();
```
（`EscapeRungId` 按 esc-ladder 派工单；main 上若多了别的档，只在 `escLadderLayerOf` 里归类。）
```dart
// pointer_gesture_catalog.dart（纯常量 + 纯函数，不 import Flutter widgets 以外的东西）
enum PointerInput { clickCard, clickPlayableVideo, dragBlank, dragMarquee, rightDrag, middleDrag, rightClick, wheel, trackpad,
  doubleClickBlank, doubleClickLaneTitle, doubleClickText, portDragToBlank, portDragToCard, dragCard, dropFiles }
enum PointerModifier { shift, primary /* Windows Ctrl / mac ⌘ */, alt }
enum PointerGestureAction { select, toggleSelection, selectAndPlay, marquee, addToSelection, invertSelection, pan, openContextMenu,
  zoomAtPointer, panZoom, openCreateMenu, toggleLaneCollapse, inlineEdit, createAndLink, link, moveCard, axisLock, dropAsIs,
  importOrAttach, timelineZoom, cutEdges }
@immutable class PointerGestureRow { final PointerInput input; final List<Set<PointerModifier>> modifierSets; final PointerGestureAction action; final ShortcutScope scope; }
const List<PointerGestureRow> kPointerGestureRows;   // 22 行，顺序 = 板上指针表顺序，末行是同波 cm-knife-cut 的「Alt 拖空白 = 切线」（dragBlank + {alt} → cutEdges，scope canvas）；不含「双击工具按钮 = 工具锁」（W19 tool-lock 追加）
/// 修饰键前缀：mac ⇧ / ⌘ / ⌥，其余 Shift+ / Ctrl+ / Alt+（与 formatShortcutActivator 同一套写法）；多组用「 / 」连。
String formatPointerModifiers(Set<PointerModifier> mods, {required bool isMac});
```
```dart
// overlay_key_catalog.dart
enum OverlaySurface { createMenu, commandPalette, batchCompare, galleryGrid, findBar, mentionPopup, notificationRegion, menuBar }
enum OverlayKeyVerb { move, choose, openSubmenu, closeSubmenu, typeToSearch, open, locate, close, switchCell, setCurrent, moveAnchor,
  preview, next, previous, insert, collapse, deleteToken, switchCard, primaryButton, cardButtons, dismissCard, backToOrigin, switchMenu, exitMenu }
@immutable class OverlayKeyHint { final List<SingleActivator> keys; /* 空 = 无键（打字即搜索） */ final OverlayKeyVerb verb; }
@immutable class OverlayKeyRow { final OverlaySurface surface; final List<OverlayKeyHint> hints; final bool windowsOnly; }
const List<OverlayKeyRow> kOverlayKeyRows;
List<OverlayKeyRow> overlayKeyRowsFor({required bool isMac});    // mac 去掉 windowsOnly（菜单栏）
/// 一条提示的键位串：各键走 formatShortcutActivator，同组用「 / 」连；⌘↵ 与 Ctrl+Enter 两个变体按平台各出其一。
String formatOverlayHintKeys(OverlayKeyHint hint, {required bool isMac});
```
`shortcuts_section.dart`：`ShortcutsSection` 构造不变（`isMacOverride`）。新增常量 `scopeColumnWidth = 64`。段结构：段头（标题 + 段注）→ 表头 → 行；段间距 `InkSpacing.lg`，段头到表头 `InkSpacing.sm`。范围列是纯文字 `t.micro` fg4，不画框。Esc 阶梯行：序号 `t.monoSmall` fg5 + 层名 `t.body` fg2 + 作用 `t.meta` fg4；阶梯表下一行段注（不在阶梯上…）。指针行键位列 = 修饰键前缀 + 输入名（ARB）。弹层行 = 弹层名 | 提示串（`键 动词 · 键 动词…`，键用 `t.mono` fg1、动词 `t.meta` fg3，用 `Text.rich` 拼，可换行，不截断）。全部颜色 / 字号 / 间距走 token，不写数字字面量（现有 27 / 29 行高保留）。

## 行为规则与边界情况
1. 段序固定：单键 → Esc 阶梯 → 组合键 → 指针 → 弹层内部；某段一行都没有就整段不画（含段头）。
2. 组内行序 = `buildShortcutRows` 的行序（注册表顺序）；一行只出现在一段（按它在本平台的第一个键位分段）。
3. 分组只看修饰键：无 Ctrl/⌘/Alt 的（含 Shift+数字、Del、Tab、Esc、F6）归单键；其余归组合键。
4. 范围只看来源表，不看键位；同一动作两个来源冲突时以画布注册表为准（不应出现，测试钉住）。
5. 仍只列注册过的：注册表新增一行（如 canvas-minimap 的 M）不改本文件就自动进单键段；键名不在 `_keyLabels` 白名单里时照旧让 `shortcut_catalog_test` 打红。
6. Esc 阶梯段固定 7 层，顺序跟 `EscapeRungId.values` 走（层表改序，本段跟着改序）；工具锁那一档的说明由 W19 tool-lock 让主 Agent 改 ARB 值。
7. mac：组合键显示 ⌘ 变体、指针 primary 写 ⌘、弹层段不出菜单栏行；Windows：Ctrl 变体，出菜单栏行。
8. 指针 / 弹层两张常量表是手写的：执行时**逐行对照 main 上的实现**（例如 `canvas_view` / stage_pointer_layer 里的中键平移、`command_palette_dialog.dart` 第 111–118 行的绑定、`batch_compare_overlay.dart` 第 135–145 行、`gallery_grid.dart` 第 75–87 行），main 上不存在的行不写。
9. 不改任何绑定、不新增任何键；页面只读。
10. 窄窗口（设置正文最窄约 680）：动作列 ellipsis，范围列与键位列定宽不折行；弹层提示串换行。

## 新文案键
| key | en | zh |
|---|---|---|
| settingsColumnScope | Scope | 范围 |
| settingsColumnGesture | Gesture | 手势 |
| settingsColumnPopup | Popup | 弹层 |
| settingsShortcutScopeCanvas / App / Overlay / Sequence | Canvas / App / Popup / Sequence | 画布 / 应用 / 弹层 / 序列 |
| settingsShortcutsGroupSingleKey · …Hint | Single keys · Canvas focused, not typing | 单键 · 画布持焦、不在文字里 |
| settingsShortcutsGroupEscLadder · …Hint | Esc ladder · Each press peels one layer, top first | Esc 阶梯 · 按一次剥一层，从上往下找 |
| settingsShortcutsGroupCombination · …Hint | Key combinations · Only this platform's set is shown | 组合键 · 清单按平台只显示一套 |
| settingsShortcutsGroupPointer · …Hint | Pointer · Each modifier does one thing | 指针 · 修饰键各管一件 |
| settingsShortcutsGroupOverlay · …Hint | Inside popups · Scoped to that popup, never clashes with canvas keys | 弹层内部 · 作用域隔开，和画布键不冲突 |
| settingsShortcutsEscOffLadder | Not on the ladder: while a dialog, the command palette, settings, the task popover or the bell is open, Esc belongs to it. | 不在阶梯上：对话框、命令面板、设置、任务弹层、铃铛开着时，Esc 归它们自己。 |
| settingsEscLayerMenu · …Desc | Menu · New / right-click; submenu closes first | 菜单 · 新建 / 右键；子菜单先关 |
| settingsEscLayerMention · …Desc | @ autocomplete · Collapses, text stays | @ 补全弹层 · 收起，字留着 |
| settingsEscLayerFindBar · …Desc | Find bar · Closes, selection stays on the current hit | 查找条 · 关掉，选中留在当前 |
| settingsEscLayerTextField · …Desc | Text field · Loses focus, back to the canvas | 文字输入框 · 失焦，焦点回画布 |
| settingsEscLayerGesture · …Desc | Gesture in progress · Wire drag · marquee | 进行中的手势 · 拖线 · 框选 |
| settingsEscLayerTool · …Desc | Back to select tool · Pan · link | 工具回到选择 · 平移 · 连线 |
| settingsEscLayerClearSelection · …Desc | Clear selection · Nodes and edges | 清空选中 · 节点和连线 |
| settingsPointerInput{ClickCard, ClickPlayableVideo, DragBlank, DragMarquee, RightDrag, MiddleDrag, RightClick, Wheel, Trackpad, DoubleClickBlank, DoubleClickLaneTitle, DoubleClickText, PortDragToBlank, PortDragToCard, DragCard, DropFiles} | Click card · Click playable video · Left-drag blank · Drag marquee · Right-drag · Middle-drag · Right-click · Wheel · Two-finger / pinch · Double-click blank · Double-click lane title · Double-click text / note · Drag port to blank · Drag port onto card · Drag card · Drag assets / files in | 点卡 · 点可播视频产物 · 左键拖空白 · 拖框 · 右键拖 · 中键拖 · 右键点 · 滚轮 · 双指 / 捏合 · 双击空白 · 双击泳道标题 · 双击文本 / 便签 · 端口拖到空白 · 端口拖到卡上 · 拖卡 · 拖素材 / 文件进来 |
| settingsPointerAction{Select, ToggleSelection, SelectAndPlay, Marquee, AddToSelection, InvertSelection, Pan, OpenContextMenu, ZoomAtPointer, PanZoom, OpenCreateMenu, ToggleLaneCollapse, InlineEdit, CreateAndLink, Link, MoveCard, AxisLock, DropAsIs, ImportOrAttach, TimelineZoom, CutEdges} | Select · Toggle selection · Select and play · Box select · Add to selection · Invert selection · Pan · Open context menu on release · Zoom around pointer · Pan / zoom · New… menu · Collapse / expand · Edit in place · New… menu, then link · Link · Move; changes lane only when dragged deep enough · Lock axis · Drop as is · Import or attach to node · Zoom timeline · Cut links | 单选 · 切换选中 · 选中并开播放框 · 框选 · 加选 · 反选 · 平移 · 松开时开右键菜单 · 以指针为中心缩放 · 平移 / 缩放 · 新建… 菜单 · 折叠 / 展开 · 就地编辑 · 新建菜单，建好连线 · 连线 · 移动；跨带够深才换道 · 锁轴 · 原样放下 · 导入或挂到节点 · 时间轴缩放 · 切线 |
| settingsOverlay{CreateMenu, CommandPalette, BatchCompare, GalleryGrid, FindBar, MentionPopup, NotificationRegion, MenuBar} | New / right-click menus · Command palette · Batch compare · Gallery grid · Find bar · @ autocomplete · Notification area (F6) · Menu bar | 新建 / 右键菜单 · 命令面板 · 批量对比 · 画廊网格 · 查找条 · @ 补全 · 通知区（F6）· 菜单栏 |
| settingsOverlayVerb{Move, Choose, OpenSubmenu, CloseSubmenu, TypeToSearch, Open, Locate, Close, SwitchCell, SetCurrent, MoveAnchor, Preview, Next, Previous, Insert, Collapse, DeleteToken, SwitchCard, PrimaryButton, CardButtons, DismissCard, BackToOrigin, SwitchMenu, ExitMenu} | move · choose · open submenu · close submenu · type to search · open · locate on canvas · close · switch cell · set as current · move anchor · preview · next · previous · insert · collapse · delete whole tag · switch card · main button · card buttons · dismiss card · back to where you were · switch menu · exit | 移动 · 选择 · 开子菜单 · 关子菜单 · 打字即搜索 · 打开 · 在画布中定位 · 关闭 · 切格 · 设为当前 · 移锚点 · 预览 · 下一个 · 上一个 · 插入 · 收起 · 整块删 · 切卡 · 主按钮 · 卡内按钮 · 关卡 · 回到原处 · 切菜单 · 退出 |

（带花括号 / 斜杠的行是同前缀的多键，逐个展开，en / zh 按「 · 」一一对应；「…Hint / …Desc」= 前一键名加该后缀。）

## 测试
- `test/features/settings/shortcut_catalog_test.dart`（现有用例全部保留）：
  - `shortcutSectionOf：无修饰与仅 Shift 归单键，Ctrl/⌘/Alt 归组合键`（V、Shift+1、Delete → singleKey；⌘A、Ctrl+K、Alt+A → combination）。
  - `每行的范围按来源表：画布表 → canvas，命令面板 → app，浮层关闭 → overlay，按住空格 → canvas`。
  - `同一行只落一段`：两个平台下每个 row.id 的 section 唯一。
  - `buildEscLadderRows 序号从 1 连续、7 层、层序 == EscapeRungId.values 归并后的顺序`；`escLadderLayerOf：wireDrag / marquee / edgeCut 都归 gesture`。
- `test/features/settings/pointer_gesture_catalog_test.dart`（新）：`行序与板一致且不重复`、`修饰键按平台出字：Windows「Ctrl+」、mac「⌘」`、`切换选中两组修饰键用「 / 」连`、`时间轴缩放范围是 sequence，其余是 canvas`、`含切线一行（dragBlank + alt → cutEdges，mac 出「⌥」）、不含工具锁行`。
- `test/features/settings/overlay_key_catalog_test.dart`（新）：`mac 不出菜单栏行，Windows 出`、`命令面板定位键：mac ⌘↵，Windows Ctrl+Enter`、`方向键出 ↑ ↓ ← →`、`新建菜单的打字即搜索没有键位`。
- `test/features/settings/shortcuts_section_test.dart`：
  - 现有两条用例保留（surfaceSize 视需要加高到 800×2400）。
  - `五个段头按序上屏`（en 文案，按 `tester.getTopLeft` 的 dy 递增断言顺序）。
  - `范围列：⌘K 那行是 App，⌘A 那行是 Canvas`。
  - `Esc 阶梯：1 Menu … 最后一层 Clear selection，下方有 off-ladder 段注`。
  - `指针段：Windows 出「Ctrl+Drag marquee」，mac 出「⌘Drag marquee」`。
  - `弹层段：mac 下找不到「Menu bar」，Windows 找得到`。

## 变异点
1. `shortcutSectionOf` 把 `shift` 也算进组合键 → `shortcutSectionOf：无修饰与仅 Shift 归单键…` 变红。
2. `buildShortcutRows` 里命令面板的 scope 改成 canvas → `每行的范围按来源表…` 与 section 测试 `范围列：⌘K 那行是 App…` 变红。
3. `buildEscLadderRows` 的序号改成从 0 起，或把层表倒序遍历 → `buildEscLadderRows 序号从 1 连续，层序 == escape_ladder 层表序` 变红（断言对照的是层表自身的顺序，不写死 7 行）。
4. `formatPointerModifiers` 在 mac 下也写「Ctrl+」→ `修饰键按平台出字…` 与 section `指针段…` 变红。
5. `overlayKeyRowsFor` 不过滤 `windowsOnly` → `mac 不出菜单栏行，Windows 出` 与 section `弹层段…` 变红。
6. section 里把段序改成组合键在单键前 → `五个段头按序上屏` 变红。
7. 删掉 `_keyLabels` 的方向键 → `方向键出 ↑ ↓ ← →` 变红。

## 验收
- 跑 `flutter analyze lib test`、`flutter test test/features/settings --exclude-tags golden`，逐条做变异。
- 截图：`pumpInkApp(tester, Scaffold(body: SingleChildScrollView(child: ShortcutsSection(isMacOverride: …))), surfaceSize: Size(880, 2400))`，真实注册表数据；截 ① mac 全页 ② Windows 全页 ③ Windows 下滚到指针 + 弹层两段。再在设置浮层里（`SettingsScreen` 打开到快捷键页，`settings_screen_test` 的宿主写法）截一张 1120×740 首屏。

## 风险与不确定
- **shortcut_catalog.dart 在 W17 有三片写着要改**（canvas-minimap 的 M、cm-knife-cut 的「Alt + 拖」、本片）。esc-ladder 之后加键只需往注册表追加一行，catalog 自动出行，所以本派工单认定 W17 的 catalog 归本片；需主 Agent 确认 minimap / knife-cut 的派工单不再改 catalog。主 Agent 交叉核对后定：knife-cut 的「Alt 拖空白 = 切线」一行由本片直接写进 `kPointerGestureRows`（同波 cm-knife-cut 不碰本文件；这一行只是静态说明，不依赖 knife-cut 的代码先合）；tool-lock（W19）的「双击工具按钮 = 工具锁」一行由 tool-lock 追加，并由主 Agent 把 `settingsEscLayerToolDesc` 的值改成「工具锁 · 平移 · 连线」。
- slices.json 原打算让四个弹层各导出自己的键表，本片改为设置侧常量表 `overlay_key_catalog`：新建菜单所在的 create_node_menu / canvas_menu 是 W17 rail-templates-page 的热点，四个弹层的按键又是 onKeyEvent 里内联判断、导不出表。代价：弹层改键时这里不会自动变红，靠行为规则 8 的人工对照。
- esc-ladder 的层表按派工单是 `EscapeRungId` 枚举 + 运行时登记，不暴露「有无 handler」，所以第 6 条直接列全部 7 层。
- F6 那一行：W11 f6-notification-region 的派工单仍按 esc-ladder 之前的 `ShortcutAction.notificationRegion` 写，落地后 F6 行的实际来源以 main 为准（应是 catalog 里手动收的 app 级行，scope = app）。
- `settingsShortcutCanvasEscape` 已由 esc-ladder（W0）改值为「逐层退出（菜单 · 输入框 · 工具 · 选中）」，本片不再改（主 Agent 跨批核对补充）。zoom-reset-100（W0）已把缩放复位改为「复位 100%」，本片不再动。
- 新增约 95 个 ARB 键（大多是指针与弹层动词），由主 Agent 统一加；键名按上表展开。
