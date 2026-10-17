# more-dropdown-panel · 工具条「更多」改用菜单面板

- 波次：W18；lane：A；基底：origin/main（W0–W17 已全部合入）
- 依赖切片：menu-split（W0，硬：theme 层菜单面板 + `CanvasMenuPopover`）；naming-shot-unify（W0，硬：「导入脚本」已改名「导入剧本」，`canvasAddImportScript` 文案已是「导入剧本…」）；app-action-table（W1，硬：动作表 `lib/features/app_actions/app_action_catalog.dart`）；cm-knife-cut（W17，软：`edge_cut_controller.dart` 已提供一次性模式 `arm()` / `disarm()`、武装时不按 Alt 拖空白即切、precise 光标、切完或 Esc 自动解除——见 briefs/cm-knife-cut.md 规则 12，本片只调用）；以及给「更多」供动作的 import-media-command（W3）、align-distribute-arrange（W8）、canvas-find-bar（W9）、tc-batch-run-dialog（W11）、rail-templates-page（W17）、canvas-minimap（W17）。执行本片时以上都已在 main 上。
- 阻塞决定：无（CM 的「切线手势」按 revise-summary 建议 A：Alt + 左键拖空白）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 点工具条最右的「更多」，弹出的不再是 Material 菜单，而是和右键菜单同一套的画布菜单面板：图标、键位提示、置灰、打勾，↑↓ / ↵ / Esc。
- 菜单里是一份固定分组的清单：导入 | 叙事链 | 模板 | 切线 | 视图，共 8 项；画布没有叙事链时「整理叙事链」「运行叙事链…」置灰。
- 新增「切线」一次性模式：点了以后在空白处直接左键拖（不用按 Alt）就能剪线，剪一次或按 Esc 就退出。

## 设计依据
画板 GapsCanvas.dc.html › 「『更多』下拉」（副标题「工具条最右，一份清单」）。样稿行序（含分隔线）：
`导入剧本…` · `导入媒体… Ctrl U` | `整理叙事链` · `运行叙事链…` | `从模板插入…` | `切线 Alt 拖` | `查找 Ctrl F` · `小地图 M ✓`。
规则原文：
1. 顺序固定：导入 | 叙事链 | 模板 | 切线 | 视图；每项也进 ⌘K 动作表和菜单栏。
2. 改用画布菜单组件 CanvasMenuPanel（键位、置灰说原因、↑↓ ↵ Esc，与右键同一套），不再用 Material showMenu。
3. 「导入脚本」改叫「导入剧本」，与左栏「剧本」页同名（naming-shot-unify 已改 ARB）。
4. 整理叙事链见 Selection，运行叙事链开 TakesCost 的运行对话框，从模板插入见 RailScript；画布没有链时前两项置灰。
5. 切线：点了进一次性切线模式（剪刀光标，拖过的线高亮，松手剪掉，Esc 退出）；平时 Alt 拖空白同效（W3）。
ContextMenus 板「停用 · 切线」：产出线划不断；平移工具下不生效；Esc 与「框选 / 切线进行中」同一级（菜单 > @ 弹层 > 查找条 > 框选 / 切线进行中 > 工具锁 > 清空选中）。
样稿图标：script / upload / sequence / run / templates / link / search / minimap（都在 `InkGlyph` 里）；小地图行尾是 accent 色的勾。
设计缺口：①菜单相对按钮怎么对齐、贴不下时往哪翻没画；②Flutter 没有系统「剪刀」光标，InkGlyph 也没有剪刀；③一次性模式开着时屏幕上有没有提示没画；④进了一次性模式后点空白（不拖）算什么没写；⑤置灰原因的文案没写。处理见「行为规则」。

## 允许改的文件
- `lib/features/canvas/widgets/canvas_toolbar.dart`（W18 归本片）：删 `_MoreAction`、`_showMoreMenu` 与 `showMenu`；「更多」键改为开 / 关 `CanvasMoreMenu`；头注第 13 行「更多：小菜单，目前只有『导入脚本…』」改写。把前序切片内联在 `_showMoreMenu` 里的项（导入媒体、运行叙事链、从模板插入等，以 main 上实际为准）全部迁进 more_menu_model，不留第二份。
- `lib/features/canvas/widgets/canvas_more_menu.dart`（新建）：更多菜单宿主：Popover 定位、把 more_menu_model 的项转成面板条目、执行、关闭后焦点交还。
- `lib/features/canvas/util/more_menu_model.dart`：按「具体改动」的形状。**先查 main**：没有这个文件（slices.json 里只有本片列了它）⇒ 本片新建；已有（某个前序切片按 plan 第 0 节当注册表建过）⇒ 保留其中已有的行，只补齐分组枚举 / 缺的行，并把渲染改到面板上。
- `lib/features/app_actions/app_action_catalog.dart`（注册表，只追加）：追加「切线（一次性）」一行；8 项里在表中找不到的其它动作也在表尾同一处连续追加（见「具体改动」第 3 条），不改已有行。
- 测试：`test/features/canvas/util/more_menu_model_test.dart`（新建）、`test/features/canvas/widgets/canvas_toolbar_test.dart`（第 307 行「更多 → 导入脚本…」用例改写）、`test/features/canvas/widgets/canvas_more_menu_test.dart`（新建）。

## 不许碰的文件
- 同波 create-menu-notes-characters：`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/theme/components/ink_menu_panel.dart`（本波归它，本片只用不改）、`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/create_node_menu_test.dart`。
- 同波 back-to-content-chip：`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`。
- 同波 node-library-section / node-library-drag-recents：`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`templates_panel.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/util/canvas_tool_actions.dart`（本片只调用其中已有函数，不改）、`lib/core/interfaces/job_repository.dart`、`lib/storage/repositories/postgres_job_repository.dart`、`lib/features/canvas/providers/recent_generation_params.dart`、`lib/features/canvas/models/canvas_drag_payload.dart`、`image_config_inspector.dart`、`prompt_presets_controller.dart`。
- 同波 storyboard-pdf-export：`pubspec.yaml`、`pubspec.lock`、`assets/fonts/**`、`lib/core/licenses.dart`、`lib/core/di/video_export.dart`、`lib/features/export/**`、`lib/services/pdf_storyboard_service.dart`。
- cm-knife-cut 的文件（W17 建，本片只调用不改）：`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/widgets/stage_pointer_layer.dart`、`edge_cut_hit.dart`、`edge_cut_painter.dart`、`canvas_cut_actions.dart`、`test/features/canvas/widgets/canvas_knife_cut_test.dart`。
- 其它：`lib/features/command_palette/command_actions.dart`（app-action-table 之后 ⌘K 从动作表取，本片不再改它）、`canvas_shortcuts.dart` / `canvas_shortcut_registry.dart`（不加新键）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - node-library-drag-recents（另加）：`lib/features/canvas/widgets/canvas_view.dart`（舞台拖放派发的三个分支）
  - create-menu-notes-characters：`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/theme/components/ink_menu_panel_test.dart`
  - back-to-content-chip：`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`
  - node-library-section：`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/widgets/left_rail/node_library_section_test.dart`
  - node-library-drag-recents：`lib/features/canvas/models/canvas_drag_payload.dart`、`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/util/prompt_preset_apply.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/util/prompt_preset_apply_test.dart`、`test/features/canvas/widgets/left_rail/node_library_drag_test.dart`
  - storyboard-pdf-export：`assets/fonts/`、`assets/fonts/NotoSansSC-Regular.ttf`、`assets/fonts/OFL-NotoSansSC.txt`、`lib/core/di/storyboard_pdf.dart`、`lib/core/interfaces/storyboard_pdf_service.dart`、`lib/core/licenses.dart`、`lib/features/export/providers/storyboard_pdf_controller.dart`、`lib/features/export/util/storyboard_pages.dart`、`lib/features/export/widgets/export_history_row.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/storyboard_pdf_dialog.dart`、`lib/services/pdf_storyboard_service.dart`、`lib/services/ui_storyboard_thumbnail_loader.dart`、`pubspec.yaml`、`test/core/licenses_test.dart`、`test/features/export/providers/storyboard_pdf_controller_test.dart`、`test/features/export/util/storyboard_pages_test.dart`、`test/features/export/widgets/storyboard_pdf_dialog_test.dart`、`test/services/pdf_storyboard_service_test.dart`

## 具体改动
1. more_menu_model.dart（数据表 + 纯函数；只 import 模型、InkGlyph、riverpod，不 import `features/canvas/widgets/` 下的任何文件）：
```dart
enum MoreMenuGroup { import, chain, templates, knife, view } // 枚举序 = 组序，改组序只改这里
@immutable
class MoreMenuItem {
  const MoreMenuItem({required this.group, required this.actionId, required this.glyph, this.isChecked});
  final MoreMenuGroup group;
  final String actionId;                 // app_action_ids.dart 里的 id
  final InkGlyph glyph;
  final bool Function(WidgetRef ref, String canvasId)? isChecked; // 只有小地图给
}
final List<MoreMenuItem> kMoreMenuItems; // 一项一行；新项 = 追加一行
List<List<MoreMenuItem>> moreMenuGroups(List<MoreMenuItem> items); // 按枚举序分组、组内保持登记顺序、空组不出
bool canvasHasNarrativeChain(List<CanvasNode> nodes, List<CanvasEdge> edges); // = narrativeChainMembers(...).isNotEmpty（outline_model.dart:34）
```
2. 8 行登记（组 · 动作 · 图标 · 执行体的出处，执行体都在前序切片里，按名字去 main 上找）：
   - import · 导入剧本… · script · `showScriptImportDialog(context, canvasId:, origin: viewportCenteredNodeOrigin(ref, canvasId:, type: CanvasNodeType.shot))`（现 canvas_toolbar.dart 第 236–245 行原样搬）
   - import · 导入媒体… · upload · import-media-command 的 `importMediaViaPicker`（canvas_tool_actions）
   - chain · 整理叙事链 · sequence · align-distribute-arrange 的「整理叙事链」动作；无链置灰
   - chain · 运行叙事链… · run · tc-batch-run-dialog 的 `openBatchRunDialog`（范围 = 叙事链）；无链置灰
   - templates · 从模板插入… · templates · rail-templates-page：左栏切到模板页并展开（left_rail_state）
   - knife · 切线 · link · 本片新增动作：`activateSelectTool(ref, canvasId:)`（canvas_tool_actions.dart 第 179 行，退出平移与连线）→ `edgeCutControllerProvider(canvasId).notifier.arm()` → 弹轻提示胶囊
   - view · 查找 · search · canvas-find-bar 的打开查找条
   - view · 小地图 · minimap · canvas-minimap 的开合；`isChecked` = 小地图可见
3. 动作表：每行的 文案 / 键位 / isEnabled / disabledReason / run 都取 app_action_catalog 里同 id 的那一项，菜单不自带第二份。核对表里是否已有这 8 个动作（app-action-table 登记过「导入媒体」「查找」；batch-run-dialog 登记过 ⌘K 的「运行叙事链」；其余以 main 为准）；缺的在表尾一处连续追加，键位取已有常量（Ctrl U / Ctrl F / M 用各切片注册的 activator，「切线」不绑键，键位提示写 `canvasMoreKnifeKeyHint`）。「整理叙事链」「运行叙事链」的 isEnabled 用 `canvasHasNarrativeChain`，disabledReason = `canvasMoreNoChainReason`。
4. 一次性切线本身（武装后拖空白即切、光标、切完 / Esc 解除、Esc 阶梯登记）全部由 cm-knife-cut 实现；本片不改它的任何文件。
5. canvas_more_menu.dart：
```dart
class CanvasMoreMenu extends ConsumerStatefulWidget { const CanvasMoreMenu({super.key, required this.canvasId, required this.anchor}); }
static const Key panelKey = ValueKey<String>('canvasMoreMenu.panel');
```
   面板用 menu-split 搬到 theme 层的面板（宽 = 空白处菜单的 196，无搜索框）；条目字段：label / glyph / keyHint / enabled / checked，置灰原因用面板条目已有的原因字段（见「风险」）。

## 行为规则与边界情况
1. 「更多」键：点一下开，开着时再点一下关；Enter / Space 同点击；打开后焦点进菜单，高亮第一项可用项。
2. 定位（缺口①）：面板顶边 = 按钮底边 + `InkSpacing.xs`，面板右边对齐按钮右边；左侧贴不下时右移到舞台左边 + `InkSpacing.lg`；全部交给 `CanvasMenuPopover` 的贴边逻辑，本片不自己算。
3. 行序与分隔线严格按 MoreMenuGroup 枚举序；组内按登记顺序；某组一项都没有就不出（不留孤立分隔线）。
4. 无链（节点 + 边里没有一条两端都在的 narrative 边）：「整理叙事链」「运行叙事链…」置灰（降 0.5、↑↓ 跳过、点不动），悬停写「还没有叙事链」（缺口⑤）。其余项不受链影响。
5. 小地图行：可见时行尾打勾；点了切换，菜单关闭。
6. 选一项：先关菜单并把焦点还给画布（`CanvasShortcuts.reclaimFocus`），再执行；执行体开对话框时焦点归对话框。Esc / 点外面 / 菜单失焦 = 只关菜单，焦点还给画布（点外面关走帧后补焦点，与右键菜单一致）。
7. 一次性切线（手势细节归 cm-knife-cut，本片只负责「进入」）：
   a. 选「切线」：先回到选择工具并退出连线模式（平移工具下切不了），再 `arm()`；画布出轻提示胶囊「拖过要剪的线 · Esc 退出」（缺口③，纯文字 2 秒，dedupeKey `knife-armed`，走 canvas-capsule 的 canvasCapsuleProvider(canvasId)）。
   b. 之后的行为全按 cm-knife-cut：不按 Alt 左键拖空白起切线、红色虚线、划过的叙事 / data 线变红、松手一个事务剪掉 + 撤销卡、产出线不受影响、切完（不论命中）或 Esc 自动解除；光标 `SystemMouseCursors.precise`（缺口②：没有系统剪刀光标）。
   c. 武装后点空白不拖（缺口④）、按到卡片上：按 cm-knife-cut 的实现（< 4px 视为普通单击空白）；若与画板「一次性」的预期不符，在回报里写明，不在本片改它的文件。
   d. 菜单开着时已经在武装状态：再选「切线」不重复弹胶囊之外的东西（`arm()` 对已武装 / 正在切幂等）。
8. ⌘K：「切线」动作只在画布标签打开时可用，执行 = 对当前画布 `arm()`；其余 7 项的 ⌘K 行为以动作表为准。
9. mac / Windows：键位提示走 `formatShortcutActivator`（Ctrl U / ⌘U、Ctrl F / ⌘F）；「切线」提示 Windows 写「Alt 拖」、mac 写「⌥ 拖」。
10. 并发：菜单开着时节点 / 边变了（例如别处删掉最后一条叙事边），置灰状态跟着重建（宿主 watch 节点与边控制器）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasMoreKnife | Cut wires | 切线 |
| canvasMoreKnifeKeyHint | Alt drag | Alt 拖 |
| canvasMoreKnifeKeyHintMac | ⌥ drag | ⌥ 拖 |
| canvasMoreNoChainReason | No narrative chain yet | 还没有叙事链 |
| canvasKnifeArmedHint | Drag across wires to cut · Esc to exit | 拖过要剪的线 · Esc 退出 |
（「导入剧本…」复用 `canvasAddImportScript`；其余 6 项复用各自切片已有的动作文案键。若 node-menu-append-chain 已加过「还没有叙事链」的键，复用它，不新增 `canvasMoreNoChainReason`。）

## 测试
- `test/features/canvas/util/more_menu_model_test.dart`（新建）：
  - `moreMenuGroups：按枚举序分组，组内保持登记顺序`（打乱登记顺序也出 import | chain | templates | knife | view）。
  - `某组为空则不出`。
  - `kMoreMenuItems 正好 8 行，导入组第一项是导入剧本`。
  - `canvasHasNarrativeChain：只有悬空 narrative 边 ⇒ false；两端都在 ⇒ true；只有 data 边 ⇒ false`。
- `test/features/canvas/widgets/canvas_more_menu_test.dart`（新建）：
  - `点「更多」出面板（canvasMoreMenu.panel），不再有 PopupMenuItem`。
  - `8 行按样稿顺序，4 条分隔线`。
  - `无链时整理 / 运行两项置灰，↓ 从导入媒体直接跳到从模板插入`。
  - `有链时两项可点`。
  - `小地图可见时行尾打勾`。
  - `Esc 关闭且焦点回到画布`；`再点一次「更多」关闭`。
  - `选「导入剧本…」开脚本导入框`。
- `test/features/canvas/widgets/canvas_toolbar_test.dart`：第 307 行用例改成「更多 → 面板 → 导入剧本…」。
- `canvas_more_menu_test.dart` 里的切线用例：
  - `选「切线」⇒ edgeCutControllerProvider 进入武装，并出「拖过要剪的线」胶囊`。
  - `平移工具下选「切线」⇒ 工具回到选择、连线模式退出`。
  - `武装后不按 Alt 左键拖过叙事线 ⇒ 边被剪掉（端到端走 cm-knife-cut 的手势）`。

## 变异点
1. `moreMenuGroups` 改成按登记顺序不按枚举序 → 由 `按枚举序分组…` 抓住。
2. 空组不过滤 → 由 `某组为空则不出` 抓住。
3. `canvasHasNarrativeChain` 改成 `edges.any(narrative)`（不看两端）→ 由 `只有悬空 narrative 边 ⇒ false` 抓住。
4. 宿主把「整理叙事链」的 enabled 写死 true → 由 `无链时整理 / 运行两项置灰…` 抓住。
5. 「切线」动作去掉 `arm()` 调用 → 由 `选「切线」⇒ edgeCutControllerProvider 进入武装` 抓住。
6. 「切线」动作去掉 `activateSelectTool` → 由 `平移工具下选「切线」⇒ 工具回到选择` 抓住。
7. 「切线」动作不弹胶囊 → 由 `选「切线」⇒ … 出「拖过要剪的线」胶囊` 抓住。
8. 恢复 `showMenu` → 由 `不再有 PopupMenuItem` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/features/app_actions --exclude-tags golden` 与上面的变异；`test/quality/no_reverse_layer_import_test.dart`、`no_dead_interactive_test.dart` 必须绿。
- 截图：`CanvasScreen`（或 `CanvasToolbar` + `CanvasMoreMenu` 放进带 ProviderScope 的舞台）；数据 = 一个画布两镜 + 一条叙事边、小地图开着。状态：① 菜单打开有链（小地图打勾）；② 删掉叙事边后打开（两项置灰、悬停出原因）；③ 选「切线」后的胶囊 + 拖动中（红色虚线 + 被划过的线变红）。

## 风险与不确定
- more_menu_model 归属不一致：plan 第 0 节把它列为「W0 / W1 建的注册表」，但 slices.json 里只有本片的足迹列了它，W3 / W11 / W17 那几片的足迹写的是直接改 canvas_toolbar.dart 的「更多」。执行前先看 main：两种情况的做法都写在「允许改的文件」里；请主 Agent 确认以本片为建表者。
- 置灰原因：画板要「悬停说原因」，但 main 上的 `CanvasMenuEntry` 没有原因字段。若 menu-split 或 W6–W12 的右键菜单切片已经加了（预计叫 `disabledReason` / tooltip），直接用；没有的话本片**不改** `ink_menu_panel.dart`（本波归 create-menu-notes-characters），置灰项先只置灰，在回报里列为缺口，由主 Agent 决定下一波补。
- app_action_catalog 每片只许追加一行，而这里可能要补 1–5 行（取决于前序切片登记了多少）；都放在表尾同一处，主 Agent rebase 时当一块合。
- 一次性切线完全依赖 cm-knife-cut 的 `arm()`（见 briefs/cm-knife-cut.md 具体改动与规则 12）；若 main 上没有 `arm()`，停下回报主 Agent，不要自行改 edge_cut_controller / stage_pointer_layer（slices.json 原注说过这种情况体量会升到 L）。画板说「Esc 退出」，cm-knife-cut 规则 12 已覆盖；「点空白不拖」是否解除武装两边都没定，列为设计缺口。
- 各动作执行体的函数名来自 slices.json（importMediaViaPicker、openBatchRunDialog 等），以 main 上实际为准；找不到某个动作（前序切片没落地）时这一行登记但置灰，原因「即将推出」（沿用 app-action-table 的做法）。
- 「每项也进菜单栏」：Windows 自绘菜单栏 / mac 菜单栏从动作表取哪些项归 ShellExport 的切片，本片只保证动作表里有，不改菜单栏文件。
