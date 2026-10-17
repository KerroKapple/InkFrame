# rail-templates-page · 左栏模板页（内置）：示意卡 + 悬停展开「插入当前画布 / 用它新建画布」；新建菜单与「更多」加「从模板插入…」
- 波次：W17；lane：A；基底：origin/main（W16 全部合入后）
- 依赖切片：
  - 硬依赖 template-core（W16）：`lib/features/templates/**` 的模型、`builtinTemplates`、`builtinTemplateStringsOf`、`templateInsertControllerProvider`、`templateCanvasCreatorProvider`、`TemplateInsertResult.historyStepId`——已在 main。
  - 硬依赖 rail-script-panel（W12）：`LeftRailPage.script` 与导航条「剧本」键已在 main；本片改的三个左栏文件排在它之后。
  - 已在 main 的地基：menu-split（W0，`canvas_menu/` 目录、theme 层 `InkMenuPanel` / `InkMenuEntry`、`create_menu_entries.dart` 的 `createMenuEntry` / `buildCreateMenuGroups` / `runCreateMenuPick`）、app-action-table（W1，`lib/features/canvas/util/more_menu_model.dart` 的 `kMoreMenuActionIds`——「更多」已由它驱动，`_MoreAction` 枚举在 W1 就删了）、canvas-capsule（W1，画布胶囊）、undo-stack（W0，`undoSpecific`）、app-action-table（W1）、create-menu-pick-recent（W13，新建菜单的项类型）、help-actions（W3，导航条帮助键）。
- 阻塞决定：无（RailScript-R7 按建议 B：节点库将来并进本页顶部，导航条不加节点库键；R6 按建议 A）

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
左栏导航条在「剧本」下面多一个「模板」键，点开是 241 宽的模板页：三张内置模板卡（三幕短片 / 单镜试拍 · 图生视频 / 短剧示例），每张带按节点位置画的缩略示意。
鼠标悬停（或键盘聚焦）一张卡，卡片展开两个按钮「插入当前画布」「用它新建画布」和一行计数。插入后新节点全部选中，画布底部胶囊出「已插入「三幕短片」· 12 个节点 · 撤销」。
Tab 新建菜单（不带连线上下文时）末尾、工具条「更多」里、⌘K 里都多一项「从模板插入…」，点了展开左栏并停在模板页。

## 设计依据
画板 `RailScript.dc.html`（文本版 boards/RailScript.txt，生成器 b2_rail.js 第 145–200 行）：
- 导航条：`LeftRailPage` 加 script / templates，声明序 = 从上到下；模板键标「顶部含节点库（R7）」；点当前页收起、Ctrl \ 开合、记住停在哪页都不变。
- 「模板 · 开局用的镜头链」面板：面板头「模板」，右侧「存为模板…」（属 my-templates-table，本片不画）；「内置 3 | 我的 1」分段（本片只有内置，不画分段，见设计缺口）。
- 卡片：外边距 0 8 6、内边距 8、圆角 4；左 64×40 示意图（surface1 底、1px outline 描边、圆角 3；泳道画成横贯的色带，取泳道底色、不透明度 0.16；每个节点画 8×6、圆角 1 的 fg5 小方块）；右侧名称（fg2，悬停 fg1，单行省略）+ 副标题（10 号 fg5）：「9 镜 · 3 泳道」「1 镜 · 图像 → 视频」。
- 悬停态：surface5 底 + 1px control 描边；下方两个等宽按钮（24 高、间距 6、上边距 8）：左「插入当前画布」琥珀主按钮，右「用它新建画布」controlStrong 描边次按钮；再下一行 10 号 fg6 计数「12 节点 · 9 镜 · 3 泳道 · 11 条线 · 不含产物」（上边距 6）。
- 规则：插入 = 新 id、整体移到视口中心、单事务、插完选中全部 + 撤销通知；用它新建画布 = 建画布 + 插入 + 打开；示意图按节点位置缩略画，不截图；Tab 新建菜单和工具条「更多」里加「从模板插入…」，打开这一页。
`GapsCanvas.dc.html`「更多」下拉：顺序固定 导入 | 叙事链 | 模板 | 切线 | 视图；每项也进 ⌘K 动作表。
`UndoClipboard.dc.html`：反馈只走画布底部胶囊；卡片上「撤销」撤卡上这一步（Q1-A）。
设计缺口：①只有内置时分段控件画不画——本片不画，W19 my-templates-table 加；②卡片本体单击做什么——本片不做任何事（只悬停 / 聚焦展开），避免误插；③「用它新建画布」之后左栏停在哪页——不动 `leftRailProvider`；④插入进行中的卡片态——两个按钮置灰，不加转圈；⑤键盘怎么展开——卡片可聚焦，聚焦即展开，Tab 进按钮。

## 允许改的文件
- `lib/features/canvas/providers/left_rail_state.dart`：`LeftRailPage` 在 `script` 之后追加 `templates`（头注「页只有三张」一并改正）。
- `lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`：剧本键之后加 `pageKey(LeftRailPage.templates, InkGlyph.templates, l.leftRailTemplates)`；头注同步。
- `lib/features/canvas/widgets/left_rail/left_rail_panel.dart`：switch 加 `LeftRailPage.templates => TemplatesPanel(canvasId: canvasId)`。
- `lib/features/canvas/widgets/left_rail/templates_panel.dart`（新建）：面板头 + 内置卡列表；留出顶部插槽给 W18 节点库（见具体改动）。
- `lib/features/canvas/widgets/left_rail/template_card.dart`（新建）：一张卡的呈现 + 悬停 / 聚焦展开。
- `lib/features/templates/widgets/template_thumbnail_painter.dart`（新建）：`CustomPainter` + 纯几何函数。
- `lib/features/templates/util/template_ui_actions.dart`（新建）：`openTemplatesPage` / `insertTemplateWithFeedback` / `createCanvasFromTemplateAndOpen` 三个带 context 的动作。
- `lib/features/canvas/util/create_menu_model.dart`：加「从模板插入…」项与独立分组（W17 本链归本片）。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（menu-split 建，W0）：`createMenuEntry` 加一臂（呈现）+ `runCreateMenuPick` 加一个 case（派发）。
- `lib/features/canvas/util/more_menu_model.dart`（app-action-table 建，W1；注册表）：`kMoreMenuActionIds` 只追加一行 `AppActionIds.insertFromTemplate`。**不改** `canvas_toolbar.dart`：W1 起「更多」按 `kMoreMenuActionIds` 逐个取 `appActionById(id)` 画项。
- `lib/features/app_actions/app_action_catalog.dart`（app-action-table 建，W1）：追加一行；`lib/features/app_actions/app_action_ids.dart` 追加常量 `insertFromTemplate`（与 catalog 同算注册表例外）。
- `test/features/canvas/widgets/left_rail/templates_panel_test.dart`（新建）
- `test/features/templates/widgets/template_thumbnail_painter_test.dart`（新建）
- `test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`：各加用例。

## 不许碰的文件
- 同波：`lib/features/storyboard/**`、`core/interfaces/script_repository.dart`、`storage/repositories/postgres_script_repository.dart`、`left_rail/script_panel.dart`（script-reimport-diff）；`widgets/canvas_minimap.dart`、`util/minimap_geometry.dart`、`providers/minimap_visible.dart`、`widgets/canvas_zoom_bar.dart`、`widgets/canvas_screen.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`（canvas-minimap）；`widgets/canvas_view.dart` 与 `stage_*`、`providers/edge_cut_controller.dart`、`util/edge_cut_hit.dart`、`widgets/edge_cut_painter.dart`、`canvas_cut_actions.dart`、`widgets/canvas_shortcuts.dart` 与 `shortcuts/**`（cm-knife-cut / canvas-minimap）；`settings/util/shortcut_catalog.dart`、`settings/util/pointer_gesture_catalog.dart`、`settings/widgets/shortcuts_section.dart`、`widgets/create_node_menu.dart`、`command_palette/widgets/command_palette_dialog.dart`、`widgets/batch_compare_overlay.dart`、`gallery/widgets/gallery_grid.dart`（shortcuts-page-v2）。
- 热点：`canvas_tool_actions.dart`、`canvas_menu_host`、`canvas_nodes_controller.dart`、`lib/features/templates/` 下 template-core 已建的文件（只调用）、`lib/features/studio/open_canvas.dart`（不需要改，见风险 3）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W17 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - script-reimport-diff：`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/providers/script_reimport_controller.dart`、`lib/features/storyboard/util/script_diff.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`lib/features/storyboard/widgets/script_reimport_preview.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/providers/script_reimport_controller_test.dart`、`test/features/storyboard/util/script_diff_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
  - canvas-minimap：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/minimap_visible.dart`、`lib/features/canvas/util/minimap_geometry.dart`、`lib/features/canvas/widgets/canvas_capsule_host.dart`、`lib/features/canvas/widgets/canvas_minimap.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/canvas_zoom_bar.dart`、`lib/features/canvas/widgets/shortcuts/minimap_keys.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/minimap_visible_test.dart`、`test/features/canvas/util/minimap_geometry_test.dart`、`test/features/canvas/widgets/canvas_minimap_test.dart`、`test/features/canvas/widgets/canvas_screen_layout_test.dart`、`test/features/canvas/widgets/canvas_zoom_bar_test.dart`、`test/services/file_preferences_service_test.dart`
  - cm-knife-cut：`lib/features/canvas/models/commands/cut_edges_command.dart`、`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/util/canvas_cut_actions.dart`、`lib/features/canvas/util/edge_cut_hit.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/widgets/edge_cut_painter.dart`、`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`test/features/canvas/models/commands/cut_edges_command_test.dart`、`test/features/canvas/providers/edge_cut_controller_test.dart`、`test/features/canvas/util/edge_cut_hit_test.dart`、`test/features/canvas/widgets/canvas_knife_cut_test.dart`
  - shortcuts-page-v2：`lib/features/settings/util/overlay_key_catalog.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/settings/overlay_key_catalog_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/shortcut_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`

## 具体改动
```dart
// left_rail_state.dart
enum LeftRailPage { outline, assets, characters, script, templates }

// templates_panel.dart
class TemplatesPanel extends ConsumerStatefulWidget { const TemplatesPanel({super.key, required this.canvasId}); final String canvasId;
  static Key cardKeyOf(String templateId); static Key insertKeyOf(String templateId); static Key newCanvasKeyOf(String templateId); }
// 结构：Column[ LeftPanelHeader(title: l.leftRailTemplates), Expanded(ListView[ ...内置卡 ]) ]。
// ListView 第一项前留一行注释「W18 node-library-section 在此插入 NodeLibrarySection」，本片不放任何占位 widget。
// 内置列表 = builtinTemplates(builtinTemplateStringsOf(l), sampleSeedOf(l))，在 build 里按当前语言算。
// 面板级 _busy：任一卡的插入 / 新建在进行中时为真，全部按钮置灰。

// template_card.dart
class TemplateCard extends StatefulWidget { const TemplateCard({super.key, required this.template, required this.busy,
  required this.onInsert, required this.onNewCanvas}); }   // onNewCanvas 为 null ⇒ 按钮置灰（没有活动项目）
String templateSubtitle(AppLocalizations l, CanvasTemplate t);  // 「{shots} 镜 · {lanes} 泳道」；t.tagline != null ⇒ 「{shots} 镜 · {tagline}」
String templateCountsLine(AppLocalizations l, TemplateCounts c); // 「12 节点 · 9 镜 · 3 泳道 · 11 条线 · 不含产物」，各段 ARB、' · ' 连接

// template_thumbnail_painter.dart
const Size kTemplateThumbnailSize = Size(64, 40);
@immutable class TemplateThumbnailGeometry { final List<({Rect rect, String? tintColor})> lanes; final List<Rect> nodes; }
TemplateThumbnailGeometry templateThumbnailGeometry(CanvasTemplatePayload payload, {Size size = kTemplateThumbnailSize, double padding = 3});
class TemplateThumbnailPainter extends CustomPainter { TemplateThumbnailPainter({required this.geometry, required this.nodeColor, required this.laneColorOf}); }

// template_ui_actions.dart
void openTemplatesPage(WidgetRef ref);   // ref.read(leftRailProvider.notifier).open(LeftRailPage.templates)
Future<void> insertTemplateWithFeedback(BuildContext context, WidgetRef ref, {required String canvasId, required CanvasTemplate template});
Future<void> createCanvasFromTemplateAndOpen(BuildContext context, WidgetRef ref, {required String projectId, required CanvasTemplate template});
```
- 几何：payload 坐标按「主轴 → x、横截 → y」画（不管来源画布方向），道按顺序堆叠、厚度按 size 比例；先算全部卡（每张按 `kNodeCardSize` 折算）与道的包围盒，等比缩放进 `size - 2·padding` 并居中；节点小方块固定 8×6（不随缩放），中心落在卡中心的缩放位置。空 payload ⇒ 两个空列表（只画底框）。
- 颜色：节点 `inkColors.fg5`；道底色走泳道背景同一个解析（`lane_tint.dart` / `lane_background.dart` 里把 tintColor 解析成 Color 的那个函数；tintColor 为 null 时用 `inferTintHex(stylePrompt)`，仍为 null 用 `inkColors.surface5`），再乘 0.16 不透明度。
- `insertTemplateWithFeedback`：await 之前取好文案、胶囊控制器、`templateInsertControllerProvider(canvasId)`；成功 ⇒ 画布胶囊（`canvasCapsuleProvider(canvasId).notifier.show(CanvasCapsuleMessage(kind: CanvasCapsuleKind.action, …))`）显示 `templatesInserted(name, count)` + 动作「撤销」（`commonUndo`）→ `ref.read(canvasHistoryControllerProvider(canvasId).notifier).undoSpecific(result.historyStepId!)`（historyStepId 为 null 的空模板不出胶囊）；`InkError` ⇒ `showCanvasSnack(context, l.templatesInsertFailed)`。
- `createCanvasFromTemplateAndOpen`：调 `templateCanvasCreatorProvider.createCanvasFromTemplate`，成功后 `shellControllerProvider.notifier.openCanvas(newId)`（同项目，不带 withProject，与 canvas_switcher.dart:160 一致）；`InkError` ⇒ toast 错误卡 `templatesNewCanvasFailed`（`toastServiceProvider`，`ToastKind.error`）。
- 新建菜单：`create_menu_model.dart` 新增独立分组常量 `kTemplateCreateActions`（只含「从模板插入…」一项），**不放进 `kPlainCreateActions`**（W18 节点库读那六项）。W13 create-menu-pick-recent 之后 `createMenuGroups` 返回 `List<List<CreateMenuPick>>`，`CreateMenuAction` 枚举保留为 `CreateMenuActionPick` 的载荷：本片给枚举加 `CreateMenuAction.insertTemplate`，`kTemplateCreateActions = <CreateMenuAction>[CreateMenuAction.insertTemplate]`，不带上下文时在**最后**追加一组 `kTemplateCreateActions.map(CreateMenuActionPick.new)`——即 `[六种建节点, 最近用过（有才出）, 从模板插入]`。`createdNodeType` / `createdEdge` 对它返回 null、note-variant 的 `createdTypeConfig` 返回 `const {}`；各处对 `CreateMenuAction` 的穷举 switch 补一臂。带连线上下文的菜单不出这一项。
- 条目：图标 `InkGlyph.templates`、文案 `canvasInsertFromTemplate`、无键位；派发 = `openTemplatesPage(ref)`（菜单照常关闭、焦点按现有规则还给画布）。
- 「更多」：`kMoreMenuActionIds` 追加 `AppActionIds.insertFromTemplate`（执行体就是下面 ⌘K 那一行的 run = `openTemplatesPage`）；分组与分隔线由 W18 more-dropdown-panel 统一做，本片只追加这一行。
- ⌘K：`app_action_catalog` 追加一行（id `insertFromTemplate`，文案 `canvasInsertFromTemplate`，无键位，可用 = 当前标签是画布且有 canvasId，不可用原因沿用表里「需要打开画布」那类现成文案；执行 = `openTemplatesPage`）。表里若已有登记成禁用的同名行，改那一行，不新增。

## 行为规则与边界情况
1. 导航条键序：大纲 · 素材 · 角色 · 剧本 · 模板，Spacer 之后帮助 / 快捷键 / 收起不变；点亮规则同其它页（`isActive`）。
2. 点「模板」键：未在本页 ⇒ 展开并切页；已在本页且展开 ⇒ 收起；Ctrl \ / ⌘\ 开合时停在模板页。
3. 卡片未悬停、未聚焦：只画示意图 + 名称 + 副标题，不画按钮与计数。
4. 鼠标进入卡片或卡片 / 其内按钮持有焦点 ⇒ 展开；两者都没有 ⇒ 收起；同一时刻最多一张展开（鼠标在 A、焦点在 B 时两张都展开可以接受，不做互斥）。
5. 「插入当前画布」：插入成功后新节点全部选中，胶囊文案带模板名与节点数；胶囊「撤销」撤的就是这一步（其他步不受影响）。
6. 插入失败（任一写入抛 InkError）：画布不变、选中不变、出错误卡「插入模板失败」，按钮恢复可点。
7. 进行中再点任何卡的任何按钮：无反应（按钮已置灰）；完成或失败后恢复。
8. 「用它新建画布」：没有活动项目（`activeProjectProvider` 为 null）⇒ 按钮置灰；成功后新画布被打开，画布名 = 模板名，画布切换胶囊里看得到它；失败 ⇒ 错误通知，不切画布。
9. 新建菜单：不带上下文 ⇒ 六种建节点 |（最近用过，有才出）| 从模板插入…，组间分隔线；从模板插入恒为最后一组；搜索「模板」只剩这一组；带上下文的菜单（拖线 / 有源）不出现这一项。
10. 「更多」与 ⌘K 的「从模板插入…」只开左栏并切到模板页，不插入任何东西；左栏原来收着也会展开。
11. 语言切换后内置模板名、三幕道名、镜头名随之变化（每次 build 按当前语言算），已插入画布的节点不受影响。
12. 示意图：三幕短片画 3 条色带 + 12 个小方块；单镜试拍 0 条带 + 2 个方块；空 payload 只画底框。
13. mac / Windows 无差异（没有新键）。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailTemplates | Templates | 模板 |
| templatesInsertIntoCanvas | Insert into canvas | 插入当前画布 |
| templatesNewCanvas | New canvas from template | 用它新建画布 |
| templatesMetaShots | {count, plural, =1{1 shot} other{{count} shots}} | {count} 镜 |
| templatesMetaLanes | {count, plural, =1{1 lane} other{{count} lanes}} | {count} 泳道 |
| templatesMetaNodes | {count, plural, =1{1 node} other{{count} nodes}} | {count} 节点 |
| templatesMetaEdges | {count, plural, =1{1 link} other{{count} links}} | {count} 条线 |
| templatesMetaNoOutputs | no outputs | 不含产物 |
| templatesInserted | Inserted “{name}” · {count, plural, =1{1 node} other{{count} nodes}} | 已插入「{name}」· {count} 个节点 |
| templatesInsertFailed | Couldn't insert template | 插入模板失败 |
| templatesNewCanvasFailed | Couldn't create a canvas from the template | 用模板新建画布失败 |
| canvasInsertFromTemplate | Insert from template… | 从模板插入… |

## 测试
先写会失败的用例。
- `test/features/canvas/providers/left_rail_state_test.dart`：`LeftRailPage 声明序 = 导航条顺序，templates 在 script 之后`。
- `test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`：`模板键点亮并打开模板页，再点收起`（`CanvasLeftRail.keyOf('templates')`，断言 `find.byType(TemplatesPanel)`）。
- `test/features/canvas/widgets/left_rail/templates_panel_test.dart`（外壳级 pump，照 canvas_left_rail_test 的 `pumpInkShell` + fake 控制器写法）
  - `列出三张内置卡，顺序 三幕短片 / 单镜试拍 / 短剧示例`；`副标题：9 镜 · 3 泳道、1 镜 · 图像 → 视频`。
  - `未悬停不画按钮；悬停后出现两个按钮与计数行`（`TestGesture` 移入卡片）。
  - `键盘 Tab 聚焦卡片也展开`。
  - `点插入当前画布：调用 insertIntoCanvas 一次，胶囊出现带撤销`（override `templateInsertControllerProvider` 为记录型 fake）。
  - `插入进行中按钮置灰，重复点击不再调用`（fake 返回未完成的 Completer）。
  - `插入失败出错误卡，按钮恢复`（`RecordingToastService`）。
  - `没有活动项目时用它新建画布置灰`；`新建成功后 openCanvas 到新画布`（读 shell 状态 canvasId）。
- `test/features/templates/widgets/template_thumbnail_painter_test.dart`
  - `三幕短片：3 条道、12 个节点方块，全部落在 64×40 内`；`主横轴固定：竖向来源的 payload 也画成横带`；`空 payload 返回空几何`；`节点方块恒为 8×6`。
- `test/features/canvas/util/create_menu_model_test.dart`
  - `不带上下文：最后一组只有从模板插入`；`带上下文：不出现从模板插入`；`kPlainCreateActions 不含从模板插入`；`从模板插入不建节点、不连线`。

## 变异点
1. `createMenuGroups(source: null)` 去掉 `kTemplateCreateActions` ⇒ `不带上下文：最后一组只有从模板插入` 红。
2. 把「从模板插入」塞进 `kPlainCreateActions` ⇒ `kPlainCreateActions 不含从模板插入` 红。
3. `TemplateCard` 展开条件去掉「有焦点」⇒ `键盘 Tab 聚焦卡片也展开` 红。
4. 面板 `_busy` 不置真 ⇒ `插入进行中按钮置灰，重复点击不再调用` 红。
5. 几何里不等比缩放（直接用世界坐标）⇒ `全部落在 64×40 内` 红。
6. 导航条模板键用 `LeftRailPage.script` ⇒ `模板键点亮并打开模板页，再点收起` 红。
7. `createCanvasFromTemplateAndOpen` 删掉 openCanvas ⇒ `新建成功后 openCanvas 到新画布` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/widgets/left_rail test/features/templates test/features/canvas/util/create_menu_model_test.dart test/features/canvas/providers/left_rail_state_test.dart`；逐条变异。
- 截图（screenshot 标签，照 `test/screenshots/studio_screenshot_test.dart` 的写法）：`InkShell` 停在画布标签、左栏模板页、默认 fake 画布（两节点），截三张：①未悬停的三张卡；②悬停三幕短片（展开两个按钮 + 计数行）；③Tab 新建菜单（不带上下文）显示两组、第二组「从模板插入…」。

## 风险与不确定
1. 新建菜单的项类型按 W13 create-menu-pick-recent 派工单（`CreateMenuActionPick(CreateMenuAction)`）写，派发在 menu-split 的 `runCreateMenuPick`（create_menu_entries.dart），不碰 `canvas_menu_host`；合入后的实际形状若不同，以 main 为准并在回报里说明。
2. 「更多」此时仍是 W1 的 Material `showMenu`（按 `kMoreMenuActionIds` 画）；W18 more-dropdown-panel 把 `kMoreMenuActionIds` 改成分组的 `kMoreMenuItems` 时会把本行一起搬过去（那片派工单已写明）。
3. slices.json 把「用它新建画布」放在 `open_canvas.dart`；本单改成由 template-core 的 `createCanvasFromTemplate`（事务）+ 本片的 `createCanvasFromTemplateAndOpen`（导航）完成，`open_canvas.dart` 的 `openProjectCanvas` 语义是「打开项目的第一张画布」，不适合复用，所以不碰。
4. 画布胶囊按 canvas-capsule 派工单：`ref.read(canvasCapsuleProvider(canvasId).notifier).show(CanvasCapsuleMessage(text: l.templatesInserted(name, count), kind: CanvasCapsuleKind.action, actionLabel: l.commonUndo, onAction: () => …undoSpecific(stepId)))`。
