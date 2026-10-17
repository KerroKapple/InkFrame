# note-variant · 便签（text 节点 variant = note）

> **阻塞决定 IS-Q5（plan.md 第 5 节）：按建议 A 写——便签 = `text` 节点 + `type_config.variant = "note"`，不迁移。** critic 第 13 条把「Q5 选 B」列进迁移清单，与画板建议不一致；如最终拍板选 B，本单作废重写。

- 波次：W14 / lane：A / 基底：origin/main（W0–W13 已合入）
- 依赖切片：menu-split（W0）、canvas-view-split（W0）、esc-ladder（W0，快捷键注册表）、naming-shot-unify（W0）、canvas-find-bar（W9）、create-menu-pick-recent（W13，addNodeFromMenu 已能收 typeConfig）
- 阻塞决定：**IS-Q5 选 A**——便签仍是 `text` 节点，`type_config.variant = "note"`，不迁移、不加 nodes.type 档位

## 执行约定
1. 在你自己的工作树里，从 origin/main（W0–W13 已合入）起新分支 `feat/note-variant`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法，用现有 patchTypeConfig / update。（注意：`canvas_node.dart` 实际是手写 `@immutable` 类、不是 freezed，规则照样：不改它。）
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 不碰 `canvas_tool_actions.dart`：便签的建节点动作写在新文件 `util/canvas_note_actions.dart`，复用 `addNodeAtViewportCenter` / `addNodeFromMenu`（W13 已加 `typeConfig` 参数）。
10. 「是不是便签」只有一个判据：`canvas_node_note.dart` 里的 `isNoteTypeConfig`（行映射）与 extension `isNote`（模型），其他地方都调它。

## 目标
- 按 N、点工具条「便签」、或新建菜单「便签」，在画布上建一张便签：三种底色、没有端口、不能连线。
- 便签不进提示词（生成与检查器预览都不并入）、不进左栏大纲；画布查找（Ctrl F）照样搜得到正文。
- 检查器沿用文本正文框，便签时多一行底色选择。

## 设计依据
- `b2/project/ImportSearch.dc.html` ›「工具锁 · 便签」：
  - 「N 建便签：没有端口，不进提示词和大纲，查找能搜到；三种底色」。
  - 「正文只有一个键 type_config.text：检查器正文框……是随时可用的那条路」。
  - 「新键 Ctrl U、Ctrl F、M、Q、N 都不撞现有键；单键只在画布持焦且不在文字里时生效」。
  - 样稿卡：琥珀底 `#2A2318`、描边 `#6B5A38`、浮层阴影、正文 `#E8E8E8` 行高 1.5，旁注「便签 N · 不进提示词」，对照文本卡「连线后并入提示词」。
  - 需要你定 5：「A. 仍是 text，type_config.variant = note，不迁移 / B. 新类型 note，nodes.type 加一档，新增一条前向迁移；建议 A；提示词拼装、大纲要排除便签，检查器沿用文本正文框」。
- `b2/project/GapsCanvas.dc.html` › 新建菜单：「建节点组加便签、统一叫『镜头』」；便签字号 / 标题（note_style）属 W16 note-heading-style，本片不做。
- `b2/project/ShellExport.dc.html` / `RailScript.dc.html`：可建类型叫法与顺序「图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道」。
- `b2/project/KeyMap.dc.html`：N = 新建便签（画布，第二批）。
- 设计缺口：只画了琥珀一种底色，另两种（本片定为「青灰」「苔绿」，取 `InkPalette.canvasCardColorChoices` 的蓝灰 / 墨绿面）与浅色主题下的三种底色都没画。
- 设计缺口：便签卡在节点尺寸体系里多大没画。本片保持外框 `kNodeCardSize`（命中、框选、适应视口、连线几何都按它），整卡画成便签纸，不画标题行 / 状态行 / 继承行。
- 设计缺口：底色选择器长什么样没画。本片：检查器里三颗色块（与 `canvas_appearance_section` 的色块同款）。

## 允许改的文件
- `lib/features/canvas/models/canvas_node_note.dart`（新建）：键名常量、`NoteTint`、`isNoteTypeConfig`、extension `CanvasNodeNote`、`noteTypeConfig()`。
- `lib/features/canvas/util/create_menu_model.dart`（W14 归本片）：`CreateMenuAction.note` 进 `kPlainCreateActions`；`createdNodeType(note) = text`；新增 `createdTypeConfig`。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（menu-split 新建；W14 归本片）：便签行（标签、`InkGlyph.note`、键位 N）；派发带 typeConfig；Tab 视口中心路径走 `addNoteAtViewportCenter`。
- `lib/features/canvas/widgets/shortcuts/note_keys.dart`（新建）+ `canvas_shortcut_registry.dart` 追加一行：N（`includeRepeats: false`，文字里让位）。
- `lib/features/canvas/util/canvas_note_actions.dart`（新建）：`addNoteAtViewportCenter`。
- `lib/features/canvas/widgets/canvas_toolbar.dart`：「镜头」后加「便签」按钮。
- `lib/features/canvas/widgets/node_card.dart`（W14 归本片）：便签分支外观；不画端口、不当连线候选；`nodeDisplayName` 便签回落「便签」。
- `lib/features/canvas/widgets/stage_edge_layer.dart`（canvas-view-split 新建；W14 归本片）：核对拖线松手逻辑所在；若在这里，落到便签上不开新建菜单、交给 linkTo 拒绝。没有相关代码就不改。
- `lib/features/canvas/providers/link_action_controller.dart`（**不在归属表，W14 无人占用**）：`LinkActionResult` 加 `noteRejected`；`linkTo` 源或目标是便签 ⇒ 取消连线模式并发该结果。
- `lib/features/canvas/widgets/canvas_view.dart`（**不在归属表，W14 无人占用**）：`_onLinkEvent`（现约第 300 行）的 switch 加 `noteRejected` 一臂（warning）。若 W0 后它在别的文件，改那个文件并回报。
- `lib/features/canvas/widgets/text_node_inspector.dart`：便签时组标题「便签」+ 底色行。
- `lib/features/canvas/widgets/image_config_inspector.dart`（**不在归属表，W14 无人占用**）：最终提示词预览收集文本入边处（现约第 600 行）跳过便签，与生成链路一致。
- `lib/features/canvas/util/outline_model.dart`（W14 归本片）：`buildCanvasOutline` 的配置节点集合排除便签（configCount 同步）。
- `lib/features/generation/generation_controller.dart`（W14 归本片）：`_resolveAssociatedTexts`（现约第 962 行）跳过便签行。
- `lib/theme/tokens.dart`：只追加 `InkNoteTint` 常量类。
- 测试：`test/features/canvas/models/canvas_node_note_test.dart`（新建）、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/note_node_test.dart`（新建）、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`。

## 不许碰的文件
- W14 其他切片：`panel_resize_handle.dart`、`panel_widths.dart`、`left_rail_panel.dart`、`canvas_inspector_panel.dart`、`canvas_screen.dart`、`app_preferences.dart`、`file_preferences_service.dart`（panel-resize）；`left_rail/assets_panel.dart`、`asset_hover_preview.dart`（assets-hover-preview）；character / schema_v11 / app_migrations / import_remapper / columns / characters_controller / character_* widgets（character-kind）；export_task_registry / export_controller / delivery_* / shell_task_*（export lane）。
- `canvas_tool_actions.dart`、`canvas_node.dart`、`create_node_menu.dart`（barrel）、`shortcut_catalog.dart`（注册表已提供文案）、`node_card_slot.dart`（W15 归 text-inline-edit）。
- ARB、`lib/l10n/generated/`、`docs/CLAUDE.md`。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- panel-resize：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/panel_widths.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/panel_resize_handle.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/panel_widths_test.dart`、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart`、`test/features/canvas/widgets/inspector_auto_save_row_test.dart`、`test/features/canvas/widgets/inspector_history_panel_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/panel_resize_test.dart`
- assets-hover-preview：`lib/core/interfaces/video_player_service.dart`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/services/media_kit_video_player_service.dart`、`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/sequence/widgets/sequence_monitor_test.dart`
- character-kind：`lib/core/db/columns.dart`、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v11.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`
- export-in-task-popover：`lib/features/export/providers/delivery_controller.dart`、`lib/features/export/providers/export_controller.dart`、`lib/features/export/providers/export_task_registry.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`test/features/export/providers/delivery_execute_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/export_task_registry_test.dart`、`test/features/shell/shell_task_capsule_test.dart`、`test/features/shell/shell_task_popover_test.dart`
- delivery-clips-tab：`lib/features/export/util/delivery_clip_rows.dart`、`lib/features/export/widgets/delivery_clips_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/util/delivery_clip_rows_test.dart`、`test/features/export/widgets/delivery_clips_tab_test.dart`

## 具体改动
canvas_node_note.dart：
```dart
const String kNodeVariantKey = 'variant';
const String kNoteVariant = 'note';
const String kNoteTintKey = 'note_tint';
enum NoteTint { amber, slate, moss }           // 存储名 = name；缺省 / 非法 ⇒ amber
bool isNoteTypeConfig(Map<String, Object?> typeConfig);   // typeConfig['variant'] == 'note'
NoteTint noteTintOf(Map<String, Object?> typeConfig);
Map<String, Object?> noteTypeConfig({NoteTint tint = NoteTint.amber});   // {'variant': 'note', 'note_tint': tint.name}
extension CanvasNodeNote on CanvasNode { bool get isNote; NoteTint get noteTint; }   // isNote = type == text && isNoteTypeConfig
```
create_menu_model.dart：`CreateMenuAction.note` 插在 `shot` 之后、`lane` 之前（与 ShellExport / RailScript 的叫法顺序一致）；`createdNodeType(note) => CanvasNodeType.text`；`createdEdge(note) => null`；新增 `Map<String, Object?> createdTypeConfig(CreateMenuAction action)`（note ⇒ `noteTypeConfig()`，其余 `const {}`）；W13 pick-recent 的 `createdTypeConfigOf(CreateMenuPick pick)` 里 action 分支改为调用它（不再恒回 `{}`）。
canvas_note_actions.dart：
```dart
Future<void> addNoteAtViewportCenter(BuildContext context, WidgetRef ref, {required String canvasId, Random? random});
```
实现 = `addNodeAtViewportCenter(context, ref, canvasId:, type: CanvasNodeType.text, random:, typeConfig: noteTypeConfig())`（canvas_tool_actions.dart 约第 110 行；`typeConfig` 参数由 W13 create-menu-pick-recent 加在 `addNodeFromMenu` 与 `addNodeAtViewportCenter` 上，参数名固定为 `typeConfig`）。新建菜单带锚点的路径直接 `addNodeFromMenu(..., typeConfig: createdTypeConfig(action))`。
note_keys.dart：`CanvasAddNoteIntent` + 绑定 `SingleActivator(LogicalKeyboardKey.keyN, includeRepeats: false)`，动作走注册表规定的「文字里让位」包装（与 I / G / T 的 `_EditingAwareAction` 同口径）；设置页文案键 `settingsShortcutCanvasAddNote`。
canvas_toolbar.dart：「镜头」按钮（`keyOf('shot')`，约第 113 行）后加 `keyOf('note')`：label `canvasToolNote`、`InkGlyph.note`（ink_glyph.dart 第 135 行已有）、keys `['N']`（取 note_keys 的常量 keyLabel）、onTap `addNoteAtViewportCenter`。
node_card.dart：
- `build`（约第 271 行起）：`node.isNote` ⇒ 走 `_NoteCard`：外框 `kNodeCardSize`；整卡底色 / 描边取 `InkNoteTint` 对应色、圆角 `InkRadius.sm`、浮层阴影；正文 `node.textContent` 用 `typo.body`、`colors.fg1`、内边距 `InkSpacing.s10`；选中时描边换 `colors.accent`；compact（`canvasCompactCardsProvider`）⇒ 居中 `InkGlyph.note` 图标。
- 便签不渲染入 / 出端口（`showInPort` / `showOutPort` 恒 false），`isLinkSource` / `isLinkCandidate` 不改便签外观；`portDrag` 忽略。
- 新增 `String nodeKindLabel(BuildContext, CanvasNode)`：便签 ⇒ `canvasNodeNoteType`，其余 `nodeTypeLabel`；`nodeDisplayName`（约第 457 行）空标签回落改用它。
link_action_controller.dart：`enum LinkActionResult { created, selfLinkRejected, duplicate, failed, noteRejected }`；`linkTo` 在自连判断之后、addEdge 之前读节点表：源或目标 `isNote` ⇒ `linkCtrl.cancel()`，`state = LinkActionEvent(LinkActionResult.noteRejected)`，不写库。拖线落到便签也走这里（`linkByPortDrop` → `linkTo`）。
text_node_inspector.dart：`widget.node.isNote` ⇒ 组标题 `canvasNodeNoteType`；正文框不变；其下加「底色」行（三颗色块，当前打勾），点选 = `_submitCtrl.saveConfig({kNoteTintKey: tint.name})` 后 `ref.invalidate(canvasNodesControllerProvider(canvasId))`（与失焦提交同一做法）。
outline_model.dart：`buildCanvasOutline`（约第 149 行）的 `configs` 过滤加 `&& !n.isNote`。
generation_controller.dart：`_resolveAssociatedTexts` 在 `src[NodeCol.type] != 'text'` 之后读 tc，`isNoteTypeConfig(tc)` ⇒ continue。
image_config_inspector.dart：约第 600 行 `src.type != CanvasNodeType.text` 改为同时排除 `src.isNote`。
tokens.dart（只追加）：`class InkNoteTint { static const Color amberFill = Color(0xFF2A2318); amberBorder = Color(0xFF6B5A38); slateFill / slateBorder; mossFill / mossBorder; 以及 light 档 amberFillLight … }`。`NoteTint` → 颜色的映射**不放 tokens**（theme 层不许引用 features 类型，`no_reverse_layer_import_test` 守着），写成 node_card.dart 里的公开函数 `({Color fill, Color border}) noteTintColors(NoteTint tint, Brightness brightness)`；检查器色块调同一个函数（models 不引 theme，所以不放 canvas_node_note.dart）。

## 行为规则与边界情况
- R1：N / 工具条「便签」/ Tab 菜单「便签」在视口中心 + 散布建一张；新建菜单（双击 / 右键「新建…」）落在锚点；都写 `{'variant': 'note', 'note_tint': 'amber'}`。
- R2：带连线上下文的新建菜单不出「便签」（`createMenuGroups(source != null)` 不变）。
- R3：便签不画端口；在便签上按 L / 从别的卡拖线落到便签 / 连线模式下点便签 ⇒ 不建边、连线模式退出、出 warning 卡「便签不能连线」。
- R4：生成时连到目标的 data 边若源是便签（老数据 / 导入数据）⇒ 不并入提示词；检查器预览同样不列。
- R5：便签不进左栏大纲，也不计入大纲的配置节点总数（空画布只有便签 ⇒ 大纲空态）。
- R6：画布查找能命中便签正文（canvas-find-bar 搜 text 节点正文，便签是 text，自动覆盖；测试钉住）。
- R7：「下一镜」锚点、拖到线上插入、序列、导出都已排除 text，便签随之排除，不改。
- R8：Ctrl D 复制便签保留 variant 与底色（`duplicateNodes` 原样拷 typeConfig）。
- R9：底色改动走 InspectorSubmitController 串行写链，失败进「未保存 · 重试」行；成功后画布重载。
- R10：N 在文字编辑里让位（提示词条、检查器、查找框里打 n 是字符）；按住不放不连建（`includeRepeats: false`）。
- R11：撤销：建便签与建其他节点同一条撤销路径（undo-node-create-move 已接 addNodeFromMenu），一步撤销。
- R12：未知 `note_tint` 值 ⇒ 按琥珀画，不抛。
- R13：无平台差异：N 单键两平台相同，不带修饰键。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasToolNote | Sticky note | 便签 |
| canvasCreateMenuNote | Sticky note | 便签 |
| canvasNodeNoteType | Note | 便签 |
| settingsShortcutCanvasAddNote | New sticky note | 新建便签 |
| inspectorNoteTintLabel | Color | 底色 |
| noteTintAmber | Amber | 琥珀 |
| noteTintSlate | Slate | 青灰 |
| noteTintMoss | Moss | 苔绿 |
| linkNoteNotAllowed | Sticky notes can't be linked | 便签不能连线 |

## 测试
先写、先红。
- `test/features/canvas/models/canvas_node_note_test.dart`（新建）：`'isNote is true only for text nodes with variant note'`（image + variant note ⇒ false）；`'noteTint falls back to amber on missing or unknown value'`；`'noteTypeConfig writes variant and tint'`。
- `test/features/canvas/util/create_menu_model_test.dart`：`'plain create actions list note between shot and lane'`；`'note creates a text node with note type config'`；`'menus with a source do not offer note'`。
- `test/features/canvas/util/outline_model_test.dart`：`'outline excludes sticky notes and does not count them'`。
- `test/features/generation/generation_controller_prompt_test.dart`：`'data edge from a sticky note is not merged into the prompt'`（同一画布一张普通文本 + 一张便签都连 data 边 ⇒ 只并入普通文本）。
- `test/features/canvas/link_action_controller_test.dart`：`'linking to a sticky note is rejected without writing an edge'`；`'linking from a sticky note is rejected'`。
- `test/features/canvas/widgets/note_node_test.dart`（新建）：`'note card renders body with tint and no ports'`（找不到 `NodeCard.inPortKey` / `outPortKey`，悬停后仍找不到）；`'pressing N on the focused canvas creates a sticky note at viewport center'`；`'pressing N inside a text field types a character'`；`'find bar matches sticky note body'`（调用 canvas-find-bar 的匹配函数，名字以合入后为准）。
- `test/features/canvas/widgets/canvas_toolbar_test.dart`：`'toolbar note button creates a sticky note'`。
- `test/features/canvas/widgets/text_node_inspector_test.dart`：`'note inspector shows tint row and saves note_tint'`；`'plain text inspector has no tint row'`。

## 变异点
- M1：`isNoteTypeConfig` 改成恒 false → `'isNote is true only…'`、`'outline excludes sticky notes…'`、`'note card renders body…'` 变红。
- M2：`_resolveAssociatedTexts` 去掉便签判断 → `'data edge from a sticky note is not merged into the prompt'` 变红。
- M3：outline 的 `!n.isNote` 去掉 → `'outline excludes sticky notes and does not count them'` 变红。
- M4：`linkTo` 去掉便签拒绝 → `'linking to a sticky note is rejected without writing an edge'` 与 `'linking from a sticky note is rejected'` 变红。
- M5：node_card 便签分支恢复端口 → `'note card renders body with tint and no ports'` 变红。
- M6：note_keys 去掉文字让位包装 → `'pressing N inside a text field types a character'` 变红。
- M7：`createdTypeConfig(note)` 返回 null → `'note creates a text node with note type config'`、`'toolbar note button creates a sticky note'` 变红。
- M8：`noteTintOf` 未知值抛 / 返回 null → `'noteTint falls back to amber…'` 变红。

## 验收
- `flutter analyze lib test`。
- `flutter test --exclude-tags golden test/features/canvas/ test/features/generation/ test/features/settings/shortcut_catalog_test.dart`。
- 变异 M1–M8 逐条。
- 截图：`CanvasScreen` + ProviderScope 覆写 InMemory 仓储（一张图像配置、一张普通文本连 data 边、三张便签各一种底色），截：①画布全貌（便签无端口）；②选中一张便签的检查器（底色行）；③工具条（便签按钮 tooltip「便签 N」）；④新建菜单不带上下文（便签在镜头之后）；⑤左栏大纲（无便签）；⑥缩放 < 0.6 时便签收成图标。

## 风险与不确定
- **critic 与画板说法不一致**：critic.txt 第 13 条把「ImportSearch Q5 选 B（便签做成新类型）」列进要迁移的清单，且第 41 行只说「便签颜色有了」；ImportSearch 画板建议 A（不迁移）。plan.md 第 5 节按 A。本片照 A：不迁移、不新增 nodes.type 档。若日后改 B，要一条前向迁移把 variant = note 的 text 行改型，本片的判据集中在 `canvas_node_note.dart`，改动面可控。
- 画板之间顺序不一致：GapsCanvas 新建菜单样稿是「文本 T · 便签 N · 镜头」，ShellExport / RailScript / revise-summary #16 是「文本 · 镜头 · 便签」；本片按后者（多数），W18 create-menu-notes-characters 若要改顺序在那边改。
- `addNodeFromMenu` / `addNodeAtViewportCenter` 的 `typeConfig` 参数由 W13 create-menu-pick-recent 加（其派工单已固定参数名）；若合入后没有，本片无权改 canvas_tool_actions.dart，需停下回报。
- 新建菜单派发若在 W0 后仍在 `canvas_menu_host.dart`（W14 无人占用），需在那里加一臂，回报说明。
- 另两种底色与浅色主题配色是本片自定（设计缺口），需主 Agent 确认。
- 越出归属表的文件：`link_action_controller.dart`、`canvas_view.dart`（`_onLinkEvent` 一臂）、`image_config_inspector.dart`（预览排除便签），W14 均无人占用。
- 便签标题 / 字号（note_style）留给 W16 note-heading-style；本片正文字号用 `typo.body`，W16 再换 `noteBody`。
