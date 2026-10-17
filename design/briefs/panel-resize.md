# panel-resize · 左面板与检查器拖边调宽（舞台至少留 480）
- 波次：W14 / lane：B / 基底：origin/main（W0–W13 已合入）
- 依赖切片：无硬依赖（rail-script-panel W12 改过 left_rail_panel.dart 加了剧本页，基于合入后的版本改）
- 阻塞决定：P1 → A（检查器也能拖，260–480，与左面板同一套热区和记法）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/panel-resize`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片不碰。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不涉及。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：宽度计算写成纯函数（`panel_widths.dart`），widget 只接线；拖动中只改内存，**松手才落盘**。

## 目标
左面板右沿、检查器左沿各有一条看不见的 6px 拖动热区：悬停变 2px accent 线，按住拖可调宽，拖动时旁边浮一个「↔ 280」读数；双击回默认宽。
宽度全局记一个值（preferences.json），所有画布共用；窗口变窄时先压检查器、再压左面板，还不够就自动收起左面板，保证舞台至少 480 宽。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` 小节「面板调宽 · 收起全部面板」（b2_gaps_panels.js 约第 98–120 行）：
  - 原文：「左面板右沿 6px 热区（看上去仍是 1px 线），悬停变 2px accent；内容宽 200–420，默认 240，双击回默认；松手才落盘，全局记一个 leftPanelWidth（preferences.json）」。
  - 原文：「舞台至少留 480：窗口变窄先压检查器、再压左面板，仍不够自动收起左面板（记住的宽度不动）」。
  - 读数徽标：高 14、左右内边距 4、圆角 3、surface5 底、1px overlayBorder、等宽 9 号 fg1，文字「↔ 280」（内容宽，整数）。
- P1 建议 A「能，260–480，与左面板同一套热区和记法」——检查器默认 300（现 301 = 300 + 1px 左沿）。
- 设计缺口：①拖动时读数徽标的确切位置（画板只有缩略示意）——定为贴着热区、垂直居中于面板，左面板在热区右侧 8px，检查器在热区左侧 8px；②自动收起后左栏导航条的高亮——跟随 leftRailProvider（本片把收起写进状态，见 R7）。

## 允许改的文件
- `lib/features/canvas/providers/panel_widths.dart`（新建）：`PanelWidths` 值对象、`PanelWidthsController`、`panelWidthsProvider`（非 autoDispose）、纯函数 `resolvePanelLayout`。
- `lib/features/canvas/widgets/panel_resize_handle.dart`（新建）：`PanelResizeHandle`（热区 + 悬停线 + 拖动读数 + 双击）。
- `lib/features/canvas/widgets/left_rail/left_rail_panel.dart`：删 `static const double width = 241`（约第 26 行），改为 `static const double defaultWidth = InkPanelSize.leftDefault + 1`（供测试 / 外部引用默认值）；构造加可选参数 `this.contentWidth = InkPanelSize.leftDefault`（由 canvas_screen 传入；`Container.width = contentWidth + 1`）。
- `lib/features/canvas/widgets/canvas_inspector_panel.dart`：删 `static const double width = 301`（约第 38 行），改为 `static const double defaultWidth = InkPanelSize.inspectorDefault + 1`；构造加可选参数 `this.contentWidth = InkPanelSize.inspectorDefault`（约第 63 行 `width:` 改用它 + 1）。可选是为了不动现有构造点：`test/features/canvas/widgets/inspector_auto_save_row_test.dart` 约第 156 行、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart` 约第 36 行。
- `lib/features/canvas/widgets/canvas_screen.dart`：`Row`（约第 49 行）外包 `LayoutBuilder`，经 `resolvePanelLayout` 算出两侧内容宽；左面板右沿、检查器左沿各叠一个 `PanelResizeHandle`；更新文件头注释里的「241 / 301」。
- `lib/core/models/app_preferences.dart`：加 `final double? leftPanelWidth`、`final double? inspectorWidth`（null = 用默认），JSON 键 `left_panel_width` / `inspector_width`；fromMap 非 num 退 null，超范围夹回 [min, max]；copyWith / == / hashCode / toMap 补齐。
- `lib/services/file_preferences_service.dart`：只经 toMap / fromMap 序列化（约第 74 行），不预期改动，仅核对。
- `lib/theme/tokens.dart`：只追加 `class InkPanelSize { leftMin = 200; leftMax = 420; leftDefault = 240; inspectorMin = 260; inspectorMax = 480; inspectorDefault = 300; stageMin = 480; resizeHit = 6; resizeLine = 2; resizeBadgeGap = 8; }`。
- 测试（引用旧常量的三处必须改）：
  - `test/features/canvas/widgets/inspector_auto_save_row_test.dart` 约第 68 行 `CanvasInspectorPanel.width` → `defaultWidth`。
  - `test/features/canvas/widgets/inspector_history_panel_test.dart` 约第 104 行同上。
  - `test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart` 约第 152 行 `CanvasLeftRailPanel.width` → `defaultWidth`。
  - `test/features/canvas/providers/panel_widths_test.dart`（新建）、`test/features/canvas/widgets/panel_resize_test.dart`（新建）、`test/core/models/app_preferences_test.dart`（追加）。

## 不许碰的文件
- W14 其他片：`models/canvas_node_note.dart`、`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`widgets/canvas_toolbar.dart`、`widgets/node_card.dart`、`widgets/stage_edge_layer.dart`、`widgets/text_node_inspector.dart`、`util/outline_model.dart`、`generation/generation_controller.dart`（note-variant）；`left_rail/assets_panel.dart`、`left_rail/asset_hover_preview.dart`（assets-hover-preview）；`character_library_panel.dart`、`character_edit_dialog.dart`、`canvas/models/character.dart`、storage/**（character-kind）；`lib/features/export/**`、`shell/widgets/shell_task_*.dart`（export-in-task-popover → delivery-clips-tab）。
- 同 lane 后序 W15 collapse-all-panels：`providers/left_rail_state.dart`、`providers/inspector_expanded.dart`——本片不加 inspectorExpanded，不改 LeftRailController（自动收起只调用现有 `toggle()`）。
- `widgets/left_rail/canvas_left_rail.dart`、`create_node_menu.dart`（barrel）、`models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- note-variant：`lib/features/canvas/models/canvas_node_note.dart`、`lib/features/canvas/providers/link_action_controller.dart`、`lib/features/canvas/util/canvas_note_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/shortcuts/note_keys.dart`、`lib/features/canvas/widgets/stage_edge_layer.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/features/generation/generation_controller.dart`、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/models/canvas_node_note_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/note_node_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`
- assets-hover-preview：`lib/core/interfaces/video_player_service.dart`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/services/media_kit_video_player_service.dart`、`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/sequence/widgets/sequence_monitor_test.dart`
- character-kind：`lib/core/db/columns.dart`、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v11.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`
- export-in-task-popover：`lib/features/export/providers/delivery_controller.dart`、`lib/features/export/providers/export_controller.dart`、`lib/features/export/providers/export_task_registry.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`test/features/export/providers/delivery_execute_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/export_task_registry_test.dart`、`test/features/shell/shell_task_capsule_test.dart`、`test/features/shell/shell_task_popover_test.dart`
- delivery-clips-tab：`lib/features/export/util/delivery_clip_rows.dart`、`lib/features/export/widgets/delivery_clips_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/util/delivery_clip_rows_test.dart`、`test/features/export/widgets/delivery_clips_tab_test.dart`

## 具体改动
```dart
// providers/panel_widths.dart
@immutable class PanelWidths { const PanelWidths({required this.left, required this.inspector}); final double left; final double inspector; }
class PanelWidthsController extends Notifier<PanelWidths> {
  PanelWidths build();                    // 自 preferencesServiceProvider.current 播种，null → 默认，夹到范围
  void previewLeft(double content);       // 拖动中：只改内存（夹 [leftMin, leftMax]）
  void previewInspector(double content);
  void commit();                          // 松手：把当前两个值写 preferences（fire-and-forget，同 NotificationPrefsController._persist）
  void resetLeft();  void resetInspector(); // 双击：回默认并立即落盘
}
final panelWidthsProvider = NotifierProvider<PanelWidthsController, PanelWidths>(...);

@immutable class PanelLayout { final double left; final double inspector; final bool collapseLeft; }
/// available = 行宽 − 导航条 43（CanvasLeftRail.width）；各面板另占 1px 边。
PanelLayout resolvePanelLayout({required double available, required bool leftExpanded,
    required bool inspectorShown, required PanelWidths prefs});

// widgets/panel_resize_handle.dart
enum PanelEdge { right, left } // 拖的是面板的哪条边：左面板 = right，检查器 = left
class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({super.key, required this.edge, required this.contentWidth,
      required this.onDrag /* void Function(double newContent) */, required this.onDragEnd,
      required this.onReset});
}
```
`resolvePanelLayout` 顺序：先用记住的值；`available − (left+1)·[leftExpanded] − (inspector+1)·[inspectorShown] < stageMin` 时先把 inspector 压向 inspectorMin，再把 left 压向 leftMin；仍不够 ⇒ `collapseLeft = true`（left 不计入），再不够就让舞台拿剩下的（≥ 0），检查器不自动收。记住的 prefs 值始终不变。
canvas_screen：`collapseLeft && leftRail.expanded` 时在 post-frame 里调用一次 `ref.read(leftRailProvider.notifier).toggle()`（只在跨过阈值那一帧做，用局部标志防重入）。
热区：`MouseRegion(cursor: SystemMouseCursors.resizeColumn)` + `GestureDetector(onHorizontalDragStart/Update/End, onDoubleTap)`，宽 `InkPanelSize.resizeHit`，中心对齐面板那条 1px 边（Stack 里 Positioned，左右各探出 3px，压在舞台之上）。静止时不画任何东西（1px 边仍由面板自己的 border 画），悬停 / 拖动时画 `resizeLine` 宽 `colors.accent`。拖动时由 `onDrag` 回传「起拖宽 + 指针位移」（检查器方向取反），读数显示 `contentWidth.round()`。

## 行为规则与边界情况
- R1 默认：没有偏好时左 240、检查器 300，画面与现在一致（241 / 301 含边）。
- R2 拖动夹在范围内：左 [200, 420]、检查器 [260, 480]；同时不让舞台小于 480——拖到会挤到舞台时停在能放下的最大值。
- R3 拖动中每帧只改 `panelWidthsProvider`，不写 preferences；松手 `commit` 写一次；取消（指针丢失）同松手。
- R4 双击热区：回默认并立即落盘；与拖动不冲突（双击没有位移）。
- R5 窗口变窄：先压检查器到 260，再压左面板到 200；记住的值不变，窗口再变宽时恢复到记住的值。
- R6 仍不够：自动收起左面板（写 leftRailProvider，导航条高亮跟着灭）；窗口变宽**不**自动展开（与用户手动收起一致），用户展开后若仍放不下会再次收起。
- R7 左面板收起时不画左热区；没有画布（`canvasId == null`）时两侧都不画。
- R8 宽度全局一份：切画布 / 切项目不变；两个画布标签同一个值。
- R9 偏好非法（非 num、NaN、超范围）：读时夹回范围或退默认，不抛。
- R10 平台差异：无——光标 `resizeColumn` 在 macOS / Windows 都有；拖动用指针位移，与 DPI 无关（逻辑像素）。

## 新文案键
图标集 v1（lib/theme/icons/ink_glyph.dart）没有左右箭头 glyph，读数走 ARB：

| key | en | zh |
|---|---|---|
| panelResizeWidthBadge | ↔ {width} | ↔ {width} |

（`width` 为 int 占位符，ICU：`{width}`，placeholders 里声明 `"width": {"type": "int"}`。）

## 测试
- `test/features/canvas/providers/panel_widths_test.dart`：
  - `defaults are 240 and 300 when prefs are empty`。
  - `preview clamps to range and does not persist` —— previewLeft(999) ⇒ 420，preferences 未变。
  - `commit persists both widths once`。
  - `reset restores default and persists`。
  - `resolvePanelLayout keeps prefs when stage fits`。
  - `resolvePanelLayout squeezes inspector before left panel` —— available 刚少 30 ⇒ inspector 减 30、left 不变。
  - `resolvePanelLayout collapses left panel when both minima still leave stage below 480`。
  - `remembered widths are untouched by squeezing` —— 断言 prefs 对象未变。
- `test/features/canvas/widgets/panel_resize_test.dart`（ProviderScope 覆写 preferencesServiceProvider 为 InMemoryPreferencesService，屏宽 1440）：
  - `dragging the left edge widens the panel and shows the width badge`。
  - `dragging the inspector edge to the left widens the inspector`。
  - `releasing persists left_panel_width`；`double-click resets to default`。
  - `hover shows accent line, idle shows none`。
  - `narrow window auto-collapses the left panel` —— 屏宽 43+201+480+261 − 10 ⇒ leftRailProvider.expanded == false。
- `test/core/models/app_preferences_test.dart`：`panel widths round-trip and clamp on read`。
- `test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart` 约第 146 行用例改用 `defaultWidth` 后仍绿。

## 变异点
- M1 `resolvePanelLayout` 先压左面板再压检查器 → `squeezes inspector before left panel` 红。
- M2 去掉 collapseLeft 分支 → `collapses left panel when...` 与 `narrow window auto-collapses the left panel` 红。
- M3 `previewLeft` 里顺手落盘 → `preview clamps to range and does not persist` 红。
- M4 `commit` 不写 → `releasing persists left_panel_width` 红。
- M5 夹范围的上限写成 480（左）→ `preview clamps to range...` 红。
- M6 检查器拖动方向不取反 → `dragging the inspector edge to the left widens the inspector` 红。
- M7 压缩时改写 prefs → `remembered widths are untouched by squeezing` 红。
- M8 `fromMap` 不夹范围 → `panel widths round-trip and clamp on read` 红。

## 验收
- `flutter analyze lib test`。
- `flutter test test/features/canvas/providers test/features/canvas/widgets test/core/models --exclude-tags golden`。
- 变异 M1–M8。
- 截图：`CanvasScreen(isVisible: true)`，覆写 currentCanvasIdProvider + fake 画布数据；截①默认、②左面板拖到 320 中（读数 + accent 线）、③检查器 420、④窗口 1100 宽（检查器被压）、⑤窗口 900 宽（左面板自动收起）。

## 风险与不确定
1. 左面板内容在 200 宽时的排版（角色库行、素材两列网格、剧本页）未在画板验证；character_library_panel.dart 头注释写着「横向数字按 240 折算」。本片不改这些面板，只在回报里列出 200 宽截图中出现的溢出。
2. assets-hover-preview（同波 W14）的大预览「贴面板右沿外」——它若自己写死 241 会错位；回报里提醒主 Agent 合并时让它读 `panelWidthsProvider`。
3. post-frame 写 leftRailProvider 的自动收起与 W15 collapse-all-panels 的「恢复」可能来回打架（恢复后放不下又被收起）；按 R6 接受，W15 派工单已注明。
4. 「↔」读数走 ARB 键 panelResizeWidthBadge（图标集无左右箭头）；若主 Agent 认为纯数字读数无需 i18n，可改为只显示数字。
