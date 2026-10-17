# note-heading-style · 便签两档字号（正文 / 标题）
决定：IS-Q5 按建议 A（便签 = text 节点 + `type_config.variant = note`，不迁移）

- 波次：W16；lane：A；基底：origin/main（W0–W15 已全部合入）
- 依赖切片：note-variant（W14，硬依赖：`lib/features/canvas/models/canvas_node_note.dart` 的 extension `CanvasNodeNote`〔`isNote` / `noteTint`〕、键名常量 `kNodeVariantKey` / `kNoteTintKey`、node_card 里的 `_NoteCard` 与 `noteTintColors`、便签卡体、三种底色、便签不接端口、不进提示词 / 大纲）；text-inline-edit（W15，软依赖：就地编辑器）；canvas-view-split（W0，nodeStageRect 的调用方已拆进 node_card_slot / stage_*）。执行本片时以上都已在 main 上。
- 阻塞决定：IS-Q5 → 按建议 A 执行；N6（GapsCanvas）→ 按建议 A（只有两档）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 便签多一档「标题」：20 号 / 500 字重、无底色无边框、宽度跟字走、最宽 480 换行，当章节路标用。
- 检查器正文框上方加「正文 | 标题」切换；正文便签保持现状（12 / 1.55、三种底色）。
- 缩到 60% 以下：正文便签收成图标（与其它卡一致），标题便签不收，屏幕上的字不小于 12 号。

## 设计依据
画板 GapsCanvas.dc.html › 「便签字号 · 标题」（副标题「便签 = 文本节点 variant=note（ImportSearch Q5）」）。规则原文：
1. 两档（N6）：正文 12 / 1.55，标题 20 / 500；存 `type_config.note_style` = `body | heading`，JSONB 不迁移。
2. 标题便签无底色无边框，宽度跟字走，最宽 480 换行；三种底色只给正文便签。
3. 缩放 < 0.6 时正文便签收成图标（同卡片），标题不收，屏幕字号不小于 12：缩远了当章节路标。
4. 需：字号进 InkTypography（noteBody / noteHeading），检查器正文框上方加「正文 | 标题」切换。
5. 标题便签不进大纲、不进提示词，查找能搜到（这三条 note-variant 已按 isNote 做完，标题便签自动继承，本片只补回归测试）。
样稿：100% 时标题 18–20px 一行；缩到 40% 时标题画成 12px 屏幕字号，旁边正文便签是 22×18 的图标块。样稿里标题下方那条 accent 细线是标注线，不是界面元素。
设计缺口：①标题便签被选中 / 悬停时长什么样没画；②标题为空时显示什么没画；③从标题切回正文后原来的底色是否恢复没写；④a11y「界面字号」档位对画布内标题是否生效没写。处理见「行为规则」。

## 允许改的文件
- `lib/theme/typography.dart`：InkTypography 加 `noteBody`（12 / 400 / 行高 1.55）与 `noteHeading`（20 / 500 / 行高 1.3）两档；构造、`defaults`、`all`、`scaled` 同步。
- `lib/features/canvas/models/canvas_node_note_style.dart`（新建）：`NoteStyle` 枚举 + `CanvasNode` 的 extension `noteStyle` / `isHeadingNote`。
- `lib/features/canvas/util/note_geometry.dart`（新建）：标题便签的尺寸测量、反向缩放系数、`nodeRenderSize`。
- `lib/features/canvas/providers/heading_note_zoom.dart`（新建）：按画布的反向缩放系数 provider（只在系数变化时通知）。
- `lib/features/canvas/util/viewport_focus.dart`：`nodeStageRect` 末行 `drawn.position & kNodeCardSize` 改为 `drawn.position & nodeRenderSize(node, scale: scaleOf(transform))`（viewport_fit 的 nodesStageBounds、left_rail_actions、canvas_tool_actions 的 _fitNodes 都经它，自动生效）。
- `lib/features/canvas/util/drop_placement.dart`：仅 `topmostNodeAt`（f64f56e 第 191–196 行；W4 stage-drop-target 在同文件追加了 `stagePaintOrder` / `resolveStageDrop`，行号以 main 为准）把 `kNodeCardSize` 换成按节点算的尺寸（签名加 `double scale = 1`）。
- `lib/features/canvas/widgets/node_card.dart`（热点链 W16 归本片）：便签分支按 `noteStyle` 画两种体；标题体不收缩略、不画底色 / 边框 / 状态行 / 继承行；外框尺寸改读 `nodeRenderSize`。
- `lib/features/canvas/widgets/text_node_inspector.dart`：便签时在正文框上方加「正文 | 标题」分段切换；标题时隐藏底色选择行。
- `lib/features/canvas/widgets/node_inline_text_editor.dart`（由 text-inline-edit 新建，W15）：只改文字样式——标题便签用 noteHeading、最宽 480。
- （不改）`lib/features/canvas/util/selection_geometry.dart`：multi-select-core 的 `marqueeHits` / `selectionBounds` 已经走 `nodeStageRect`，改了 nodeStageRect 就自动生效。
- 测试：`test/theme/typography_test.dart`（第 40 行 11 → 13，加两档断言）、`test/features/canvas/util/note_geometry_test.dart`（新建）、`test/features/canvas/widgets/node_card_note_style_test.dart`（新建）、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/canvas/util/viewport_focus_test.dart`、`test/features/canvas/util/drop_placement_test.dart`。

## 不许碰的文件
- 同波 template-core：`lib/features/templates/**`、`lib/features/canvas/providers/canvas_bootstrap_controller.dart`、`test/features/templates/**`。
- 同波 toast-corner：`lib/features/notifications/widgets/toast_layer.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`、`test/features/notifications/widgets/toast_layer_test.dart`（`lib/theme/tokens.dart` 只许追加常量，本片不需要）。
- 同波 assets-gallery-import-origin：`lib/features/canvas/widgets/left_rail/assets_model.dart`、`assets_panel.dart`、`lib/features/gallery/**`。
- 同波 export-one-click：`lib/theme/components/ink_split_button.dart`、`lib/features/export/**`、`lib/features/shell/widgets/shell_tab_bar.dart`、`lib/features/shell/widgets/tabs/export_tab.dart`、`lib/features/command_palette/command_actions.dart`。
- 其它：`lib/features/canvas/models/canvas_node.dart`（freezed / 手写模型不改，`kNodeCardSize` 不改）、`canvas_compact_cards.dart`（阈值复用，不改）、`edge_geometry.dart`（便签没有端口，连线锚点不涉及标题便签）、`outline_model.dart`、`generation_controller.dart`（排除便签已由 note-variant 做完）、`node_position.dart`（新建便签恒为正文，默认尺寸不变）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W16 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - template-core：`lib/features/canvas/models/commands/insert_template_command.dart`、`lib/features/canvas/providers/canvas_bootstrap_controller.dart`、`lib/features/templates/builtin_templates.dart`、`lib/features/templates/models/canvas_template.dart`、`lib/features/templates/providers/template_insert_controller.dart`、`lib/features/templates/util/builtin_template_strings.dart`、`lib/features/templates/util/template_capture.dart`、`lib/features/templates/util/template_remap.dart`、`lib/features/templates/util/template_writer.dart`、`test/features/templates/builtin_templates_test.dart`、`test/features/templates/providers/template_insert_controller_test.dart`、`test/features/templates/util/template_capture_test.dart`、`test/features/templates/util/template_remap_test.dart`
  - toast-corner：`lib/core/models/app_preferences.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/util/toast_placement.dart`、`lib/features/notifications/widgets/toast_layer.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/notifications/util/toast_placement_test.dart`、`test/features/notifications/widgets/toast_layer_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
  - assets-gallery-import-origin：`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_model.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_tile.dart`、`lib/features/gallery/widgets/imported_badge.dart`、`test/features/canvas/widgets/left_rail/asset_captions_test.dart`、`test/features/canvas/widgets/left_rail/assets_model_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/gallery/providers/gallery_filter_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/gallery/widgets/gallery_tile_test.dart`
  - export-one-click：`lib/features/export/open_export_dialog.dart`、`lib/features/export/providers/one_click_export_controller.dart`、`lib/features/export/util/export_file_name.dart`、`lib/features/export/util/last_export_settings.dart`、`lib/features/export/util/one_click_export_plan.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/shell/widgets/shell_tab_bar.dart`、`lib/theme/components/ink_split_button.dart`、`test/features/export/providers/one_click_export_controller_test.dart`、`test/features/export/util/export_file_name_test.dart`、`test/features/export/util/last_export_settings_test.dart`、`test/features/export/util/one_click_export_plan_test.dart`、`test/features/export/widgets/export_video_dialog_test.dart`、`test/features/shell/shell_tab_bar_test.dart`、`test/theme/components/ink_split_button_test.dart`

## 具体改动
```dart
// canvas_node_note_style.dart
const String kNoteStyleKey = 'note_style';
enum NoteStyle { body, heading }            // 持久化值 = name
extension CanvasNodeNoteStyle on CanvasNode {
  NoteStyle get noteStyle;                  // 非便签恒 body；缺键 / 未知值 → body
  bool get isHeadingNote;                   // isNote && noteStyle == heading
}

// note_geometry.dart
const double kHeadingNoteMaxWidth = 480;     // 世界坐标，含内边距
const double kHeadingNotePadding = InkSpacing.xs;
const double kHeadingNoteMinWidth = 120;     // 空标题时的可点区域
final InkTypography kWorldTypography = InkTypography.defaults(); // 世界坐标测量用，不吃界面字号档位
double headingNoteZoomFactor(double scale);  // scale >= kCompactCardScale ? 1 : kCompactCardScale / scale
Size headingNoteBaseSize(String text);       // TextPainter(noteHeading, maxWidth 480-2*pad) + 内边距；空文本 = 最小宽 × 一行高
Size nodeRenderSize(CanvasNode node, {double scale = 1}); // 标题便签 = base × factor(scale)；其余 kNodeCardSize

// heading_note_zoom.dart
final headingNoteZoomProvider = AutoDisposeNotifierProviderFamily<HeadingNoteZoom, double, String>(...);
// 照 CanvasCompactCards 写法：监听 canvasTransformControllerProvider(canvasId)，值变才发；>= 0.6 时恒 1.0，不逐帧通知。
```
- node_card：`isHeadingNote` 时整卡 = `SizedBox(nodeRenderSize(node, scale))` 里一个 `FittedBox(fit: BoxFit.fill)`，子级是 `SizedBox(headingNoteBaseSize)` + `Padding(kHeadingNotePadding)` + `Text(textContent, style: kWorldTypography.noteHeading.copyWith(color: fg1))`（只换颜色，不改字号）。只有标题便签 watch `headingNoteZoomProvider`。正文便签分支沿用 note-variant 的写法，正文样式改读 `context.inkTypography.noteBody`。
- text_node_inspector：便签时在 `InspectorGroup` 第一行加分段切换（用 Material `SegmentedButton<NoteStyle>`，先例见 `lib/features/storyboard/widgets/script_import_dialog.dart:114`）；点选 → `_submitCtrl.saveConfig({kNoteStyleKey: style.name})`，写完 `ref.invalidate(canvasNodesControllerProvider(canvasId))`（与 `_commitAndRefresh` 同一做法）。测试锚点 `TextNodeInspector.noteStyleKey = Key('inspector.note.style')`。

## 行为规则与边界情况
1. 缺 `note_style` 或值不认识 ⇒ 正文；非便签的文本节点即使带了这个键也按普通文本画。
2. 标题便签：无底色、无边框、无标题行 / 状态行 / 继承行、无端口；文字 fg1、20 / 500 / 1.3，宽度 = 最长一行 + 2×xs，最宽 480，超出换行，不截断、不限行数。
3. 选中（缺口①）：在文字盒外画 1px accent 描边、圆角 sm（同卡片图区描边写法，画在盒外不占布局）；悬停不画东西，光标仍是 grab。
4. 空标题（缺口②）：盒宽 120、一行高，文字画 `canvasNoteHeadingEmpty`（fg5）；占位字不进测量。
5. 缩放 ≥ 0.6：系数 1，屏幕字号 = 20 × 缩放；缩放 < 0.6：系数 = 0.6 / 缩放，屏幕字号恒为 12，盒子同比放大，换行位置不变（先按 base 排版再整体缩放）。
6. 缩放 < 0.6 时正文便签收成图标（与 config 卡同一个 `canvasCompactCardsProvider` 判据）；标题便签永远不收。
7. 适应全部 / 适应选中、左栏「定位」、新建菜单落点判卡、框选命中：都按规则 2–5 的真实盒子算（nodeStageRect 是唯一入口）。适应视口的二分仍成立：盒宽 × 缩放 = base × max(缩放, 0.6) 随缩放单调不减。
8. 切换「正文 | 标题」立即落库（不走 500ms 防抖），失败走 InspectorSubmitController 现有的「未保存 · 重试」行；切换不改 `text`、不改底色值。切回正文后原来的底色照旧（缺口③：底色键保留不删）。标题时检查器不显示底色行。
9. 撤销：切换走 `saveConfig`；若 undo-params（W5）已让检查器写入进栈，则一次切换 = 一步撤销，撤销后卡片回到原样式；本片不另造撤销命令。
10. 就地编辑（双击）标题便签时编辑器用 noteHeading、最宽 480；失焦后盒子按新文字重新测量。
11. 界面字号档位（缺口④）：标题便签是世界坐标里的内容，测量与绘制都用 `kWorldTypography`（档位 1.0），保证命中盒与字一致；画布缩放本身负责「看得清」。在 typography.dart 头注与 note_geometry 头注里写明这个例外。
12. 标题便签不进大纲、不进提示词、查找能搜到——note-variant 的 isNote 判据覆盖，本片只加回归测试。
13. mac / Windows 无差异（字体回落链不同导致宽度差几像素，测量与绘制同一 TextPainter 规则，自洽）。

## 新文案键
| key | en | zh |
|---|---|---|
| inspectorNoteStyleLabel | Style | 样式 |
| inspectorNoteStyleBody | Body | 正文 |
| inspectorNoteStyleHeading | Heading | 标题 |
| canvasNoteHeadingEmpty | Empty heading | 空标题 |

## 测试
先写，确认在没实现时红。
- `test/theme/typography_test.dart`：`all 列出全部 13 档`（含 noteBody / noteHeading）；`noteBody = 12/400/1.55，noteHeading = 20/500/1.3`；`scaled(1.5) 后 noteHeading 字号 30`。
- `test/features/canvas/util/note_geometry_test.dart`（新建）：
  - `缺键 / 未知值 ⇒ body；非便签带 heading 也不是标题便签`。
  - `headingNoteZoomFactor：1.0→1，0.6→1，0.3→2，0.1→6`。
  - `短标题宽度跟字走（< 480），长标题封顶 480 并换成多行（高 > 一行）`。
  - `空标题 = 最小宽 120 × 一行高`。
  - `nodeRenderSize：正文便签 / config / result 恒为 kNodeCardSize；标题便签在 0.3 缩放下 = base × 2`。
- `test/features/canvas/util/viewport_focus_test.dart`：`nodeStageRect 对标题便签返回测量盒（不是 224×191）`；`缩放 0.3 时盒子按 0.6/0.3 放大`。
- `test/features/canvas/util/drop_placement_test.dart`：`topmostNodeAt：点在短标题便签右侧 224 宽以内、但在文字盒外 ⇒ 不算落在它上面`。
- `test/features/canvas/widgets/node_card_note_style_test.dart`（新建）：
  - `标题便签：无底色 DecoratedBox、无端口、无状态行，卡片 RenderBox 尺寸 = nodeRenderSize`。
  - `缩放 0.4：正文便签出 compactGlyphKey，标题便签不出、文字仍在`。
  - `缩放 0.4：标题文字的屏幕字号（fontSize × 缩放 × FittedBox 系数）= 12`。
  - `选中标题便签画 accent 描边`；`空标题画「空标题」占位`。
  - `标题便签不进大纲`：buildCanvasOutline 结果里没有它（util/outline_model.dart:149）。
- `test/features/canvas/widgets/text_node_inspector_test.dart`：`便签显示「正文 | 标题」切换，普通文本不显示`；`点「标题」→ 立即写 type_config.note_style=heading 并重载节点表（不等防抖）`；`标题时底色行不出现，切回正文底色值未变`。

## 变异点
1. `headingNoteZoomFactor` 改成恒 `1` → 由 `headingNoteZoomFactor：…0.3→2` 与 `缩放 0.4：标题文字的屏幕字号 = 12` 抓住。
2. `nodeStageRect` 改回 `& kNodeCardSize` → 由 `nodeStageRect 对标题便签返回测量盒` 抓住。
3. node_card 标题分支去掉 `isHeadingNote` 判断（标题按正文画）→ 由 `标题便签：无底色…尺寸 = nodeRenderSize` 抓住。
4. 标题便签也读 compact 收图标 → 由 `缩放 0.4：…标题便签不出` 抓住。
5. `noteStyle` 对未知值返回 heading → 由 `缺键 / 未知值 ⇒ body` 抓住。
6. 检查器切换改走 `saveDebounced` → 由 `点「标题」→ 立即写…（不等防抖）` 抓住。
7. `topmostNodeAt` 改回 `& kNodeCardSize` → 由 `topmostNodeAt：点在短标题便签右侧…` 抓住。
8. `kHeadingNoteMaxWidth` 封顶去掉 → 由 `长标题封顶 480 并换成多行` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/theme test/features/canvas --exclude-tags golden` 与上面的变异。
- 截图（widget test 截图或 golden 场景，CI 出图）：`NodeCard` 放在 ProviderScope 里，数据 = 一张正文便签（「第二场改成黄昏？问导演」，默认底色）+ 一张标题便签（「第一场 · 拂晓出港」）+ 一张 60 字长标题；状态：① 100% 未选中；② 100% 标题便签选中；③ 缩放 0.4（正文便签图标、标题 12px）；④ `TextNodeInspector` 便签态分别选中「正文」与「标题」。

## 风险与不确定
- note-variant 的 extension 文件名、便签卡体在 node_card 里的结构、底色选择行的写法都由 W14 决定，执行前先读 main 上的实现再插分支；若 note-variant 已让正文便签收图标，规则 6 只需回归测试。
- 用 `kWorldTypography`（档位 1.0）测量和绘制标题，是对 typography.dart「不要绕过 a11y 缩放」的有意例外；若主 Agent 不接受，备选是标题便签用固定宽 480 换行（slices 注里说的降到 M 的方案），但会和画板「宽度跟字走」冲突。
- `heading_note_zoom` 在缩放 < 0.6 时每帧都会变值，只有标题便签订阅；画布上标题便签很多时有重建开销，验收时看一下 100 张标题便签缩放的帧耗时。
- 仓库里还有别的 `kNodeCardSize` 用处（result_placement、canvas_bootstrap、node_menu_model 第 161 行、drop_placement 第 91 / 173 行、W17 小地图）表示「新卡默认尺寸 / 换道判据」，本片不动；执行时 grep 一遍，若发现别的「已存在节点的渲染矩形」用处，不要改，列进回报。
