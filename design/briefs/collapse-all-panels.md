# collapse-all-panels · Ctrl Shift \ / ⌘⇧\ 一起收起左面板和检查器
- 波次：W15 / lane：B / 基底：origin/main（W0–W14 已合入，含 panel-resize 改过的画布外壳）
- 依赖切片：panel-resize（W14，canvas_screen 的 LayoutBuilder + resolvePanelLayout + 两侧热区）、esc-ladder（W0，快捷键注册表）、app-action-table（W1，⌘K 动作表）
- 阻塞决定：无

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/collapse-all-panels`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行：本片在 canvas_shortcut_registry 与 app_action_catalog 各追加一行。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不涉及。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：新键 `includeRepeats: false`（注册表有守卫测试）；Ctrl \ / ⌘\ 的现有行为一个字都不改。

## 目标
在画布页按 Ctrl Shift \（macOS ⌘⇧\），左面板和右侧检查器一起收起，只留 43px 导航条，舞台占满；再按一次，两边恢复成收起前各自的开合。
⌘K 里也能找到「收起全部面板 / 展开面板」。Ctrl \ 仍只开合左面板。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` 小节「面板调宽 · 收起全部面板」（b2_gaps_panels.js 约第 98–120 行）：
  - 原文：「Ctrl Shift \ / ⌘⇧\：左面板 + 检查器一起收，43 导航条留着；再按恢复收起前各自的开合。检查器要新增 inspectorExpanded（同 leftRailProvider 不 autoDispose）；Ctrl \ 仍只管左面板」。
  - 示意图右图：导航条 8px 条 + 满宽舞台，无左面板、无检查器，下注「Ctrl Shift \ 收起全部」。
- 设计缺口：①检查器收起后**没有**任何可见的单独展开入口（画板只给了快捷键）——本片只提供快捷键与 ⌘K 动作，不加按钮；②选中节点时检查器是否自动弹出——不弹（与「恢复收起前各自的开合」一致）；③开合有没有动画——没有（与现有 Ctrl \ 一致，瞬时）。

## 允许改的文件
- `lib/features/canvas/providers/left_rail_state.dart`：`LeftRailController`（约第 46 行）追加 `void setExpanded(bool expanded)`（只动开合、页不变；同值不通知靠现有 `updateShouldNotify`）。不改 `tapPage / open / toggle`。
- `lib/features/canvas/providers/inspector_expanded.dart`（新建）：`InspectorExpandedController` + `inspectorExpandedProvider`（**非 autoDispose**，与 `leftRailProvider` 同理由：用户的布局选择，切走画布再回来原样在），以及收起全部 / 恢复的唯一实现。
- `lib/features/canvas/widgets/canvas_inspector_panel.dart`：只改文件头注释（说明可被「收起全部」收起、由 canvas_screen 决定画不画）；不改 build。
- `lib/features/canvas/widgets/canvas_screen.dart`：`ref.watch(inspectorExpandedProvider)`；为 false 时不画检查器、不画检查器热区，并把 `inspectorShown: false` 传给 `resolvePanelLayout`（panel-resize 提供，签名以合入后为准）。
- `lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`（新建）：两个 activator + 注册表条目。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（esc-ladder 新建）：追加一行。
- `lib/features/app_actions/app_action_catalog.dart`（app-action-table 新建）：追加一行（一个动作，标题按 `inspectorExpandedProvider` 取「收起全部面板 / 展开面板」，回调同快捷键）；若动作 id 必须登记在 `app_action_ids.dart`，在那里也追加一行（回报说明）。
- 测试：`test/features/canvas/providers/left_rail_state_test.dart`（已存在，追加）、`test/features/canvas/providers/inspector_expanded_test.dart`（新建）、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`（新建）。

## 不许碰的文件
- W15 其他片：`widgets/node_card.dart`、`widgets/node_card_slot.dart`、`widgets/text_node_inspector.dart`、`providers/inspector_submit_controller.dart`、`providers/inline_edit_node.dart`、`util/escape_ladder.dart`（text-inline-edit）；`left_rail/script_panel.dart`、`storyboard/**`、`providers/characters_controller.dart`（script-characters-row）；`widgets/character_edit_dialog.dart`、`widgets/character_library_panel.dart`、`providers/character_usage.dart`（character-usage-links）；`lib/features/export/**`、`core/interfaces/image_zip_export_service.dart`、`core/di/image_zip_export.dart`（delivery-history-tab → image-zip-export）。
- 同 lane 前序 panel-resize 的文件只读：`providers/panel_widths.dart`、`widgets/panel_resize_handle.dart`、`left_rail/left_rail_panel.dart`、`core/models/app_preferences.dart`。
- `widgets/canvas_shortcuts.dart` 里 Ctrl \ 的绑定（`toggleLeftRailMeta / toggleLeftRailControl`，约第 168–177 行）与 `_toggleLeftRail`（约第 673 行）——不改；`widgets/left_rail/canvas_left_rail.dart`；`settings/util/shortcut_catalog.dart`（从注册表取，不用改）；`create_node_menu.dart`（barrel）、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- text-inline-edit：`lib/features/canvas/providers/inline_edit_node.dart`、`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_card_slot.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`test/features/canvas/providers/inline_edit_node_test.dart`、`test/features/canvas/providers/inspector_submit_controller_test.dart`、`test/features/canvas/widgets/text_inline_edit_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`
- script-characters-row：`lib/core/interfaces/script_repository.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/storage/repositories/postgres_script_repository.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`
- character-usage-links：`lib/features/canvas/providers/character_usage.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`test/features/canvas/providers/character_usage_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`
- delivery-history-tab：`lib/features/export/widgets/delivery_history_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/widgets/delivery_history_tab_test.dart`
- image-zip-export：`lib/core/di/image_zip_export.dart`、`lib/core/interfaces/image_zip_export_service.dart`、`lib/features/export/providers/image_zip_export_controller.dart`、`lib/features/export/util/export_order.dart`、`lib/features/export/util/image_zip_manifest.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/image_zip_export_dialog.dart`、`lib/services/archive_image_zip_export_service.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/util/export_order_test.dart`、`test/features/export/util/image_zip_manifest_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`、`test/services/archive_image_zip_export_service_test.dart`

## 具体改动
```dart
// providers/inspector_expanded.dart
final inspectorExpandedProvider = NotifierProvider<InspectorExpandedController, bool>(
    InspectorExpandedController.new, name: 'inspectorExpandedProvider');
class InspectorExpandedController extends Notifier<bool> {
  bool build() => true;
  /// 收起全部 / 恢复（快捷键与 ⌘K 共用这一个入口）。
  void toggleCollapseAll();
  // 私有：bool? _savedLeftExpanded —— 收起那一刻左面板的开合
}

// shortcuts/collapse_panels_keys.dart
abstract final class CollapsePanelsKeys {
  static const SingleActivator meta = SingleActivator(LogicalKeyboardKey.backslash, meta: true, shift: true, includeRepeats: false);
  static const SingleActivator control = SingleActivator(LogicalKeyboardKey.backslash, control: true, shift: true, includeRepeats: false);
}
// 注册表条目：intent / 回调 = ref.read(inspectorExpandedProvider.notifier).toggleCollapseAll()，
// 文案键 canvasShortcutCollapseAllPanels，对文本编辑让位（与 Ctrl \ 那一行同一个让位标志）。
```
`toggleCollapseAll` 状态机（检查器只能被「收起全部」收起，所以 `state == false` 就是「处于收起全部」）：
- `state == true`（检查器开着）⇒ `_savedLeftExpanded = ref.read(leftRailProvider).expanded`；`leftRailProvider.notifier.setExpanded(false)`；`state = false`。
- `state == false` ⇒ `state = true`；`leftRailProvider.notifier.setExpanded(_savedLeftExpanded ?? true)`；`_savedLeftExpanded = null`。
- 与现有 Shift+1 / Shift+2 一样用 `SingleActivator(..., shift: true)` 写法（canvas_shortcuts.dart 约第 205 行 `fitAll` 是先例）。

## 行为规则与边界情况
- R1 两边都开 → 按一次：两边都收，导航条在；再按：两边都开。
- R2 左面板本来就收着、检查器开 → 按一次：检查器收；再按：检查器开、左面板**仍收着**（恢复各自的开合）。
- R3 收起全部期间用 Ctrl \ 打开了左面板 → 再按 Ctrl Shift \：检查器开、左面板回到收起前记住的状态（`_savedLeftExpanded`）。
- R4 Ctrl \ / ⌘\ 只管左面板，不碰 `inspectorExpandedProvider`（现有测试 canvas_left_rail_test 约第 121 行照绿）。
- R5 焦点在文本框（大纲筛选框、检查器输入）里时新键让位，不收面板。
- R6 没有打开画布（`currentCanvasIdProvider == null`）时快捷键与 ⌘K 动作都不生效 / 置灰。
- R7 按住不放不连发（`includeRepeats: false`）。
- R8 恢复后若窗口放不下左面板，panel-resize 的自动收起照常生效（R6 of panel-resize）；本片不另处理。
- R9 状态不落盘：应用重启后两边都开（与 leftRailProvider 同）。
- R10 平台差异：macOS 走 ⌘⇧\，Windows 走 Ctrl Shift \；两个 activator 都注册（与 Ctrl \ 的双注册同法），设置「快捷键」页按平台显示其一。部分键盘布局下 Shift+\ 的逻辑键可能不是 backslash，见风险 1。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasShortcutCollapseAllPanels | Collapse / restore all panels | 收起 / 恢复全部面板 |
| appActionCollapseAllPanels | Collapse all panels | 收起全部面板 |
| appActionRestorePanels | Restore panels | 展开面板 |

## 测试
- `test/features/canvas/providers/inspector_expanded_test.dart`（ProviderContainer）：
  - `defaults to expanded`。
  - `collapse all hides both and restore brings both back`。
  - `restore keeps the left panel collapsed if it was collapsed before`。
  - `left panel opened during collapse-all is reset to the saved state on restore`。
  - `provider is not autoDispose` —— 无监听者时读两次，状态保留。
- `test/features/canvas/providers/left_rail_state_test.dart`：`setExpanded changes only expanded and keeps page`；`setExpanded with same value does not notify`。
- `test/features/canvas/widgets/canvas_collapse_panels_test.dart`（`CanvasScreen(isVisible: true)`，覆写 currentCanvasIdProvider + fake 画布）：
  - `ctrl shift backslash collapses left panel and inspector, rail stays` —— 找不到 CanvasLeftRailPanel / CanvasInspectorPanel 内容，CanvasLeftRail 宽 43 仍在，舞台右沿 = 屏宽。
  - `pressing again restores both`。
  - `ctrl backslash still toggles only the left panel`。
  - `shortcut yields while typing in the outline filter`。
  - `meta shift backslash works on macOS` —— `debugDefaultTargetPlatformOverride = TargetPlatform.macOS`。
  - `holding the keys does not toggle repeatedly` —— 发 repeat 事件，状态只变一次。

## 变异点
- M1 `toggleCollapseAll` 收起时不记 `_savedLeftExpanded`（恢复一律展开）→ `restore keeps the left panel collapsed...` 红。
- M2 恢复时不清 `_savedLeftExpanded` / 收起时覆盖已有记录 → `left panel opened during collapse-all is reset...` 红。
- M3 provider 改成 autoDispose → `provider is not autoDispose` 红。
- M4 canvas_screen 不看 `inspectorExpandedProvider` → `ctrl shift backslash collapses left panel and inspector...` 红。
- M5 activator 去掉 `shift: true` → `ctrl backslash still toggles only the left panel` 红（Ctrl \ 会被两行同时接）。
- M6 去掉文本让位 → `shortcut yields while typing in the outline filter` 红。
- M7 `includeRepeats` 改 true → `holding the keys does not toggle repeatedly` 与注册表守卫测试红。
- M8 `setExpanded` 顺手把 page 重置成 outline → `setExpanded changes only expanded and keeps page` 红。

## 验收
- `flutter analyze lib test`。
- `flutter test test/features/canvas/providers test/features/canvas/widgets test/features/settings/shortcut_catalog_test.dart test/features/command_palette --exclude-tags golden`。
- 变异 M1–M8。
- 截图：`CanvasScreen(isVisible: true)`，覆写当前画布 + 3 个节点、选中 1 个；截①默认、②收起全部后（只剩导航条 + 舞台）、③恢复后；再截设置「快捷键」页确认多出一行。

## 风险与不确定
1. Shift+\ 的逻辑键：仓库已有 Shift+1 / Shift+2 用 `SingleActivator(digit1, shift: true)` 的先例，但非 US 布局（如德语、日语）下 `\` 位置不同、Shift 后可能出 `|`；请在测试里两个平台各发一次 `LogicalKeyboardKey.backslash` + shift 钉住，真机差异在回报里写「未在非 US 布局验证」。
2. canvas_shortcut_registry 的条目结构、让位标志名、app_action_catalog 的条目结构都来自 esc-ladder / app-action-table（签名以合入后为准）。
3. 检查器收起后没有可见的展开入口（设计缺口①），用户可能找不到回来的路；⌘K 动作「展开面板」是唯一的非快捷键入口。
4. panel-resize 的 post-frame 自动收起左面板若与恢复同帧发生，左面板可能闪一下再收起；接受，回报里写截图结论。
